import 'dart:convert';

enum DocumentKind { resume, coverLetter, proposal }

extension DocumentKindLabel on DocumentKind {
  String get label {
    switch (this) {
      case DocumentKind.resume:
        return 'Resume';
      case DocumentKind.coverLetter:
        return 'Cover Letter';
      case DocumentKind.proposal:
        return 'Proposal';
    }
  }
}

/// A saved document of any kind (resume, cover letter, proposal), as shown
/// on the Home dashboard and Favorites tab. [payload] holds the underlying
/// ResumeData/CoverLetterData/ProposalData as JSON — this class doesn't
/// need to know each kind's field structure, only enough to list, sort,
/// and filter documents.
class DocumentEntry {
  String id;
  DocumentKind kind;
  String title;
  String templateId;
  DateTime updatedAt;
  bool isFavorite;
  double completionPercent;
  Map<String, dynamic> payload;
  /// Optional labels so variants of the same document (e.g. a resume
  /// tailored for different job applications) can be told apart at a
  /// glance. Both null on documents saved before this field existed.
  String? companyLabel;
  String? roleLabel;
  /// Set only when [templateId] is the "custom" sentinel — the AI-generated
  /// TemplateStyleSpec (see template_style_spec.dart) this document was
  /// rendered with, since "custom" has no corresponding named enum value
  /// for pdf_builder.dart's normal template dispatch to key off.
  Map<String, dynamic>? customStyleSpec;

  DocumentEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.templateId,
    required this.updatedAt,
    required this.payload,
    this.isFavorite = false,
    this.completionPercent = 0,
    this.companyLabel,
    this.roleLabel,
    this.customStyleSpec,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'templateId': templateId,
        'updatedAt': updatedAt.toIso8601String(),
        'isFavorite': isFavorite,
        'completionPercent': completionPercent,
        'payload': payload,
        'companyLabel': companyLabel,
        'roleLabel': roleLabel,
        'customStyleSpec': customStyleSpec,
      };

  factory DocumentEntry.fromJson(Map<String, dynamic> json) => DocumentEntry(
        id: json['id'],
        kind: DocumentKind.values.byName(json['kind']),
        title: json['title'] ?? '',
        templateId: json['templateId'] ?? '',
        updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
        isFavorite: json['isFavorite'] ?? false,
        completionPercent: (json['completionPercent'] ?? 0).toDouble(),
        payload: Map<String, dynamic>.from(json['payload'] ?? {}),
        companyLabel: json['companyLabel'],
        roleLabel: json['roleLabel'],
        customStyleSpec:
            json['customStyleSpec'] is Map ? Map<String, dynamic>.from(json['customStyleSpec']) : null,
      );

  String encode() => jsonEncode(toJson());

  factory DocumentEntry.decode(String source) => DocumentEntry.fromJson(jsonDecode(source));
}
