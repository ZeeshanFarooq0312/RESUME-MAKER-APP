import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/preview_scaffold.dart';
import '../models/template_kind.dart';
import 'ai_guard.dart';
import 'package:printing/printing.dart';
import 'template_screen.dart' show resumeTemplateLabel;
import 'package:screen_protector/screen_protector.dart';
import '../models/cover_letter_data.dart';
import '../models/document_entry.dart';
import '../pdf/pdf_builder.dart';
import '../pdf/templates/design_kit.dart';
import '../pdf/pdf_fonts.dart';
import '../pdf/resume_design_presets.dart';
import '../models/template_style_spec.dart';
import '../widgets/app_feedback.dart';
import '../widgets/design_customizer.dart';
import '../services/documents_repository.dart';
import '../services/subscription_repository.dart';
import 'cover_letter_template_screen.dart';

const _templateTitles = {
  CoverLetterTemplate.classic: 'Classic Cover Letter',
  CoverLetterTemplate.modern: 'Modern Cover Letter',
  CoverLetterTemplate.minimal: 'Minimal Cover Letter',
  CoverLetterTemplate.bold: 'Bold Cover Letter',
  CoverLetterTemplate.formal: 'Formal Cover Letter',
};

class CoverLetterPreviewScreen extends StatefulWidget {
  final CoverLetterData data;
  final CoverLetterTemplate template;
  final String? documentId;
  final bool isSample;
  final bool isPremium;
  final VoidCallback? onUseTemplate;

  /// A document's saved customization of a design-spec template.
  final TemplateStyleSpec? styleOverride;

  const CoverLetterPreviewScreen({
    super.key,
    required this.data,
    required this.template,
    this.documentId,
    this.isSample = false,
    this.isPremium = false,
    this.onUseTemplate,
    this.styleOverride,
  });

  @override
  State<CoverLetterPreviewScreen> createState() => _CoverLetterPreviewScreenState();
}

class _CoverLetterPreviewScreenState extends State<CoverLetterPreviewScreen> {
  bool _downloading = false;
  late Future<Uint8List> _pdfFuture = _generatePdf();

  /// The design spec for matching-set designs (null for hand-built ones),
  /// including any customization from the Style panel.
  late TemplateStyleSpec? _spec = widget.styleOverride ?? _presetSpec;
  TemplateStyleSpec? get _presetSpec => designFor(widget.template)?.spec;
  bool get _isCustomized => _spec != null && _spec!.encode() != _presetSpec?.encode();
  Timer? _rerender;

  @override
  void initState() {
    super.initState();
    _setScreenshotBlocking(true);
  }

  @override
  void dispose() {
    _rerender?.cancel();
    _setScreenshotBlocking(false);
    super.dispose();
  }

  Future<Uint8List> _generatePdf() async {
    final spec = _spec;
    final fontBytes = await PdfFonts.loadBytes(
      extra: spec != null ? DesignKit.fontsFor(spec) : documentFontsFor(widget.template),
    );
    final template = widget.template;
    final data = widget.data;
    return Isolate.run(() async {
      PdfFonts.primeFromBytes(fontBytes.regular, fontBytes.bold, fontBytes.extras);
      final doc = spec != null ? await buildDynamicCoverLetterDoc(data, spec) : await buildCoverLetterDoc(template, data);
      return doc.save();
    });
  }

  Future<void> _openStyle() async {
    final original = _presetSpec;
    final current = _spec;
    if (original == null || current == null) return;
    await showDesignCustomizer(
      context,
      initial: current,
      original: original,
      onChanged: (next) {
        _spec = next;
        // Re-render shortly after the last tap rather than on every one.
        _rerender?.cancel();
        _rerender = Timer(const Duration(milliseconds: 220), () {
          if (mounted) setState(() => _pdfFuture = _generatePdf());
        });
      },
    );
    await _saveStyle();
  }

