import 'dart:convert';

/// A curated, enum-backed palette (not freeform hex) so an AI-generated
/// style spec always renders legibly — colors are chosen from the same set
/// already proven across the app's hand-built templates.
enum TemplateAccentColor { violet, forestGreen, navyBlue, burgundy, gold, charcoal, teal, slate }

/// Structural layout choices the flexible renderer ([DynamicResumeTemplate])
/// knows how to build. Limited to the two layouts already proven in the
/// hand-built templates (plain header vs colored banner header) rather than
/// an untested sidebar layout.
enum TemplateLayoutVariant { plainHeader, bannerHeader }

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

  static const List<TemplateSection> defaultSectionOrder = [
    TemplateSection.summary,
    TemplateSection.experience,
    TemplateSection.education,
    TemplateSection.skills,
  ];

  TemplateStyleSpec({
    this.accentColor = TemplateAccentColor.navyBlue,
    this.layoutVariant = TemplateLayoutVariant.plainHeader,
    this.density = TemplateDensity.comfortable,
    this.headerStyle = TemplateHeaderStyle.leftAligned,
    this.sectionOrder = defaultSectionOrder,
  });

  Map<String, dynamic> toJson() => {
        'accentColor': accentColor.name,
        'layoutVariant': layoutVariant.name,
        'density': density.name,
        'headerStyle': headerStyle.name,
        'sectionOrder': sectionOrder.map((s) => s.name).toList(),
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
    );
  }

  String encode() => jsonEncode(toJson());

  factory TemplateStyleSpec.decode(String source) => TemplateStyleSpec.fromJson(jsonDecode(source));
}
