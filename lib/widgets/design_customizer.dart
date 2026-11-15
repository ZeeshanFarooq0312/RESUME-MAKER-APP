import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/template_style_spec.dart';
import '../pdf/templates/dynamic_resume_template.dart';
import 'auth/auth_kit.dart';

/// A heading + body font combination offered in the Style panel.
class _FontPairing {
  final String name;
  final TemplateFont heading;
  final TemplateFont body;
  final String uiHeadingFamily;
  const _FontPairing(this.name, this.heading, this.body, this.uiHeadingFamily);
}

const _pairings = [
  _FontPairing('Modern', TemplateFont.poppins, TemplateFont.poppins, 'Poppins'),
  _FontPairing('Clean', TemplateFont.lato, TemplateFont.lato, 'Lato'),
  _FontPairing('Neutral', TemplateFont.ptSans, TemplateFont.ptSans, 'PT Sans'),
  _FontPairing('Classic', TemplateFont.ptSerif, TemplateFont.ptSerif, 'PT Serif'),
  _FontPairing('Elegant', TemplateFont.crimsonText, TemplateFont.lato, 'Crimson Text'),
  _FontPairing('Editorial', TemplateFont.plexSerif, TemplateFont.ptSans, 'IBM Plex Serif'),
];

/// Opens the Style panel for a design-spec template. [onChanged] fires on
/// every tap so the caller can re-render the preview live above the panel;
/// the panel itself keeps no state the caller doesn't already have.
Future<void> showDesignCustomizer(
  BuildContext context, {
  required TemplateStyleSpec initial,
  required TemplateStyleSpec original,
  required ValueChanged<TemplateStyleSpec> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    // Light barrier so the live preview above stays visible.
    barrierColor: Colors.black.withValues(alpha: 0.12),
    builder: (_) => _DesignCustomizer(initial: initial, original: original, onChanged: onChanged),
  );
}

class _DesignCustomizer extends StatefulWidget {
  final TemplateStyleSpec initial;
  final TemplateStyleSpec original;
  final ValueChanged<TemplateStyleSpec> onChanged;
  const _DesignCustomizer({required this.initial, required this.original, required this.onChanged});

  @override
  State<_DesignCustomizer> createState() => _DesignCustomizerState();
}

class _DesignCustomizerState extends State<_DesignCustomizer> {
  late TemplateStyleSpec _spec = widget.initial;

  void _update(TemplateStyleSpec next) {
    setState(() => _spec = next);
    widget.onChanged(next);
  }

  bool get _isOriginal => _spec.toJson().toString() == widget.original.toJson().toString();

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Style',
                    style: TextStyle(fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w600, color: p.title)),
              ),
              if (!_isOriginal)
                TextButton.icon(
                  onPressed: () => _update(widget.original),
                  icon: const Icon(LucideIcons.rotateCcw, size: 16),
                  label: const Text('Reset'),
                  style: TextButton.styleFrom(foregroundColor: p.body),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const _Label('Color'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in TemplateAccentColor.values)
                _Swatch(
                  color: Color(DynamicResumeTemplate.accentArgb(c)),
                  selected: c == _spec.accentColor,
                  label: c.name,
                  onTap: () => _update(_spec.copyWith(accentColor: c)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const _Label('Font'),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pairings.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _pairings[i];
                final selected = f.heading == _spec.headingFont && f.body == _spec.bodyFont;
                return Semantics(
                  selected: selected,
                  button: true,
                  label: '${f.name} font',
                  child: GestureDetector(
                    onTap: () => _update(_spec.copyWith(headingFont: f.heading, bodyFont: f.body)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 92,
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? p.focus : p.fieldBorder, width: selected ? 2 : 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Aa',
                              style: TextStyle(
                                  fontFamily: f.uiHeadingFamily,
                                  fontSize: 24,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                  color: p.title)),
                          const SizedBox(height: 4),
                          Text(f.name,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected ? p.title : p.body)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          const _Label('Spacing'),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.fieldBorder),
            ),
            child: Row(
              children: [
                for (final d in TemplateDensity.values)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _update(_spec.copyWith(density: d)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: d == _spec.density ? p.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          d.name[0].toUpperCase() + d.name.substring(1),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: d == _spec.density ? p.onPrimary : p.body,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: p.muted)),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;
  const _Swatch({required this.color, required this.selected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: '$label color',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? p.focus : Colors.transparent, width: 2),
          ),
          child: Container(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: selected ? const Icon(LucideIcons.check, size: 16, color: Colors.white) : null,
          ),
        ),
      ),
    );
  }
}