  /// Stores the customization on the document so it reopens with it.
  Future<void> _saveStyle() async {
    final id = widget.documentId;
    if (id == null) return;
    final existing = await DocumentsRepository.find(id);
    if (existing == null) return;
    final spec = _isCustomized ? _spec!.toJson() : null;
    if (existing.templateId == widget.template.name && jsonEncode(existing.customStyleSpec) == jsonEncode(spec)) {
      return;
    }
    await DocumentsRepository.save(DocumentEntry(
      id: existing.id,
      kind: existing.kind,
      title: existing.title,
      templateId: widget.template.name,
      updatedAt: DateTime.now(),
      isFavorite: existing.isFavorite,
      companyLabel: existing.companyLabel,
      roleLabel: existing.roleLabel,
      customStyleSpec: spec,
      completionPercent: existing.completionPercent,
      payload: existing.payload,
    ));
    if (mounted) showToast(context, 'Style saved', tone: ToastTone.success);
  }

  void _setScreenshotBlocking(bool enabled) {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    if (enabled) {
      ScreenProtector.preventScreenshotOn();
    } else {
      ScreenProtector.preventScreenshotOff();
    }
  }

  String get _fileName =>
      '${widget.data.fullName.isEmpty ? "cover_letter" : "${widget.data.fullName.replaceAll(" ", "_")}_cover_letter"}.pdf';

  Future<void> _touchDocumentEntry() async {
    final id = widget.documentId;
    if (id == null) return;
    final entries = await DocumentsRepository.loadAll();
    final index = entries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final existing = entries[index];
    await DocumentsRepository.save(DocumentEntry(
      id: existing.id,
      kind: existing.kind,
      title: existing.title,
      templateId: widget.template.name,
      updatedAt: DateTime.now(),
      isFavorite: existing.isFavorite,
      companyLabel: existing.companyLabel,
      roleLabel: existing.roleLabel,
      customStyleSpec:
          _presetSpec != null ? (_isCustomized ? _spec!.toJson() : null) : existing.customStyleSpec,
      completionPercent: widget.data.completionPercent,
      payload: widget.data.toJson(),
    ));
  }

  Future<void> _onDownloadPressed() async {
    if (widget.isPremium && SubscriptionSession.tier.value == SubscriptionTier.basic) {
      await showProUpgradeSheet(context);
      return;
    }
    setState(() => _downloading = true);
    try {
      final bytes = await _pdfFuture;
      await Printing.sharePdf(bytes: bytes, filename: _fileName);
      await _touchDocumentEntry();
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }


  bool get _locked => widget.isPremium && SubscriptionSession.tier.value == SubscriptionTier.basic;

  @override
  Widget build(BuildContext context) {
    return PreviewScaffold(
      title: _templateTitles[widget.template] ?? '${resumeTemplateLabel(widget.template)} Cover Letter',
      subtitle: widget.isSample ? 'Template preview' : 'Your cover letter',
      isPro: widget.template.isPremium,
      pdf: _pdfFuture,
      isSample: widget.isSample,
      onShare: widget.isSample || _downloading ? null : _onDownloadPressed,
      tools: widget.isSample
          ? const []
          : [
              if (_spec != null) PreviewTool(icon: LucideIcons.palette, label: 'Style', onTap: _openStyle),
              PreviewTool(
                icon: LucideIcons.layoutTemplate,
                label: 'Change template',
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => CoverLetterTemplateScreen(data: widget.data, documentId: widget.documentId)),
                ),
              ),
            ],
      primaryLabel: widget.isSample
          ? 'Use this template'
          : _locked
              ? 'Upgrade to download'
              : 'Download PDF',
      primaryIcon: widget.isSample
          ? LucideIcons.arrowRight
          : _locked
              ? LucideIcons.crown
              : LucideIcons.download,
      primaryLoading: _downloading,
      onPrimary: widget.isSample ? widget.onUseTemplate : _onDownloadPressed,
    );
  }
}
