import 'package:flutter/material.dart';
import '../models/resume_data.dart';
import 'profile_repository.dart';

/// Offers to pre-fill a brand-new resume from the user's already-completed
/// Profile (name, experience, education, skills) instead of making them
/// retype everything — asked every time a new resume is created, whether
/// via the "New Resume" quick action or by picking a template from the
/// Home carousel or Templates tab, and only when a Profile actually
/// exists. Returns a deep copy (via the JSON round trip ResumeData already
/// supports) so editing the new document never mutates the saved Profile.
/// Returns null for "start blank" or when there's no profile to offer.
Future<ResumeData?> promptResumeStartingData(BuildContext context) async {
  if (!await ProfileRepository.exists()) return null;
  if (!context.mounted) return null;
  final useProfile = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Start from your profile?'),
      content: const Text(
          "We can fill in your name, experience, education, and skills from your saved "
          "profile — you can still edit anything before saving."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Start Blank')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Use My Profile'),
        ),
      ],
    ),
  );
  if (useProfile != true) return null;
  final profile = await ProfileRepository.load();
  return profile == null ? null : ResumeData.fromJson(profile.toJson());
}
