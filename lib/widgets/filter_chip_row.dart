import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FilterChipRow<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final String Function(T) labelFor;
  final ValueChanged<T> onSelected;

  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final option = options[i];
          final isSelected = option == selected;
          return ChoiceChip(
            label: Text(labelFor(option)),
            selected: isSelected,
            onSelected: (_) => onSelected(option),
            showCheckmark: false,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.slate600,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            backgroundColor: Colors.white,
            selectedColor: AppColors.primary,
            side: BorderSide(color: isSelected ? AppColors.primary : const Color(0xFFE7E5F3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }
}
