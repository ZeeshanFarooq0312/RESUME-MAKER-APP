import '../models/template_kind.dart';
import '../models/template_style_spec.dart';
import 'pdf_fonts.dart';
import 'templates/dynamic_resume_template.dart';

/// A curated Pro resume design: a named [TemplateStyleSpec] plus the
/// one-line description shown under it in pickers.
class ResumeDesign {
  final TemplateStyleSpec spec;
  final String tagline;
  const ResumeDesign(this.tagline, this.spec);
}

/// The curated Pro designs rendered by the template engine. Each combines a
/// layout, heading/body fonts, color, heading style and density so no two
/// read alike. To add a design: add a [ResumeTemplate] value and an entry
/// here — no new rendering code.
const resumeDesignPresets = <ResumeTemplate, ResumeDesign>{
  ResumeTemplate.aurora: ResumeDesign(
    'Teal sidebar, modern sans',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.sidebarLeft,
      accentColor: TemplateAccentColor.teal,
      headingFont: TemplateFont.poppins,
      bodyFont: TemplateFont.poppins,
      headingStyle: TemplateHeadingStyle.caps,
    ),
  ),
  ResumeTemplate.meridian: ResumeDesign(
    'Editorial split header',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.splitHeader,
      accentColor: TemplateAccentColor.navyBlue,
      headingFont: TemplateFont.plexSerif,
      bodyFont: TemplateFont.ptSans,
      headingStyle: TemplateHeadingStyle.underline,
    ),
  ),
  ResumeTemplate.sterling: ResumeDesign(
    'Timeless centered serif',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.plainHeader,
      headerStyle: TemplateHeaderStyle.centered,
      accentColor: TemplateAccentColor.charcoal,
      headingFont: TemplateFont.ptSerif,
      bodyFont: TemplateFont.ptSerif,
      headingStyle: TemplateHeadingStyle.underline,
    ),
  ),
  ResumeTemplate.vivid: ResumeDesign(
    'Bold violet banner',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.bannerHeader,
      accentColor: TemplateAccentColor.violet,
      headingFont: TemplateFont.poppins,
      bodyFont: TemplateFont.poppins,
      headingStyle: TemplateHeadingStyle.pill,
    ),
  ),
  ResumeTemplate.atlas: ResumeDesign(
    'Clean right-hand column',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.sidebarRight,
      accentColor: TemplateAccentColor.slate,
      headingFont: TemplateFont.ptSans,
      bodyFont: TemplateFont.ptSans,
      headingStyle: TemplateHeadingStyle.bar,
    ),
  ),
  ResumeTemplate.heritage: ResumeDesign(
    'Elegant book serif, airy',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.plainHeader,
      accentColor: TemplateAccentColor.burgundy,
      headingFont: TemplateFont.crimsonText,
      bodyFont: TemplateFont.lato,
      headingStyle: TemplateHeadingStyle.caps,
      density: TemplateDensity.spacious,
    ),
  ),
  ResumeTemplate.nova: ResumeDesign(
    'Plum sidebar with photo',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.sidebarLeft,
      accentColor: TemplateAccentColor.plum,
      headingFont: TemplateFont.lato,
      bodyFont: TemplateFont.lato,
      headingStyle: TemplateHeadingStyle.pill,
    ),
  ),
  ResumeTemplate.summit: ResumeDesign(
    'Green banner, centered',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.bannerHeader,
      headerStyle: TemplateHeaderStyle.centered,
      accentColor: TemplateAccentColor.forestGreen,
      headingFont: TemplateFont.ptSans,
      bodyFont: TemplateFont.ptSans,
      headingStyle: TemplateHeadingStyle.bar,
    ),
  ),
  ResumeTemplate.quartz: ResumeDesign(
    'Gold accents, split header',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.splitHeader,
      accentColor: TemplateAccentColor.gold,
      headingFont: TemplateFont.poppins,
      bodyFont: TemplateFont.lato,
      headingStyle: TemplateHeadingStyle.caps,
    ),
  ),
  ResumeTemplate.ivy: ResumeDesign(
    'Compact, fits more on a page',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.plainHeader,
      accentColor: TemplateAccentColor.forestGreen,
      headingFont: TemplateFont.plexSerif,
      bodyFont: TemplateFont.ptSans,
      headingStyle: TemplateHeadingStyle.bar,
      density: TemplateDensity.compact,
    ),
  ),
  ResumeTemplate.horizon: ResumeDesign(
    'Ocean blue side column',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.sidebarRight,
      accentColor: TemplateAccentColor.ocean,
      headingFont: TemplateFont.poppins,
      bodyFont: TemplateFont.lato,
      headingStyle: TemplateHeadingStyle.underline,
    ),
  ),
  ResumeTemplate.ember: ResumeDesign(
    'Warm rust banner, serif',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.bannerHeader,
      accentColor: TemplateAccentColor.rust,
      headingFont: TemplateFont.crimsonText,
      bodyFont: TemplateFont.ptSans,
      headingStyle: TemplateHeadingStyle.underline,
    ),
  ),
  ResumeTemplate.graphite: ResumeDesign(
    'Monochrome and modern',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.splitHeader,
      accentColor: TemplateAccentColor.black,
      headingFont: TemplateFont.ptSans,
      bodyFont: TemplateFont.ptSans,
      headingStyle: TemplateHeadingStyle.pill,
    ),
  ),
  ResumeTemplate.sage: ResumeDesign(
    'Serif sidebar, calm slate',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.sidebarLeft,
      accentColor: TemplateAccentColor.slate,
      headingFont: TemplateFont.ptSerif,
      bodyFont: TemplateFont.ptSans,
      headingStyle: TemplateHeadingStyle.underline,
    ),
  ),
  ResumeTemplate.prism: ResumeDesign(
    'Centered, crisp and compact',
    TemplateStyleSpec(
      layoutVariant: TemplateLayoutVariant.plainHeader,
      headerStyle: TemplateHeaderStyle.centered,
      accentColor: TemplateAccentColor.violet,
      headingFont: TemplateFont.poppins,
      bodyFont: TemplateFont.poppins,
      headingStyle: TemplateHeadingStyle.bar,
      density: TemplateDensity.compact,
    ),
  ),
};

/// The font families a resume template needs (only design-spec presets
/// use extra families), so callers load just those bytes into the
/// rendering isolate.
Set<PdfFontFamily> resumeFontsFor(ResumeTemplate template) {
  final design = resumeDesignPresets[template];
  return design == null ? const {} : DynamicResumeTemplate.fontsFor(design.spec);
}
