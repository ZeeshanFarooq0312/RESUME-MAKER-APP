import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  final double percent; // 0-100
  final double height;

  const ProgressBar({super.key, required this.percent, this.height = 5});

  @override
  Widget build(BuildContext context) {
    final fraction = (percent.clamp(0, 100)) / 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: height,
        backgroundColor: AppColors.slate100,
        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
      ),
    );
  }
}
