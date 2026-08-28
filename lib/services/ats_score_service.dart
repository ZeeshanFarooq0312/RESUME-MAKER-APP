import '../models/resume_data.dart';

/// One pass/fail line in the ATS checklist. [weight] is how many of the
/// 100 total score points this item is worth if [passed]; [hint] explains
/// why it matters (shown for both passed and failed items, as context).
class AtsCheckItem {
  final String label;
  final bool passed;
  final String hint;
  final int weight;
  const AtsCheckItem({
    required this.label,
    required this.passed,
    required this.hint,
    required this.weight,
  });
}

/// The full result of a rule-based ATS pass. [score] is always the sum of
/// passed checks' weights (0-100) — entirely deterministic, no AI involved,
/// so it's instant and free regardless of AI configuration or daily limits.
class AtsScoreResult {
  final int score;
  final List<AtsCheckItem> checks;
  const AtsScoreResult({required this.score, required this.checks});
}

/// How many of a job description's notable keywords a resume's text covers.
class KeywordMatchResult {
  final int matched;
  final int total;
  final List<String> missing;
  const KeywordMatchResult({required this.matched, required this.total, required this.missing});
}

/// Scores a resume's ATS-friendliness two ways: [scoreResumeData] against
/// the app's own structured [ResumeData] (for a resume built/saved in the
/// app), and [scoreRawText] against plain text (for a resume the user
/// uploads as a PDF, extracted via ResumePdfImporter). The two checklists
/// differ because structured data lets us check specific fields directly,
/// while raw text can only be pattern-matched — each is scored out of the
/// same 100 points using criteria a real ATS parser plausibly cares about:
/// contact info, standard sections, quantified achievements, action verbs,
/// and reasonable length. This is a heuristic approximation of ATS
/// behavior, not a guarantee any specific ATS product scores it the same.
class AtsScoreService {
  const AtsScoreService._();

  static AtsScoreResult scoreResumeData(ResumeData data) {
    final p = data.personalInfo;
    final allDescriptions = data.experience.map((e) => e.description).join(' ');
    final totalWords = _wordCount('${p.summary} $allDescriptions');
    final avgDescWords = data.experience.isEmpty
        ? 0
        : data.experience.map((e) => _wordCount(e.description)).reduce((a, b) => a + b) /
            data.experience.length;

    final checks = <AtsCheckItem>[
      AtsCheckItem(
        label: 'Full name provided',
        passed: p.fullName.trim().isNotEmpty,
        hint: 'Recruiters and ATS both key off your name at the top of the resume.',
        weight: 5,
      ),
      AtsCheckItem(
        label: 'Contact details present',
        passed: p.email.trim().isNotEmpty && p.phone.trim().isNotEmpty,
        hint: 'Include both an email and a phone number so ATS can extract your contact info.',
        weight: 10,
      ),
      AtsCheckItem(
        label: 'Professional summary',
        passed: _wordCount(p.summary) >= 15,
        hint: 'Add a 2-4 sentence summary near the top, targeting the role you want.',
        weight: 10,
      ),
      AtsCheckItem(
        label: 'Target job title set',
        passed: p.jobTitle.trim().isNotEmpty,
        hint: 'A clear job title helps ATS match you to the right role.',
        weight: 5,
      ),
      AtsCheckItem(
        label: 'Work experience listed',
        passed: data.experience.isNotEmpty,
        hint: 'Add at least one work experience entry.',
        weight: 15,
      ),
      AtsCheckItem(
        label: 'Experience descriptions are detailed',
        passed: data.experience.isNotEmpty && avgDescWords >= 12,
        hint: "Expand each role's description to at least a sentence or two of real detail.",
        weight: 10,
      ),
      AtsCheckItem(
        label: 'Quantified achievements',
        passed: _hasQuantifiedAchievement(allDescriptions),
        hint: 'Add numbers — %, \$, counts — to show impact (e.g. "grew revenue by 20%").',
        weight: 10,
      ),
      AtsCheckItem(
        label: 'Strong action verbs',
        passed: _hasActionVerb(allDescriptions),
        hint: 'Start bullets with verbs like "Led", "Built", "Increased" instead of passive phrasing.',
        weight: 10,
      ),
      AtsCheckItem(
        label: 'Education listed',
        passed: data.education.isNotEmpty,
        hint: 'Add at least one education entry.',
        weight: 10,
      ),
      AtsCheckItem(
        label: 'Skills listed (5+)',
        passed: data.skills.length >= 5,
        hint: 'List at least 5 relevant skills so keyword matching has something to find.',
        weight: 10,
      ),
      AtsCheckItem(
        label: 'Appropriate length',
        passed: totalWords >= 100 && totalWords <= 1200,
        hint: 'Aim for enough detail to be substantive without running long.',
        weight: 5,
      ),
    ];
    return AtsScoreResult(score: _sumWeights(checks), checks: checks);
  }

