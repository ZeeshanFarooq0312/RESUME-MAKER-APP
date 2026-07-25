import 'package:flutter/material.dart';
import '../models/cover_letter_data.dart';
import '../theme/app_theme.dart';
import 'cover_letter_preview_screen.dart';

enum CoverLetterTemplate { classic, modern, minimal }

class CoverLetterTemplateScreen extends StatelessWidget {
  final CoverLetterData data;
  const CoverLetterTemplateScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a Template')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _TemplateCard(
              title: 'Classic',
              accentColor: AppColors.slate600,
              onTap: () => _openPreview(context, CoverLetterTemplate.classic),
            ),
            _TemplateCard(
              title: 'Modern',
              accentColor: AppColors.gold,
              onTap: () => _openPreview(context, CoverLetterTemplate.modern),
            ),
            _TemplateCard(
              title: 'Minimal',
              accentColor: AppColors.slate400,
              onTap: () => _openPreview(context, CoverLetterTemplate.minimal),
            ),
          ],
        ),
      ),
    );
  }

  void _openPreview(BuildContext context, CoverLetterTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoverLetterPreviewScreen(data: data, template: template),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final String title;
  final Color accentColor;
  final VoidCallback onTap;

  const _TemplateCard({required this.title, required this.accentColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1E4E8)),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 6, width: 60, color: AppColors.slate400),
                            const SizedBox(height: 8),
                            Container(height: 3, width: 40, color: const Color(0xFFD8DCE0)),
                            const SizedBox(height: 12),
                            Container(height: 3, width: double.infinity, color: const Color(0xFFE1E4E8)),
                            const SizedBox(height: 4),
                            Container(height: 3, width: double.infinity, color: const Color(0xFFE1E4E8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
