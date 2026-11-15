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
  // Design-spec Pro designs, rendered by the template engine from the
  // specs in lib/pdf/resume_design_presets.dart. Adding a design = one
  // value here + one entry there.
  aurora,
  meridian,
  sterling,
  vivid,
  atlas,
  heritage,
  nova,
  summit,
  quartz,
  ivy,
  horizon,
  ember,
  graphite,
  sage,
  prism,
}

/// Cover letter designs. Values after `formal` are design-spec designs
/// sharing the resume design of the same name (a matching set).
enum CoverLetterTemplate {
  classic,
  modern,
  minimal,
  bold,
  formal,
  aurora,
  meridian,
  sterling,
  vivid,
  atlas,
  heritage,
  nova,
  summit,
  quartz,
  ivy,
  horizon,
  ember,
  graphite,
  sage,
  prism,
}

/// Proposal designs. Values after `executive` are design-spec designs
/// sharing the resume design of the same name (a matching set).
enum ProposalTemplate {
  classic,
  modern,
  minimal,
  corporate,
  executive,
  aurora,
  meridian,
  sterling,
  vivid,
  atlas,
  heritage,
  nova,
  summit,
  quartz,
  ivy,
  horizon,
  ember,
  graphite,
  sage,
  prism,
}

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
