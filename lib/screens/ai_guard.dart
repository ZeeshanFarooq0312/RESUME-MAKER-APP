import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/ai_usage_tracker.dart';
import '../services/groq_service.dart';
import '../widgets/auth/auth_kit.dart';
import 'paywall_screen.dart';

/// The single place every AI entry point checks availability, and the single
/// Pro-upsell sheet, replacing the per-screen copies of these dialogs.

/// Checks AI is configured and within the daily limit, showing the right
/// sheet if not. Returns true when the caller may make an AI request.
Future<bool> ensureAiAvailable(BuildContext context) async {
  if (!GroqService.isConfigured) {
    await showAiUnavailableSheet(context);
    return false;
  }
  if (!await AiUsageTracker.canUseAi()) {
    if (context.mounted) await showAiLimitSheet(context);
    return false;
  }
  return context.mounted;
}

Future<void> showAiUnavailableSheet(BuildContext context) {
  return showPromptSheet(
    context,
    icon: LucideIcons.cloudOff,
    title: "AI isn't available right now",
    message: 'AI features are temporarily unavailable in this version. Everything else in the app still works.',
    primaryLabel: 'OK',
  );
}

Future<void> showAiLimitSheet(BuildContext context) async {
  final upgrade = await showPromptSheet(
    context,
    icon: LucideIcons.hourglass,
    title: "You've used today's free AI",
    message: 'Upgrade to Pro for unlimited AI summaries, rewrites, cover letters and tailored resumes, '
        'or come back tomorrow.',
    primaryLabel: 'See Pro plans',
    secondaryLabel: 'Not now',
  );
  if (upgrade == true && context.mounted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
  }
}

/// Upsell for a Pro-only template or feature.
Future<void> showProUpgradeSheet(
  BuildContext context, {
  String title = 'This is a Pro template',
  String message = 'Upgrade to Pro to download and share premium templates, plus get unlimited AI.',
}) async {
  final upgrade = await showPromptSheet(
    context,
    icon: LucideIcons.crown,
    title: title,
    message: message,
    primaryLabel: 'See Pro plans',
    secondaryLabel: 'Not now',
  );
  if (upgrade == true && context.mounted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
  }
}
