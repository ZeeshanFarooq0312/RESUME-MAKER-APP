import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screen_protector/screen_protector.dart';
import '../models/resume_data.dart';
import '../pdf/templates/classic_template.dart';
import '../pdf/templates/compact_template.dart';
import '../pdf/templates/executive_template.dart';
import '../pdf/templates/harvard_template.dart';
import '../pdf/templates/minimal_template.dart';
import '../pdf/templates/modern_template.dart';
import '../pdf/templates/professional_template.dart';
import '../pdf/templates/simple_bold_template.dart';
import '../pdf/templates/technical_template.dart';
import '../services/download_credits_service.dart';
import '../theme/app_theme.dart';
import 'paywall_sheet.dart';
import 'template_screen.dart';

const _templateTitles = {
  ResumeTemplate.classic: 'Classic Resume',
  ResumeTemplate.modern: 'Modern Resume',
  ResumeTemplate.minimal: 'Minimal Resume',
  ResumeTemplate.professional: 'Professional Resume',
  ResumeTemplate.compact: 'Compact Resume',
  ResumeTemplate.executive: 'Executive Resume',
  ResumeTemplate.technical: 'Technical Resume',
  ResumeTemplate.simpleBold: 'Simple Bold Resume',
  ResumeTemplate.harvard: 'Harvard Resume',
};

Future<pw.Document> _buildDoc(ResumeTemplate template, ResumeData data) {
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
  }
}

class PreviewScreen extends StatefulWidget {
  final ResumeData resumeData;
  final ResumeTemplate template;

  const PreviewScreen({super.key, required this.resumeData, required this.template});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  int _credits = 0;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _refreshCredits();
    _setScreenshotBlocking(true);
  }

  @override
  void dispose() {
    _setScreenshotBlocking(false);
    super.dispose();
  }

  // screen_protector only ships native support for Android/iOS; calling it
  // on desktop/web platforms would throw a MissingPluginException.
  void _setScreenshotBlocking(bool enabled) {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    if (enabled) {
      ScreenProtector.preventScreenshotOn();
    } else {
      ScreenProtector.preventScreenshotOff();
    }
  }

  Future<void> _refreshCredits() async {
    final credits = await DownloadCreditsService.getCredits();
    if (mounted) setState(() => _credits = credits);
  }

  String get _fileName =>
      '${widget.resumeData.personalInfo.fullName.isEmpty ? "resume" : widget.resumeData.personalInfo.fullName.replaceAll(" ", "_")}.pdf';

  Future<void> _onDownloadPressed() async {
    if (_credits <= 0) {
      final unlocked = await showPaywallSheet(context);
      if (unlocked != true) return;
      await _refreshCredits();
    }

    setState(() => _downloading = true);
    try {
      final spent = await DownloadCreditsService.consumeCredit();
      if (!spent) return; // race with another download; bail safely
      final doc = await _buildDoc(widget.template, widget.resumeData);
      final bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: _fileName);
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
        await _refreshCredits();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_templateTitles[widget.template]!),
      ),
      body: Column(
        children: [
          Expanded(
            child: PdfPreview(
              build: (format) async {
                final doc = await _buildDoc(widget.template, widget.resumeData);
                return doc.save();
              },
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              pdfFileName: _fileName,
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE1E4E8))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _credits > 0
                          ? '$_credits download${_credits == 1 ? '' : 's'} available'
                          : 'Preview is free — \$3 unlocks 2 downloads',
                      style: const TextStyle(color: AppColors.slate600, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _downloading ? null : _onDownloadPressed,
                    icon: _downloading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(_credits > 0 ? Icons.download : Icons.lock_outline, size: 18),
                    label: Text(_credits > 0 ? 'Download PDF' : 'Unlock & Download'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
