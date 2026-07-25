import '../models/resume_data.dart';

/// Best-effort heuristic parser that turns raw text extracted from an
/// uploaded resume PDF into structured [ResumeData]. Layouts vary wildly,
/// so this favors safe, conservative matches over aggressive guessing —
/// the user reviews and corrects every field on the edit form afterward.
class ResumeTextParser {
  static final _emailRegex = RegExp(r'[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}');
  static final _phoneRegex =
      RegExp(r'(\+\d{1,3}[-.\s]?)?(\(?\d{3}\)?[-.\s]?){1,2}\d{3}[-.\s]?\d{4}');
  static final _dateRangeRegex = RegExp(
    r'((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s*\d{4}|\d{4})'
    r'\s*(?:-|–|—|to)\s*'
    r'((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s*\d{4}|\d{4}|present|current)',
    caseSensitive: false,
  );
  static final _locationRegex = RegExp(r'^[A-Za-z][A-Za-z .]*,\s*[A-Za-z][A-Za-z .]*$');
  static final _bulletPrefixRegex = RegExp(r'^[•●○◦▪▫∙·‣⁃∗\-*]\s*');

  static const _summaryHeaders = {
    'summary', 'profile', 'objective', 'about', 'about me',
    'professional summary', 'career objective', 'career summary',
  };
  static const _experienceHeaders = {
    'experience', 'work experience', 'employment', 'employment history',
    'professional experience', 'work history', 'career history',
  };
  static const _educationHeaders = {
    'education', 'academic background', 'academics', 'education & training',
    'education and training',
  };
  static const _skillsHeaders = {
    'skills', 'technical skills', 'core competencies', 'key skills',
    'core skills', 'skills & expertise', 'skills and expertise',
  };

