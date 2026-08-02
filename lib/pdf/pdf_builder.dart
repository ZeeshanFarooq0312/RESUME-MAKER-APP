import 'package:pdf/widgets.dart' as pw;

import '../models/cover_letter_data.dart';
import '../models/proposal_data.dart';
import '../models/resume_data.dart';
import '../models/template_kind.dart';
import 'templates/classic_template.dart';
import 'templates/compact_template.dart';
import 'templates/cover_letter_bold_template.dart';
import 'templates/cover_letter_classic_template.dart';
import 'templates/cover_letter_formal_template.dart';
import 'templates/cover_letter_minimal_template.dart';
import 'templates/cover_letter_modern_template.dart';
import 'templates/creative_template.dart';
import 'templates/elegant_template.dart';
import 'templates/executive_template.dart';
import 'templates/harvard_template.dart';
import 'templates/minimal_template.dart';
import 'templates/modern_template.dart';
import 'templates/professional_template.dart';
import 'templates/proposal_classic_template.dart';
import 'templates/proposal_corporate_template.dart';
import 'templates/proposal_executive_template.dart';
import 'templates/proposal_minimal_template.dart';
import 'templates/proposal_modern_template.dart';
import 'templates/simple_bold_template.dart';
import 'templates/technical_template.dart';
import 'templates/timeline_template.dart';

Future<pw.Document> buildResumeDoc(ResumeTemplate template, ResumeData data) {
  switch (template) {
    case ResumeTemplate.classic:
      return ClassicTemplate.build(data);
    case ResumeTemplate.modern:
      return ModernTemplate.build(data);
    case ResumeTemplate.minimal:
      return MinimalTemplate.build(data);
    case ResumeTemplate.professional:
      return ProfessionalTemplate.build(data);
    case ResumeTemplate.compact:
      return CompactTemplate.build(data);
    case ResumeTemplate.executive:
      return ExecutiveTemplate.build(data);
    case ResumeTemplate.technical:
      return TechnicalTemplate.build(data);
    case ResumeTemplate.simpleBold:
      return SimpleBoldTemplate.build(data);
    case ResumeTemplate.harvard:
      return HarvardTemplate.build(data);
    case ResumeTemplate.creative:
      return CreativeTemplate.build(data);
    case ResumeTemplate.elegant:
      return ElegantTemplate.build(data);
    case ResumeTemplate.timeline:
      return TimelineTemplate.build(data);
  }
}

Future<pw.Document> buildCoverLetterDoc(CoverLetterTemplate template, CoverLetterData data) {
  switch (template) {
    case CoverLetterTemplate.classic:
      return CoverLetterClassicTemplate.build(data);
    case CoverLetterTemplate.modern:
      return CoverLetterModernTemplate.build(data);
    case CoverLetterTemplate.minimal:
      return CoverLetterMinimalTemplate.build(data);
    case CoverLetterTemplate.bold:
      return CoverLetterBoldTemplate.build(data);
    case CoverLetterTemplate.formal:
      return CoverLetterFormalTemplate.build(data);
  }
}

Future<pw.Document> buildProposalDoc(ProposalTemplate template, ProposalData data) {
  switch (template) {
    case ProposalTemplate.classic:
      return ProposalClassicTemplate.build(data);
    case ProposalTemplate.modern:
      return ProposalModernTemplate.build(data);
    case ProposalTemplate.minimal:
      return ProposalMinimalTemplate.build(data);
    case ProposalTemplate.corporate:
      return ProposalCorporateTemplate.build(data);
    case ProposalTemplate.executive:
      return ProposalExecutiveTemplate.build(data);
  }
}