  static AtsScoreResult scoreRawText(String text) {
    final lower = text.toLowerCase();
    final wc = _wordCount(text);
    final headerHits = _sectionHeaders.where((h) => lower.contains(h)).length;

    final checks = <AtsCheckItem>[
      AtsCheckItem(
        label: 'Email address found',
        passed: _emailPattern.hasMatch(text),
        hint: 'Make sure your email appears as real text, not inside an image.',
        weight: 10,
      ),
      AtsCheckItem(
        label: 'Phone number found',
        passed: _phonePattern.hasMatch(text),
        hint: 'Include a phone number as plain text near the top.',
        weight: 10,
      ),
      AtsCheckItem(
        label: 'Standard section headings found',
        passed: headerHits >= 2,
        hint: 'Use clear headings like "Experience", "Education", and "Skills" so ATS can parse sections.',
        weight: 20,
      ),
      AtsCheckItem(
        label: 'Quantified achievements',
        passed: _hasQuantifiedAchievement(text),
        hint: 'Add numbers — %, \$, counts — to show impact.',
        weight: 15,
      ),
      AtsCheckItem(
        label: 'Strong action verbs',
        passed: _hasActionVerb(text),
        hint: 'Use verbs like "Led", "Built", "Increased" to open bullet points.',
        weight: 15,
      ),
      AtsCheckItem(
        label: 'Text is machine-readable',
        passed: wc >= 80,
        hint: 'Very little text was found in this PDF — it may be a scanned image, which most ATS '
            'systems cannot read at all. Export it as a text-based PDF instead.',
        weight: 20,
      ),
      AtsCheckItem(
        label: 'Appropriate length',
        passed: wc >= 150 && wc <= 1500,
        hint: 'Aim for roughly one to two pages of real content.',
        weight: 10,
      ),
    ];
    return AtsScoreResult(score: _sumWeights(checks), checks: checks);
  }

  /// Flattens structured resume data into plain text, for keyword matching
  /// and as the prompt content sent to [GroqService.reviewAtsScore].
  static String flattenResumeText(ResumeData data) {
    final p = data.personalInfo;
    final buf = StringBuffer()
      ..writeln(p.fullName)
      ..writeln(p.jobTitle)
      ..writeln(p.summary);
    for (final e in data.experience) {
      buf
        ..writeln('${e.role} at ${e.company}')
        ..writeln(e.description);
    }
    for (final ed in data.education) {
      buf.writeln('${ed.degree}, ${ed.school}');
    }
    buf.writeln(data.skills.join(', '));
    return buf.toString();
  }

  /// Picks the job description's most frequent non-generic words as
  /// "keywords" and checks how many appear in [resumeText]. A simple
  /// frequency heuristic rather than true NLP, matching this feature's
  /// overall approach — good enough to flag obviously missing terms.
  static KeywordMatchResult matchKeywords({
    required String jobDescription,
    required String resumeText,
  }) {
    final freq = <String, int>{};
    for (final w in _words(jobDescription)) {
      if (w.length < 4 || _stopwords.contains(w)) continue;
      freq[w] = (freq[w] ?? 0) + 1;
    }
    final keywords = freq.keys.toList()..sort((a, b) => freq[b]!.compareTo(freq[a]!));
    final top = keywords.take(20).toList();
    final resumeWords = _words(resumeText).toSet();
    final missing = top.where((k) => !resumeWords.contains(k)).toList();
    return KeywordMatchResult(
      matched: top.length - missing.length,
      total: top.length,
      missing: missing.take(10).toList(),
    );
  }

  static int _sumWeights(List<AtsCheckItem> checks) =>
      checks.where((c) => c.passed).fold(0, (sum, c) => sum + c.weight);

  static List<String> _words(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  static int _wordCount(String text) => _words(text).length;

  static bool _hasQuantifiedAchievement(String text) =>
      RegExp(r'\d+\s*%|[\$£€]\s*\d|\b\d{2,}\b').hasMatch(text);

  static bool _hasActionVerb(String text) {
    final words = _words(text).toSet();
    return _actionVerbs.any(words.contains);
  }

  static final _emailPattern = RegExp(r'[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}');
  static final _phonePattern = RegExp(r'(\+?\d[\d\-.\s()]{7,}\d)');

  static const _sectionHeaders = [
    'experience', 'work history', 'employment', 'education', 'skills',
    'summary', 'objective', 'profile', 'projects', 'certifications',
  ];

  static const _actionVerbs = {
    'managed', 'led', 'developed', 'designed', 'built', 'created', 'implemented',
    'launched', 'increased', 'decreased', 'reduced', 'improved', 'optimized',
    'streamlined', 'coordinated', 'delivered', 'achieved', 'negotiated', 'analyzed',
    'executed', 'spearheaded', 'established', 'generated', 'drove', 'directed',
    'supervised', 'mentored', 'trained', 'resolved', 'automated', 'migrated',
    'architected', 'deployed', 'scaled', 'boosted', 'cut', 'saved', 'grew',
    'exceeded', 'collaborated', 'initiated', 'transformed', 'engineered', 'authored',
    'planned', 'organized', 'presented', 'researched', 'audited', 'redesigned',
  };

  static const _stopwords = {
    'the', 'and', 'for', 'are', 'with', 'this', 'that', 'from', 'have', 'will',
    'your', 'you', 'our', 'their', 'about', 'into', 'they', 'them', 'than',
    'then', 'able', 'must', 'each', 'other', 'such', 'these', 'those', 'been',
    'being', 'over', 'more', 'most', 'some', 'also', 'when', 'where', 'which',
    'while', 'what', 'who', 'whom', 'does', 'doing', 'done', 'work', 'works',
    'working', 'role', 'roles', 'team', 'teams', 'company', 'companies',
    'position', 'candidate', 'candidates', 'require', 'requires', 'required',
    'requirements', 'including', 'include', 'includes', 'ability', 'strong',
    'excellent', 'preferred', 'plus', 'across', 'within', 'years', 'year',
    'experience', 'looking', 'join', 'apply', 'applicants',
  };
}
