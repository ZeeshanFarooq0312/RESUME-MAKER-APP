import 'package:flutter/material.dart';
import 'auth/auth_kit.dart';

/// Horizontally scrolling single-select chips, with optional counts
/// ("Resume  9").
class FilterChipRow<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final String Function(T) labelFor;
  final ValueChanged<T> onSelected;
  final int Function(T)? countFor;

  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
    this.countFor,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final option = options[i];
          final isSelected = option == selected;
          final count = countFor?.call(option);
          return Semantics(
            selected: isSelected,
            button: true,
            child: Material(
              color: isSelected ? p.primary : p.surface,
              shape: StadiumBorder(side: BorderSide(color: isSelected ? p.primary : p.fieldBorder)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labelFor(option),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? p.onPrimary : p.title,
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? p.onPrimary.withValues(alpha: 0.7) : p.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
