import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/cover_letter_data.dart';
import '../models/interview_question.dart';
import '../models/proposal_data.dart';
import '../models/resume_data.dart';
import '../models/template_style_spec.dart';

/// Friendly, user-facing error for any AI-feature failure. Every public
/// [GroqService] method only ever throws this, so callers only need to
/// catch one type.
class AiServiceException implements Exception {
  final String message;
  AiServiceException(this.message);

  @override
  String toString() => message;
}

/// Wraps Groq's OpenAI-compatible chat completions API. This is the app's
/// only networked service besides the one-time ML Kit model download in
/// translation_service.dart — every AI feature (bullet rewriting, summary/
/// cover-letter/proposal drafting, job-description resume tailoring) goes
/// through here.
///
/// The API key is embedded at build time via `--dart-define=GROQ_API_KEY=...`
/// and is NOT secret once compiled: anyone can extract it from the built
/// APK/IPA by decompiling it. That's an accepted tradeoff for a hobby app
/// with no backend to proxy through — do not treat this as a secure secret.
class GroqService {
  const GroqService._();

  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  // llama-3.3-70b-versatile / llama-3.1-8b-instant are being retired by Groq
  // on 2026-08-16 in favor of the gpt-oss family, so we target that instead.
  static const _model = 'openai/gpt-oss-120b';
  // gpt-oss-120b is text-only — image input needs a vision-capable model,
  // used only by [extractJobDescriptionFromImage]. Confirmed against Groq's
  // live /v1/models endpoint: this is the only model currently reporting
  // "image" in input_modalities on this account — verify there again
  // before changing this, rather than guessing a model id from memory.
  static const _visionModel = 'qwen/qwen3.8-27b';
  static const _timeout = Duration(seconds: 30);
  static const _visionTimeout = Duration(seconds: 45);

  static bool get isConfigured => _apiKey.isNotEmpty;

