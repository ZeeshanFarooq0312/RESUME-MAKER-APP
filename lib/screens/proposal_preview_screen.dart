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
import 'package:screen_protector/screen_protector.dart';
import '../models/document_entry.dart';
import '../models/proposal_data.dart';
import '../pdf/pdf_builder.dart';
import '../pdf/pdf_fonts.dart';
import '../services/documents_repository.dart';
import '../services/subscription_repository.dart';
import 'proposal_template_screen.dart';

const _templateTitles = {
  ProposalTemplate.classic: 'Classic Proposal',
  ProposalTemplate.modern: 'Modern Proposal',
  ProposalTemplate.minimal: 'Minimal Proposal',
  ProposalTemplate.corporate: 'Corporate Proposal',
  ProposalTemplate.executive: 'Executive Proposal',
};

class ProposalPreviewScreen extends StatefulWidget {
  final ProposalData data;
  final ProposalTemplate template;
  final String? documentId;
  final bool isSample;
  final bool isPremium;
  final VoidCallback? onUseTemplate;

  const ProposalPreviewScreen({
    super.key,
    required this.data,
    required this.template,
    this.documentId,
    this.isSample = false,
    this.isPremium = false,
    this.onUseTemplate,
  });

  @override
  State<ProposalPreviewScreen> createState() => _ProposalPreviewScreenState();
}

class _ProposalPreviewScreenState extends State<ProposalPreviewScreen> {
  bool _downloading = false;
  late final Future<Uint8List> _pdfFuture = _generatePdf();

  @override
  void initState() {
    super.initState();
    _setScreenshotBlocking(true);
  }

  @override
  void dispose() {
    _setScreenshotBlocking(false);
    super.dispose();
  }

  Future<Uint8List> _generatePdf() async {
    final fontBytes = await PdfFonts.loadBytes();
    final template = widget.template;
    final data = widget.data;
    return Isolate.run(() async {
      PdfFonts.primeFromBytes(fontBytes.regular, fontBytes.bold);
      final doc = await buildProposalDoc(template, data);
      return doc.save();
    });
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
      '${widget.data.title.isEmpty ? "proposal" : widget.data.title.replaceAll(" ", "_")}.pdf';

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
      customStyleSpec: existing.customStyleSpec,
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
      title: _templateTitles[widget.template]!,
      subtitle: widget.isSample ? 'Template preview' : 'Your proposal',
      isPro: widget.template.isPremium,
      pdf: _pdfFuture,
      isSample: widget.isSample,
      onShare: widget.isSample || _downloading ? null : _onDownloadPressed,
      tools: widget.isSample
          ? const []
          : [
              PreviewTool(
                icon: LucideIcons.layoutTemplate,
                label: 'Change template',
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => ProposalTemplateScreen(data: widget.data, documentId: widget.documentId)),
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
