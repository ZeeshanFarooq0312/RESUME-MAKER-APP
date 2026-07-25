import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'cover_letter_home_screen.dart';
import 'home_screen.dart';
import 'proposal_home_screen.dart';

/// Landing screen: pick which kind of document to work on. Each tile pushes
/// its own self-contained flow (home → form → template → preview) — the
/// three document types don't share data, only shared utilities (fonts,
/// download credits, bullet rendering).
class DocumentHomeScreen extends StatelessWidget {
  const DocumentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.slate900,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.description_outlined,
                    color: AppColors.gold, size: 28),
              ),
              const SizedBox(height: 24),
              Text('Smart Document Builder',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Build professional documents in minutes.\nWorks fully offline.',
                style: TextStyle(color: AppColors.slate600, height: 1.4, fontSize: 15),
              ),
              const SizedBox(height: 40),
              _DocumentTile(
                icon: Icons.badge_outlined,
                title: 'Resume',
                subtitle: 'Build an ATS-friendly CV',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _DocumentTile(
                icon: Icons.mail_outline,
                title: 'Cover Letter',
                subtitle: 'Write a letter to go with your application',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CoverLetterHomeScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _DocumentTile(
                icon: Icons.handshake_outlined,
                title: 'Proposal',
                subtitle: 'Pitch a project or a business proposal',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProposalHomeScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DocumentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E4E8)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.slate900, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: AppColors.slate600, fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
}
