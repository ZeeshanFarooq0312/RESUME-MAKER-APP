enum ResumeTemplate {
  classic,
  modern,
  minimal,
  professional,
  compact,
  executive,
  technical,
  simpleBold,
  harvard,
  creative,
  elegant,
  timeline,
}

enum CoverLetterTemplate { classic, modern, minimal, bold, formal }

enum ProposalTemplate { classic, modern, minimal, corporate, executive }

/// Single source of truth for which templates require Pro — read by the
/// template picker (for the "PRO" badge) and by the preview screen's
/// download gate, so the two can never drift out of sync with each other.
extension ResumeTemplateTier on ResumeTemplate {
  bool get isPremium => this != ResumeTemplate.classic && this != ResumeTemplate.minimal;
}

extension CoverLetterTemplateTier on CoverLetterTemplate {
  bool get isPremium => this != CoverLetterTemplate.classic;
}

extension ProposalTemplateTier on ProposalTemplate {
  bool get isPremium => this != ProposalTemplate.classic;
}
