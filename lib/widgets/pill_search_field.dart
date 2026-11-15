import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'auth/auth_kit.dart';

/// Rounded search field with a clear button.
class PillSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const PillSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search',
  });

  @override
  State<PillSearchField> createState() => _PillSearchFieldState();
}

class _PillSearchFieldState extends State<PillSearchField> {
  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final hasText = widget.controller.text.isNotEmpty;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.fieldBorder),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(LucideIcons.search, size: 19, color: p.muted),
          Expanded(
            child: TextField(
              controller: widget.controller,
              onChanged: (v) {
                setState(() {});
                widget.onChanged(v);
              },
              textInputAction: TextInputAction.search,
              cursorColor: p.focus,
              style: TextStyle(fontSize: 15, color: p.title),
              decoration: InputDecoration(
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: TextStyle(fontSize: 15, color: p.muted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
              ),
            ),
          ),
          if (hasText)
            IconButton(
              tooltip: 'Clear',
              icon: Icon(LucideIcons.x, size: 18, color: p.muted),
              onPressed: () {
                widget.controller.clear();
                setState(() {});
                widget.onChanged('');
              },
            ),
        ],
      ),
    );
  }
}
