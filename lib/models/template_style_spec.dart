import 'dart:convert';

/// A curated, enum-backed palette (not freeform hex) so an AI-generated
/// style spec always renders legibly — colors are chosen from the same set
/// already proven across the app's hand-built templates.
enum TemplateAccentColor { violet, forestGreen, navyBlue, burgundy, gold, charcoal, teal, slate, plum, rust, ocean, black }

/// Structural layout choices the flexible renderer ([DynamicResumeTemplate])
/// knows how to build. Sidebar layouts put contact, skills and education in
/// a side column (and flow across pages); split header puts the name left
/// and contact details right.
enum TemplateLayoutVariant { plainHeader, bannerHeader, sidebarLeft, sidebarRight, splitHeader }

/// How section headings ("EXPERIENCE", …) are drawn.
enum TemplateHeadingStyle { caps, underline, bar, pill }

/// Type families for headings and body text. Mapped to bundled static TTFs
/// by the renderer (PdfFontFamily), so the model stays free of PDF types.
enum TemplateFont { lato, poppins, ptSerif, ptSans, crimsonText, plexSerif }

enum TemplateDensity { compact, comfortable, spacious }

enum TemplateHeaderStyle { leftAligned, centered }

enum TemplateSection { summary, experience, education, skills }

/// A structured, renderable description of a resume's visual style — the
/// output of AI template generation (see GroqService.generateTemplateStyleSpec)
/// and the input to DynamicResumeTemplate.build. Every field is an enum (or
/// a validated list of enums), so the renderer can never receive a value it
/// doesn't know how to draw.
class TemplateStyleSpec {
  final TemplateAccentColor accentColor;
  final TemplateLayoutVariant layoutVariant;
  final TemplateDensity density;
  final TemplateHeaderStyle headerStyle;
  final List<TemplateSection> sectionOrder;
  final TemplateHeadingStyle headingStyle;
  final TemplateFont headingFont;
  final TemplateFont bodyFont;

  /// Sidebar layouts only: show the profile photo when one is set.
  final bool showPhoto;

  static const List<TemplateSection> defaultSectionOrder = [
    TemplateSection.summary,
    TemplateSection.experience,
    TemplateSection.education,
    TemplateSection.skills,
  ];

  const TemplateStyleSpec({
    this.accentColor = TemplateAccentColor.navyBlue,
    this.layoutVariant = TemplateLayoutVariant.plainHeader,
    this.density = TemplateDensity.comfortable,
    this.headerStyle = TemplateHeaderStyle.leftAligned,
    this.sectionOrder = defaultSectionOrder,
    this.headingStyle = TemplateHeadingStyle.caps,
    this.headingFont = TemplateFont.lato,
    this.bodyFont = TemplateFont.lato,
    this.showPhoto = true,
  });

  TemplateStyleSpec copyWith({
    TemplateAccentColor? accentColor,
    TemplateDensity? density,
    TemplateFont? headingFont,
    TemplateFont? bodyFont,
  }) =>
      TemplateStyleSpec(
        accentColor: accentColor ?? this.accentColor,
        layoutVariant: layoutVariant,
        density: density ?? this.density,
        headerStyle: headerStyle,
        sectionOrder: sectionOrder,
        headingStyle: headingStyle,
        headingFont: headingFont ?? this.headingFont,
        bodyFont: bodyFont ?? this.bodyFont,
        showPhoto: showPhoto,
      );

  Map<String, dynamic> toJson() => {
        'accentColor': accentColor.name,
        'layoutVariant': layoutVariant.name,
        'density': density.name,
        'headerStyle': headerStyle.name,
        'sectionOrder': sectionOrder.map((s) => s.name).toList(),
        'headingStyle': headingStyle.name,
        'headingFont': headingFont.name,
        'bodyFont': bodyFont.name,
        'showPhoto': showPhoto,
      };

  /// Parses untrusted JSON (AI output or stored data) field-by-field,
  /// silently falling back to a sane default for any missing/unrecognized
  /// value instead of throwing — so a partially-malformed AI response still
  /// produces a renderable spec rather than failing the whole generation.
  factory TemplateStyleSpec.fromJson(Map<String, dynamic> json) {
    T enumOrDefault<T>(List<T> values, dynamic raw, T fallback) {
      if (raw is! String) return fallback;
      for (final v in values) {
        if ((v as Enum).name == raw) return v;
      }
      return fallback;
    }

    List<TemplateSection> sections() {
      final raw = json['sectionOrder'];
      if (raw is! List) return defaultSectionOrder;
      final parsed = <TemplateSection>[];
      for (final s in raw) {
        for (final section in TemplateSection.values) {
          if (section.name == s && !parsed.contains(section)) {
            parsed.add(section);
          }
        }
      }
      // Append any section the AI omitted, so no content is ever silently
      // dropped from the rendered document.
      for (final section in TemplateSection.values) {
        if (!parsed.contains(section)) parsed.add(section);
      }
      return parsed;
    }

    return TemplateStyleSpec(
      accentColor: enumOrDefault(TemplateAccentColor.values, json['accentColor'], TemplateAccentColor.navyBlue),
      layoutVariant:
          enumOrDefault(TemplateLayoutVariant.values, json['layoutVariant'], TemplateLayoutVariant.plainHeader),
      density: enumOrDefault(TemplateDensity.values, json['density'], TemplateDensity.comfortable),
      headerStyle: enumOrDefault(TemplateHeaderStyle.values, json['headerStyle'], TemplateHeaderStyle.leftAligned),
      sectionOrder: sections(),
      headingStyle: enumOrDefault(TemplateHeadingStyle.values, json['headingStyle'], TemplateHeadingStyle.caps),
      headingFont: enumOrDefault(TemplateFont.values, json['headingFont'], TemplateFont.lato),
      bodyFont: enumOrDefault(TemplateFont.values, json['bodyFont'], TemplateFont.lato),
      showPhoto: json['showPhoto'] is bool ? json['showPhoto'] as bool : true,
    );
  }

  String encode() => jsonEncode(toJson());

  factory TemplateStyleSpec.decode(String source) => TemplateStyleSpec.fromJson(jsonDecode(source));
}
