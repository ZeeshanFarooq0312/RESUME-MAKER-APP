import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';
import '../widgets/auth/auth_kit.dart';
import 'favorites_tab_screen.dart';
import 'home_dashboard_screen.dart';
import 'settings_tab_screen.dart';
import 'templates_tab_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  late final _screens = [
    HomeDashboardScreen(onOpenTemplates: () => setState(() => _index = 1)),
    const TemplatesTabScreen(),
    FavoritesTabScreen(onGoHome: () => setState(() => _index = 0)),
    const SettingsTabScreen(),
  ];

  static const _items = [
    (icon: LucideIcons.house, activeIcon: LucideIcons600.house, label: 'Home'),
    (icon: LucideIcons.layoutGrid, activeIcon: LucideIcons600.layoutGrid, label: 'Templates'),
    (icon: LucideIcons.heart, activeIcon: LucideIcons600.heart, label: 'Saved'),
    (icon: LucideIcons.settings, activeIcon: LucideIcons600.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.fieldBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _items[i].icon,
                      activeIcon: _items[i].activeIcon,
                      label: _items[i].label,
                      selected: _index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill highlight behind the active tab.
/// One bottom-nav tab. The only selection indicator is the pill behind the
/// icon — no ink ripple, which previously drew a second highlight across the
/// whole item on every tap. A press dips the icon slightly, and switching
/// tabs gives a light haptic tick.
class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  void _handleTap() {
    if (!widget.selected) HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final selected = widget.selected;
    final color = selected ? p.title : p.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: _handleTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 60 : 44,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? p.primary.withValues(alpha: 0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedScale(
                  scale: _pressed ? 0.86 : 1,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: Icon(selected ? widget.activeIcon : widget.icon, color: color, size: 22),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
