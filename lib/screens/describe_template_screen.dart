import 'package:flutter/material.dart';
import 'ai_guard.dart';
import '../widgets/app_feedback.dart';
import '../data/sample_documents.dart';
import '../models/resume_data.dart';
import '../models/template_style_spec.dart';
import '../services/ai_usage_tracker.dart';
import '../services/groq_service.dart';
import '../services/subscription_repository.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/ai_tool_kit.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/responsive_scaffold.dart';
import 'dynamic_preview_screen.dart';

/// "Describe your own template": the user types (or scans/dictates, in a
/// later iteration) what they want their resume to look like, AI turns that
/// into a TemplateStyleSpec, and DynamicResumeTemplate renders it. A
/// Pro-tier feature, consistent with every other premium template — gated
/// the same way as the rest of the app's AI features (daily quota) plus a
/// subscription check up front, since generating a custom template is
/// itself the premium capability here, not just downloading it.
class DescribeTemplateScreen extends StatefulWidget {
  final ResumeData resumeData;
  final String? documentId;
  const DescribeTemplateScreen({super.key, required this.resumeData, this.documentId});

  @override
  State<DescribeTemplateScreen> createState() => _DescribeTemplateScreenState();
}

class _DescribeTemplateScreenState extends State<DescribeTemplateScreen> {
  final _description = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }



  Future<void> _onGenerate() async {
    final description = _description.text.trim();
    if (description.isEmpty) {
      showToast(context, 'Describe how you want your resume to look first.', tone: ToastTone.info);
      return;
    }
    if (SubscriptionSession.tier.value != SubscriptionTier.pro) {
      showProUpgradeSheet(context, title: 'Custom templates are a Pro feature', message: 'Upgrade to Pro to describe your own template and let AI design it for you.');
      return;
    }
    if (!GroqService.isConfigured) {
      showAiUnavailableSheet(context);
      return;
    }
    if (!await AiUsageTracker.canUseAi()) {
      if (mounted) {
        showAiLimitSheet(context);
      }
      return;
    }
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final spec = await GroqService.generateTemplateStyleSpec(description: description);
      await AiUsageTracker.recordUsage();
      if (!mounted) return;
      _openPreview(spec);
    } on AiServiceException catch (e) {
      if (mounted) {
        showToast(context, e.message, tone: ToastTone.error);
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Something went wrong. Please try again.', tone: ToastTone.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openPreview(TemplateStyleSpec spec) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DynamicPreviewScreen(
          resumeData: sampleResumeData(),
          styleSpec: spec,
          isSample: true,
          onUseTemplate: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DynamicPreviewScreen(
                resumeData: widget.resumeData,
                styleSpec: spec,
                documentId: widget.documentId,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _examples = [
    'Minimal and spacious, charcoal accents',
    'Bold with a dark green banner header',
    'Elegant serif headings, navy and gold',
    'Modern two columns with a teal sidebar',
  ];

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        leading: IconButton(
            tooltip: 'Back', icon: const Icon(LucideIcons.arrowLeft), onPressed: () => Navigator.maybePop(context)),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveContentBound(
          maxWidth: 720,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const AiToolHeader(
                icon: LucideIcons.wandSparkles,
                title: 'Design your own template',
                subtitle: 'Describe the look you want, like colors, mood and layout, and AI builds a template '
                    'to match.',
              ),
              const StepHeading(number: 1, title: 'Describe the look'),
              AuthField(
                dense: true,
                label: 'Your description',
                hint: 'e.g. Clean and modern with a deep blue header and lots of white space',
                controller: _description,
                maxLines: 8,
                minLines: 5,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 18),
              Text('Need ideas? Tap one to start from it.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.body)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _examples)
                    ToolPill(
                      icon: LucideIcons.palette,
                      label: e,
                      onPressed: () => setState(() {
                        _description.text = e;
                        _description.selection = TextSelection.collapsed(offset: e.length);
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AiActionBar(
        label: _loading ? 'Designing…' : 'Create my template',
        icon: LucideIcons.wandSparkles,
        loading: _loading,
        onPressed: _onGenerate,
      ),
    );
  }
}
