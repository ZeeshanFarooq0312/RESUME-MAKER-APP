import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import 'auth/auth_kit.dart';
import 'responsive_scaffold.dart';
import 'zoomable_pdf_view.dart';

/// A secondary action shown as a labeled tool button above the main CTA
/// (e.g. Translate, Cover letter) — visible instead of hidden in a ⋮ menu.
class PreviewTool {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const PreviewTool({required this.icon, required this.label, required this.onTap});
}

/// Shared layout for every document preview (resume, cover letter,
/// proposal, custom template): titled app bar, the zoomable PDF on a soft
/// stage, an optional banner, tool buttons, and one primary action.
class PreviewScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isPro;
  final Future<Uint8List> pdf;
  final bool isSample;
  final Widget? banner;
  final List<PreviewTool> tools;
  final String primaryLabel;
  final IconData? primaryIcon;
  final bool primaryLoading;
  final VoidCallback? onPrimary;
  final VoidCallback? onShare;

  const PreviewScaffold({
    super.key,
    required this.title,
    required this.pdf,
    required this.primaryLabel,
    required this.onPrimary,
    this.subtitle,
    this.isPro = false,
    this.isSample = false,
    this.banner,
    this.tools = const [],
    this.primaryIcon,
    this.primaryLoading = false,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Fraunces', fontSize: 19, fontWeight: FontWeight.w600, color: p.title),
                  ),
                ),
                if (isPro) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.accentGold, borderRadius: BorderRadius.circular(999)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.crown, size: 10, color: AppColors.ink),
                        SizedBox(width: 3),
                        Text('PRO',
                            style: TextStyle(
                                fontFamily: 'Inter', fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (subtitle != null)
              Text(subtitle!, style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: p.body)),
          ],
        ),
        actions: [
          if (onShare != null)
            IconButton(tooltip: 'Share', icon: const Icon(LucideIcons.share2, size: 21), onPressed: onShare),
          const SizedBox(width: 4),
        ],
      ),
      body: ResponsiveContentBound(
        maxWidth: 820,
        child: Column(
          children: [
            if (isSample)
              const _Banner(
                icon: LucideIcons.info,
                text: 'Sample content. Use this template to fill it with your own details.',
              ),
            if (banner != null) banner!,
            Expanded(
              child: Container(
                color: dark ? const Color(0xFF0E0D16) : const Color(0xFFECEBF2),
                child: Stack(
                  children: [
                    Positioned.fill(child: ZoomablePdfView(pdf: pdf)),
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.ink.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.zoomIn, size: 13, color: Colors.white),
                                SizedBox(width: 5),
                                Text('Pinch to zoom',
                                    style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.fieldBorder))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tools.isNotEmpty) ...[
                      Row(
                        children: [
                          for (var i = 0; i < tools.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: _ToolButton(tool: tools[i])),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    AuthPrimaryButton(
                      label: primaryLabel,
                      trailingIcon: primaryIcon,
                      loading: primaryLoading,
                      onPressed: onPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final PreviewTool tool;
  const _ToolButton({required this.tool});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Material(
      color: p.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: tool.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            children: [
              Icon(tool.icon, size: 20, color: p.title),
              const SizedBox(height: 5),
              Text(
                tool.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.title),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin full-width notice strip under the app bar.
class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Banner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => PreviewBanner(icon: icon, text: text);
}

/// Public notice strip (e.g. "Translated to Spanish · Undo").
class PreviewBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const PreviewBanner({super.key, required this.icon, required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 10, actionLabel != null ? 8 : 20, 10),
      color: AppColors.accentGold.withValues(alpha: 0.14),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.accentGoldDeep),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.35, color: p.title))),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: p.title,
                textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