  static ResumeData parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim().replaceFirst(_bulletPrefixRegex, '').trim())
        .toList();
    final data = ResumeData();

    var firstSectionIdx = lines.length;
    for (var i = 0; i < lines.length; i++) {
      if (_sectionOf(lines[i]) != _Section.other) {
        firstSectionIdx = i;
        break;
      }
    }
    final headerLines =
        lines.sublist(0, firstSectionIdx).where((l) => l.isNotEmpty).toList();

    final email = _emailRegex.firstMatch(rawText)?.group(0) ?? '';
    final phone = _phoneRegex.firstMatch(rawText)?.group(0)?.trim() ?? '';
    data.personalInfo.email = email;
    data.personalInfo.phone = phone;

    final nameCandidates = headerLines
        .where((l) =>
            !l.contains('@') &&
            !_phoneRegex.hasMatch(l) &&
            l.length <= 60 &&
            RegExp(r'[A-Za-z]').hasMatch(l))
        .toList();
    if (nameCandidates.isNotEmpty) data.personalInfo.fullName = nameCandidates[0];
    if (nameCandidates.length > 1) data.personalInfo.jobTitle = nameCandidates[1];

    data.personalInfo.location = _extractLocation(headerLines, email, phone);

    final sections = <_Section, List<String>>{};
    _Section? current;
    for (var i = firstSectionIdx; i < lines.length; i++) {
      final sec = _sectionOf(lines[i]);
      if (sec != _Section.other) {
        current = sec;
        sections.putIfAbsent(current, () => []);
        continue;
      }
      if (current != null && lines[i].isNotEmpty) {
        sections[current]!.add(lines[i]);
      }
    }

    final summaryLines = sections[_Section.summary];
    if (summaryLines != null && summaryLines.isNotEmpty) {
      data.personalInfo.summary = summaryLines.join(' ').trim();
    }

    final skillLines = sections[_Section.skills];
    if (skillLines != null && skillLines.isNotEmpty) {
      data.skills = _splitSkills(skillLines);
    }

    final experienceLines = sections[_Section.experience];
    if (experienceLines != null && experienceLines.isNotEmpty) {
      data.experience = _parseExperience(experienceLines);
    }

    final educationLines = sections[_Section.education];
    if (educationLines != null && educationLines.isNotEmpty) {
      data.education = _parseEducation(educationLines);
    }

    return data;
  }

  static String _extractLocation(List<String> headerLines, String email, String phone) {
    for (final raw in headerLines) {
      var line = raw;
      if (email.isNotEmpty) line = line.replaceAll(email, '');
      if (phone.isNotEmpty) line = line.replaceAll(phone, '');
      for (final fragment in line.split(RegExp(r'[|•;]'))) {
        final f = fragment.trim();
        if (f.isNotEmpty && f.length <= 60 && _locationRegex.hasMatch(f)) {
          return f;
        }
      }
    }
    return '';
  }

  static _Section _sectionOf(String rawLine) {
    var line = rawLine.trim();
    if (line.isEmpty || line.length > 40) return _Section.other;
    line = line.replaceAll(RegExp(r':$'), '').trim().toLowerCase();
    line = line.replaceAll(RegExp(r'\s+'), ' ');
    if (_summaryHeaders.contains(line)) return _Section.summary;
    if (_experienceHeaders.contains(line)) return _Section.experience;
    if (_educationHeaders.contains(line)) return _Section.education;
    if (_skillsHeaders.contains(line)) return _Section.skills;
    return _Section.other;
  }

  static List<String> _splitSkills(List<String> lines) {
    final tokens = lines.join(', ').split(RegExp(r'[,•|;/]'));
    final seen = <String>{};
    final result = <String>[];
    for (final raw in tokens) {
      final s = raw.trim();
      if (s.isEmpty || s.length > 40) continue;
      if (seen.add(s.toLowerCase())) result.add(s);
    }
    return result;
  }

  static List<int> _dateAnchors(List<String> lines) => [
        for (var i = 0; i < lines.length; i++)
          if (_dateRangeRegex.hasMatch(lines[i])) i,
      ];

  /// Splits "Role - Company" / "Role, Company" / "Role at Company" style
  /// text into two parts. Falls back to putting everything in the first part.
  static List<String> _splitTitleLine(String line) {
    final parts = line.split(RegExp(r'\s*[|\-–—]\s*|,\s*|\s+at\s+'));
    final first = parts.isNotEmpty ? parts[0].trim() : '';
    final rest = parts.length > 1 ? parts.sublist(1).join(', ').trim() : '';
    return [first, rest];
  }

  static String _stripDateMatch(String line, RegExpMatch match) {
    return line
        .replaceRange(match.start, match.end, '')
        .replaceAll(RegExp(r'^[\s,|•\-–—()]+|[\s,|•\-–—()]+$'), '')
        .trim();
  }

  static List<ExperienceEntry> _parseExperience(List<String> block) {
    final anchors = _dateAnchors(block);
    if (anchors.isEmpty) {
      if (block.isEmpty) return [];
      return [ExperienceEntry(description: block.join('\n'))];
    }

    final entries = <ExperienceEntry>[];
    for (var a = 0; a < anchors.length; a++) {
      final idx = anchors[a];
      final match = _dateRangeRegex.firstMatch(block[idx])!;
      final start = match.group(1)?.trim() ?? '';
      final end = match.group(2)?.trim() ?? '';

      var titleLine = _stripDateMatch(block[idx], match);
      var descStart = idx + 1;
      if (titleLine.isEmpty && idx + 1 < block.length && !anchors.contains(idx + 1)) {
        titleLine = block[idx + 1];
        descStart = idx + 2;
      }

      final titleParts = _splitTitleLine(titleLine);
      final descEnd = (a + 1 < anchors.length) ? anchors[a + 1] : block.length;
      final descLines = [
        for (var j = descStart; j < descEnd; j++)
          if (block[j].isNotEmpty) block[j],
      ];

      entries.add(ExperienceEntry(
        role: titleParts[0],
        company: titleParts[1],
        startDate: start,
        endDate: end,
        description: descLines.join('\n'),
      ));
    }
    return entries;
  }

  static List<EducationEntry> _parseEducation(List<String> block) {
    final anchors = _dateAnchors(block);
    if (anchors.isEmpty) {
      if (block.isEmpty) return [];
      return [EducationEntry(degree: block.join(', '))];
    }

    final entries = <EducationEntry>[];
    for (var a = 0; a < anchors.length; a++) {
      final idx = anchors[a];
      final match = _dateRangeRegex.firstMatch(block[idx])!;
      final start = match.group(1)?.trim() ?? '';
      final end = match.group(2)?.trim() ?? '';

      var titleLine = _stripDateMatch(block[idx], match);
      if (titleLine.isEmpty && idx + 1 < block.length && !anchors.contains(idx + 1)) {
        titleLine = block[idx + 1];
      }

      final titleParts = _splitTitleLine(titleLine);
      entries.add(EducationEntry(
        degree: titleParts[0],
        school: titleParts[1],
        startDate: start,
        endDate: end,
      ));
    }
    return entries;
  }
}

enum _Section { summary, experience, education, skills, other }