  /// [retriesLeft] covers one specific, known-transient failure: Groq's
  /// `json_object` mode only guarantees the model's raw output is *parseable
  /// as JSON* — it doesn't stop the model from occasionally producing
  /// malformed output, which Groq then rejects with a `json_validate_failed`
  /// error rather than returning it. That's a probabilistic generation
  /// hiccup, not a bad request, so a single automatic retry is the standard
  /// mitigation instead of surfacing it to the user as a failure.
  static Future<String> _post(Map<String, dynamic> body, {int retriesLeft = 1, Duration? timeout}) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout ?? _timeout);
    } on TimeoutException {
      throw AiServiceException(
          "Couldn't reach the AI service — check your internet connection and try again.");
    } on SocketException {
      throw AiServiceException(
          "Couldn't reach the AI service — check your internet connection and try again.");
    } on http.ClientException {
      throw AiServiceException(
          "Couldn't reach the AI service — check your internet connection and try again.");
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AiServiceException('AI service rejected the request (invalid API key).');
    }
    if (response.statusCode == 429) {
      throw AiServiceException('The AI service is busy right now — please try again in a moment.');
    }
    if (response.statusCode >= 500) {
      throw AiServiceException('The AI service is temporarily unavailable. Please try again shortly.');
    }
    if (response.statusCode != 200) {
      String? detail;
      String? code;
      try {
        final decoded = jsonDecode(response.body);
        detail = decoded['error']?['message'] as String?;
        code = decoded['error']?['code'] as String?;
      } catch (_) {
        // ignore — fall back to the status code alone below
      }

      if (code == 'json_validate_failed' && retriesLeft > 0) {
        return _post(body, retriesLeft: retriesLeft - 1, timeout: timeout);
      }

      // Surface Groq's actual error message when available (e.g. "invalid_request_error:
      // image too large") instead of a generic message — this is the one place callers
      // most need the real reason, since 4xx here almost always means something specific
      // about the request (bad image, bad params), not a generic outage.
      throw AiServiceException(detail != null
          ? 'The AI service rejected the request: $detail'
          : 'The AI service returned an unexpected error (HTTP ${response.statusCode}).');
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AiServiceException('The AI service returned an unreadable response.');
    }

    try {
      final content = decoded['choices'][0]['message']['content'] as String;
      return content.trim();
    } catch (_) {
      throw AiServiceException('The AI service returned an unreadable response.');
    }
  }

  static Future<String> _complete({
    required String systemPrompt,
    required String userPrompt,
    bool jsonMode = false,
    double temperature = 0.5,
  }) {
    return _post({
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': temperature,
      if (jsonMode) 'response_format': {'type': 'json_object'},
    });
  }

  /// Like [_complete], but the user message carries an image alongside
  /// text — routed to [_visionModel] since [_model] is text-only. Used only
  /// by [extractJobDescriptionFromImage].
  static Future<String> _completeVision({
    required String systemPrompt,
    required String userPrompt,
    required Uint8List imageBytes,
    double temperature = 0.2,
  }) {
    final dataUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
    return _post({
      'model': _visionModel,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userPrompt},
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl},
            },
          ],
        },
      ],
      'temperature': temperature,
    }, timeout: _visionTimeout);
  }

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AiServiceException {
      rethrow;
    } catch (_) {
      throw AiServiceException('Something went wrong generating that. Please try again.');
    }
  }

  /// Rewrites a single resume experience bullet/description.
  static Future<String> rewriteBullet({
    required String currentText,
    required String roleContext,
  }) {
    return _guard(() => _complete(
          systemPrompt:
              'You are a professional resume writer. Rewrite the given resume bullet point to '
              'be concise, achievement-oriented, and use strong action verbs. Keep it to 1-2 '
              'sentences. Return ONLY the rewritten text itself — no preamble, no quotes, no '
              'markdown, and no leading bullet character, dash, or number (the app adds its own '
              'bullet marker when displaying this).',
          userPrompt: 'Role context: $roleContext\n\nCurrent bullet point:\n$currentText',
        ));
  }

  /// Drafts a professional summary from the resume's job title/skills/experience.
  static Future<String> generateSummary({required ResumeData context}) {
    final experienceLines = context.experience
        .map((e) => '- ${e.role} at ${e.company} (${e.startDate} - ${e.endDate})')
        .join('\n');
    return _guard(() => _complete(
          systemPrompt:
              'You are a professional resume writer. Write a 2-4 sentence professional summary '
              'for the top of a resume, based on the candidate\'s job title, skills, and work '
              'history below. Return ONLY the summary text, no preamble, no quotes, no markdown.',
          userPrompt: 'Job title: ${context.personalInfo.jobTitle}\n'
              'Skills: ${context.skills.join(", ")}\n'
              'Experience:\n$experienceLines',
        ));
  }

  /// Drafts a cover letter body from the sender/recipient/job context already
  /// entered in the form.
  static Future<String> generateCoverLetterBody({required CoverLetterData context}) {
    return _guard(() => _complete(
          systemPrompt:
              'You are a professional cover letter writer. Write a 3-4 paragraph cover letter '
              'body (no salutation, no closing — those are handled separately) for the '
              'candidate below, tailored to the position and company. Return ONLY the body '
              'text, no preamble, no quotes, no markdown.',
          userPrompt: 'Candidate name: ${context.fullName}\n'
              'Position applying for: ${context.jobTitle}\n'
              'Company: ${context.companyName}\n'
              'Recipient: ${context.recipientName} (${context.recipientTitle})',
        ));
  }

  /// Drafts a cover letter body for [companyName]/[jobTitle], tailored from an
  /// existing resume rather than a separately-filled-in cover letter form.
  static Future<String> generateCoverLetterFromResume({
    required ResumeData resume,
    required String companyName,
    String? jobTitle,
    String? jobDescription,
  }) {
    final experienceLines = resume.experience
        .map((e) => '- ${e.role} at ${e.company} (${e.startDate} - ${e.endDate}): ${e.description}')
        .join('\n');
    final effectiveTitle = jobTitle?.trim().isNotEmpty == true ? jobTitle!.trim() : resume.personalInfo.jobTitle;
    return _guard(() => _complete(
          systemPrompt:
              'You are a professional cover letter writer. Write a 3-4 paragraph cover letter '
              'body (no salutation, no closing — those are handled separately) for the '
              'candidate below, based on their resume, tailored to the position and company. '
              'Return ONLY the body text, no preamble, no quotes, no markdown.',
          userPrompt: 'Candidate name: ${resume.personalInfo.fullName}\n'
              'Candidate summary: ${resume.personalInfo.summary}\n'
              'Position applying for: $effectiveTitle\n'
              'Company: $companyName\n'
              'Skills: ${resume.skills.join(", ")}\n'
              'Experience:\n$experienceLines'
              '${jobDescription != null && jobDescription.trim().isNotEmpty ? '\n\nJob description:\n${jobDescription.trim()}' : ''}',
        ));
  }

  /// Drafts the "Overview / Executive Summary" section of a business proposal.
  static Future<String> generateProposalOverview({required ProposalData context}) {
    return _guard(() => _complete(
          systemPrompt:
              'You are a professional business proposal writer. Write a 2-3 paragraph overview '
              '/ executive summary for the proposal below. Return ONLY the overview text, no '
              'preamble, no quotes, no markdown.',
          userPrompt: 'Proposal title: ${context.title}\n'
              'From: ${context.senderName} (${context.senderCompany})\n'
              'To: ${context.clientName} (${context.clientCompany})',
        ));
  }

  /// Drafts the "Scope of Work" section of a business proposal, one item per line
  /// to match this form's existing convention for that field.
  static Future<String> generateProposalScope({required ProposalData context}) {
    return _guard(() => _complete(
          systemPrompt:
              'You are a professional business proposal writer. Write a scope of work for the '
              'proposal below, as a short list of concrete deliverables — one item per line, no '
              'bullet characters or numbering, no preamble, no quotes, no markdown.',
          userPrompt: 'Proposal title: ${context.title}\n'
              'Overview: ${context.overview}\n'
              'From: ${context.senderName} (${context.senderCompany})\n'
              'To: ${context.clientName} (${context.clientCompany})',
        ));
  }

  /// Produces a resume tailored to [jobDescription], based on the user's saved
  /// [profile]. This is the highest-risk AI feature: the model must never
  /// fabricate employers, dates, degrees, or skills. The system prompt asks it
  /// not to, but that alone isn't trusted — every field that must stay factual
  /// is force-overwritten from the original [profile] after parsing, so
  /// fabrication is structurally impossible rather than merely discouraged.
  static Future<ResumeData> generateTailoredResume({
    required ResumeData profile,
    required String jobDescription,
    String? jobTitleOverride,
  }) {
    return _guard(() async {
      final content = await _complete(
        jsonMode: true,
        temperature: 0.3,
        systemPrompt: '''
You are a professional resume writer. You will be given a candidate's real profile data as JSON
and a job description as plain text. Return a single JSON object with exactly this shape:
{"personalInfo": {"fullName": "", "jobTitle": "", "email": "", "phone": "", "location": "", "summary": ""},
 "experience": [{"company": "", "role": "", "startDate": "", "endDate": "", "description": ""}],
 "education": [{"school": "", "degree": "", "startDate": "", "endDate": ""}],
 "skills": [""]}

Hard rules:
1. Return the same number of "experience" entries, in the same order, as the input profile.
2. Copy "company", "startDate", and "endDate" verbatim from the input for every experience entry.
   You may rewrite "role" wording only if it's genuinely the same underlying job, and may rewrite
   "description" wording for clarity/relevance to the job description. Never invent, remove,
   merge, or reorder experience entries.
3. Copy "education" entries verbatim and in the same order/count as the input — do not rewrite
   any education field.
4. Keep "fullName", "email", "phone", "location" verbatim. You may rewrite "summary" to better
   match the job description. Only change "jobTitle" if a title override is explicitly given.
5. For "skills", you may reorder and select a subset of the input skills to prioritize ones
   relevant to the job description, and may re-word an existing skill's phrasing, but must not
   introduce any skill/technology that isn't already in the input list.
6. Never fabricate employers, dates, degrees, schools, or credentials under any circumstances.
7. "description" is rendered as plain bullet lines by the app, one per line of your text, each
   with its own bullet marker added automatically — so write each line as plain text with NO
   leading bullet character, dash, asterisk, or number of your own (e.g. write "Led a team of 5
   engineers", never "- Led a team of 5 engineers" or "1. Led a team of 5 engineers").
''',
        userPrompt: 'Candidate profile JSON:\n${jsonEncode(profile.toJson())}\n\n'
            'Job description:\n$jobDescription\n\n'
            '${jobTitleOverride != null && jobTitleOverride.isNotEmpty ? "Job title override: $jobTitleOverride\n" : ""}',
      );

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        throw AiServiceException("Couldn't understand the AI's response — please try again.");
      }

      List<dynamic>? returnedExperience;
      try {
        returnedExperience = parsed['experience'] as List?;
      } catch (_) {
        throw AiServiceException("Couldn't understand the AI's response — please try again.");
      }
      if (returnedExperience == null || returnedExperience.length != profile.experience.length) {
        throw AiServiceException("The AI response didn't match your profile — please try again.");
      }

      // Rebuild experience entries field-by-field: only "role"/"description" come
      // from the model, matched by index; everything else is the original
      // profile's data, so a partial/malformed model response can only degrade
      // wording, never corrupt an employer/date.
      final reconciledExperience = <ExperienceEntry>[];
      for (var i = 0; i < profile.experience.length; i++) {
        final original = profile.experience[i];
        final returned = returnedExperience[i];
        String role = original.role;
        String description = original.description;
        if (returned is Map) {
          if (returned['role'] is String) role = returned['role'] as String;
          if (returned['description'] is String) description = returned['description'] as String;
        }
        reconciledExperience.add(ExperienceEntry(
          id: original.id,
          company: original.company,
          role: role,
          startDate: original.startDate,
          endDate: original.endDate,
          description: description,
        ));
      }

      // Education is left entirely untouched — passed straight through.
      final reconciledEducation = profile.education
          .map((e) => EducationEntry(
                id: e.id,
                school: e.school,
                degree: e.degree,
                startDate: e.startDate,
                endDate: e.endDate,
              ))
          .toList();

      String summary = profile.personalInfo.summary;
      String jobTitle = profile.personalInfo.jobTitle;
      final personalInfoJson = parsed['personalInfo'];
      if (personalInfoJson is Map) {
        if (personalInfoJson['summary'] is String) {
          summary = personalInfoJson['summary'] as String;
        }
        if (jobTitleOverride != null &&
            jobTitleOverride.isNotEmpty &&
            personalInfoJson['jobTitle'] is String) {
          jobTitle = personalInfoJson['jobTitle'] as String;
        }
      }

      final allowedSkills = profile.skills.map((s) => s.toLowerCase().trim()).toSet();
      final returnedSkills = (parsed['skills'] as List?) ?? const [];
      final reconciledSkills = <String>[];
      for (final s in returnedSkills) {
        if (s is String && allowedSkills.contains(s.toLowerCase().trim())) {
          // Use the original profile's casing/wording for the matched skill.
          final original = profile.skills.firstWhere(
            (p) => p.toLowerCase().trim() == s.toLowerCase().trim(),
          );
          if (!reconciledSkills.contains(original)) reconciledSkills.add(original);
        }
      }
      if (reconciledSkills.isEmpty) reconciledSkills.addAll(profile.skills);

      return ResumeData(
        personalInfo: PersonalInfo(
          fullName: profile.personalInfo.fullName,
          jobTitle: jobTitle,
          email: profile.personalInfo.email,
          phone: profile.personalInfo.phone,
          location: profile.personalInfo.location,
          summary: summary,
          photoBase64: profile.personalInfo.photoBase64,
        ),
        experience: reconciledExperience,
        education: reconciledEducation,
        skills: reconciledSkills,
      );
    });
  }

  /// Extracts structured profile data from the raw text of an uploaded
  /// resume (e.g. via [ResumePdfImporter.pickAndExtractText]), for the
  /// "fill my profile from an existing resume" onboarding path. Unlike
  /// [generateTailoredResume] there's no existing profile to reconcile
  /// against — this is the very first import — so the model's output is
  /// used as-is. That's safe here specifically because the caller always
  /// routes the result through [ProfileScreen] for the user to review and
  /// correct before anything is saved, unlike the tailoring flow which can
  /// silently overwrite an already-trusted profile.
  static Future<ResumeData> extractProfileFromResumeText(String resumeText) {
    return _guard(() async {
      final content = await _complete(
        jsonMode: true,
        temperature: 0.2,
        systemPrompt: '''
You are a resume-parsing assistant. You will be given the raw text extracted from a candidate's
resume PDF (formatting/line breaks may be imperfect since it comes from automated text
extraction). Return a single JSON object with exactly this shape, using only information present
in the text — never invent employers, dates, schools, or skills that aren't there:
{"personalInfo": {"fullName": "", "jobTitle": "", "email": "", "phone": "", "location": "", "summary": ""},
 "experience": [{"company": "", "role": "", "startDate": "", "endDate": "", "description": ""}],
 "education": [{"school": "", "degree": "", "startDate": "", "endDate": ""}],
 "skills": [""]}

Rules:
1. "jobTitle" is the candidate's current/most recent role headline, not a section header.
2. Keep dates in whatever short form the resume uses (e.g. "Jan 2022", "2020"); use "Present" for
   a current/ongoing entry's endDate.
3. "description" should summarize the key responsibilities/achievements for that role in 1-3
   sentences, based only on what's in the text. The app renders each line as its own bullet with
   a marker added automatically, so strip any bullet character, dash, asterisk, or number the
   original resume text had at the start of a line — return plain sentences only.
4. "skills" should be a flat list of individual skills/technologies, not a paragraph.
5. Leave a field empty ("" or []) rather than guessing if it isn't clearly present in the text.
''',
        userPrompt: 'Resume text:\n$resumeText',
      );

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        throw AiServiceException("Couldn't understand the AI's response — please try again.");
      }

      try {
        return ResumeData.fromJson(parsed);
      } catch (_) {
        throw AiServiceException("Couldn't understand the AI's response — please try again.");
      }
    });
  }

  /// Generates likely interview questions for [jobDescription], grounded in
  /// the candidate's real resume so questions probe their actual experience
  /// rather than generic ones.
  static Future<List<InterviewQuestion>> generateInterviewQuestions({
    required ResumeData resume,
    required String jobDescription,
    String? jobTitle,
  }) {
    final experienceLines = resume.experience
        .map((e) => '- ${e.role} at ${e.company} (${e.startDate} - ${e.endDate}): ${e.description}')
        .join('\n');
    return _guard(() async {
      final content = await _complete(
        jsonMode: true,
        temperature: 0.5,
        systemPrompt: '''
You are an experienced hiring manager preparing a candidate for an interview. You will be given
the candidate's resume summary and a job description. Return a single JSON object with exactly
this shape:
{"questions": [{"question": "", "category": "", "answerTip": ""}]}

Rules:
1. Return 8-12 questions total, spread across these categories: "Behavioral", "Technical",
   "Role-specific", and "Questions about gaps or transitions" (only include the last category if
   genuinely relevant to this candidate's history).
2. Ground "Role-specific" and "Technical" questions in both the job description and the
   candidate's actual listed experience/skills — reference specifics from their background
   where natural, not generic questions anyone could be asked.
3. "answerTip" is one short sentence (not a full answer) on what a strong response should touch
   on, based on the candidate's own background.
4. Never invent facts about the candidate not present in the resume given.
5. Return ONLY the JSON object, no markdown, no preamble.
''',
        userPrompt: 'Job title: ${jobTitle ?? resume.personalInfo.jobTitle}\n'
            'Job description:\n$jobDescription\n\n'
            'Candidate summary: ${resume.personalInfo.summary}\n'
            'Candidate skills: ${resume.skills.join(", ")}\n'
            'Candidate experience:\n$experienceLines',
      );

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        throw AiServiceException("Couldn't understand the AI's response — please try again.");
      }

      final rawQuestions = parsed['questions'];
      if (rawQuestions is! List || rawQuestions.isEmpty) {
        throw AiServiceException("Couldn't understand the AI's response — please try again.");
      }

      final questions = <InterviewQuestion>[];
      for (final q in rawQuestions) {
        if (q is Map<String, dynamic> && q['question'] is String && (q['question'] as String).trim().isNotEmpty) {
          questions.add(InterviewQuestion.fromJson(q));
        }
      }
      if (questions.isEmpty) {
        throw AiServiceException("Couldn't understand the AI's response — please try again.");
      }
      return questions;
    });
  }

  /// Reviews a resume's text for ATS-friendliness and produces a short
  /// qualitative summary plus concrete improvement suggestions. Deliberately
  /// separate from AtsScoreService's numeric score (100% rule-based and
  /// instant) — this call only adds written feedback on top of it, and a
  /// failure here should never block the score/checklist from showing.
  static Future<({String summary, List<String> suggestions})> reviewAtsScore({
    required String resumeText,
    String? jobDescription,
  }) {
    return _guard(() async {
      final content = await _complete(
        jsonMode: true,
        temperature: 0.4,
        systemPrompt: '''
You are an ATS (Applicant Tracking System) resume reviewer. You will be given the text of a
resume, and optionally a job description it's being considered for. Return a single JSON object
with exactly this shape:
{"summary": "", "suggestions": [""]}

Rules:
1. "summary" is 2-3 sentences on how ATS-friendly and effective this resume is overall.
2. "suggestions" is a list of 3-6 short, specific, actionable improvements (e.g. "Add a metric to
   your first bullet under Acme Corp", not "add more metrics"). Base them only on the actual
   content given — never invent facts about the candidate.
3. Be honest and specific about real gaps rather than only praising the resume.
4. Return ONLY the JSON object, no markdown, no preamble.
''',
        userPrompt: 'Resume text:\n$resumeText\n\n'
            '${jobDescription != null && jobDescription.trim().isNotEmpty ? "Target job description:\n$jobDescription\n" : ""}',
      );

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        throw AiServiceException("Couldn't understand the AI's response — please try again.");
      }
      final summary = parsed['summary'] is String ? parsed['summary'] as String : '';
      final suggestions = (parsed['suggestions'] as List? ?? []).whereType<String>().toList();
      if (summary.isEmpty && suggestions.isEmpty) {
        throw AiServiceException("Couldn't understand the AI's response — please try again.");
      }
      return (summary: summary, suggestions: suggestions);
    });
  }

  /// Turns a plain-English description of a desired resume look into a
  /// [TemplateStyleSpec] — a fixed, enum-backed set of styling choices the
  /// renderer (DynamicResumeTemplate) knows how to draw. The model is
  /// constrained to the exact allowed values for each field; any value it
  /// returns outside that set is silently corrected to a default by
  /// [TemplateStyleSpec.fromJson] rather than failing the whole generation,
  /// since a renderable-but-imperfect result beats an error here.
  static Future<TemplateStyleSpec> generateTemplateStyleSpec({required String description}) {
    return _guard(() async {
      final content = await _complete(
        jsonMode: true,
        temperature: 0.6,
        systemPrompt: '''
You are a resume template stylist. You will be given a plain-English description of how someone
wants their resume to look. Translate it into a single JSON object with exactly this shape, using
ONLY the allowed values listed for each field:
{"accentColor": "", "layoutVariant": "", "density": "", "headerStyle": "", "sectionOrder": []}

Allowed values:
- "accentColor": one of "violet", "forestGreen", "navyBlue", "burgundy", "gold", "charcoal", "teal", "slate"
- "layoutVariant": one of "plainHeader" (simple text header, no color block), "bannerHeader" (full-width
  colored header banner — bolder, more visual)
- "density": one of "compact", "comfortable", "spacious"
- "headerStyle": one of "leftAligned", "centered"
- "sectionOrder": an array containing exactly these four strings, in whatever order best fits the
  description: "summary", "experience", "education", "skills"

Rules:
1. Pick the closest matching values for the description's tone/keywords (e.g. "bold and colorful"
   → bannerHeader + a saturated accentColor like violet or burgundy; "minimal and clean" →
   plainHeader + charcoal or slate + compact or comfortable; "spacious and elegant" → plainHeader +
   centered + spacious).
2. Return ONLY the JSON object, no markdown, no preamble, no values outside the allowed lists.
''',
        userPrompt: 'Description: $description',
      );

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        throw AiServiceException("Couldn't understand the AI's response — please try again.");
      }
      return TemplateStyleSpec.fromJson(parsed);
    });
  }

  /// Reads a photo of a job posting directly (vision, not on-device OCR)
  /// and returns a clean job-description text — the model transcribes only
  /// the actual posting content and leaves out whatever surrounding noise
  /// a raw OCR pass would otherwise capture (UI chrome, ads, watermarks,
  /// unrelated page text, repeated/garbled characters). The photo is sent
  /// to Groq to do this, so this is a networked call like every other AI
  /// feature here — only used where the user has explicitly asked to scan
  /// a photo.
  static Future<String> extractJobDescriptionFromImage(Uint8List imageBytes) {
    return _guard(() async {
      final content = await _completeVision(
        systemPrompt: '''
You are reading a photo of a job posting (a printout, a screen, or a poster) to recover its job
description text. Transcribe ONLY the actual job posting content — title, company (if shown),
responsibilities, requirements, qualifications — in clean plain text, preserving its structure
with line breaks between sections/bullets.

Rules:
1. Leave out anything that isn't part of the job description itself: browser/app UI chrome, ads,
   navigation text, watermarks, page numbers, unrelated text elsewhere in the photo.
2. Fix obvious OCR-style artifacts a camera capture would introduce (stray characters, broken
   words split across a line wrap, repeated characters) by reading what the text actually says —
   but never invent or guess content that isn't legible; skip an illegible fragment rather than
   making something up.
3. Return ONLY the cleaned job description text, no preamble, no commentary, no markdown.
4. If the photo doesn't contain a legible job posting at all, return exactly: NO_JOB_DESCRIPTION_FOUND
''',
        userPrompt: 'Extract the job description from this photo.',
        imageBytes: imageBytes,
      );

      final cleaned = content.trim();
      if (cleaned.isEmpty || cleaned == 'NO_JOB_DESCRIPTION_FOUND') {
        throw AiServiceException(
            "Couldn't find a job description in that photo. Try a clearer, well-lit shot, or paste it manually.");
      }
      return cleaned;
    });
  }
}
