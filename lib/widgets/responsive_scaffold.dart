import 'package:flutter/material.dart';
import '../theme/app_breakpoints.dart';

/// Stops content stretching edge-to-edge on wide screens (tablets,
/// desktop, landscape) by centering it within a max width. The app has no
/// such bound today — every screen uses `Expanded`/`double.infinity` and
/// just stretches wider instead of reflowing — this is the fix for that on
/// screens whose content doesn't need a grid/wrap reflow of its own.
class ResponsiveContentBound extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContentBound({
    super.key,
    required this.child,
    this.maxWidth = 900,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A grid whose column count adapts to available width via
/// [AppBreakpoints.columnsFor], instead of a hardcoded crossAxisCount — the
/// drop-in replacement for every `GridView.count`/`GridView.builder(...,
/// SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2))` call in
/// the app today.
class AdaptiveGrid extends StatelessWidget {
  final List<Widget>? children;
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const AdaptiveGrid.count({
    super.key,
    required List<Widget> this.children,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.childAspectRatio = 0.78,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  })  : itemCount = null,
        itemBuilder = null;

  const AdaptiveGrid.builder({
    super.key,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.childAspectRatio = 0.78,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  }) : children = null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AppBreakpoints.columnsFor(constraints.maxWidth);
        final delegate = SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childAspectRatio: childAspectRatio,
        );
        if (children != null) {
          return GridView.count(
            padding: padding,
            shrinkWrap: shrinkWrap,
            physics: physics,
            crossAxisCount: columns,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: childAspectRatio,
            children: children!,
          );
        }
        return GridView.builder(
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: itemCount!,
          gridDelegate: delegate,
          itemBuilder: itemBuilder!,
        );
      },
    );
  }
}

/// A row that reflows into a wrap at medium+ widths instead of crowding or
/// clipping at phone widths — for things like a row of quick-action cards
/// that's fine as a `Row` on a phone but needs to stop just stretching
/// wider (and instead wrap) once there's tablet-width space to use.
class AdaptiveWrapRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const AdaptiveWrapRow({
    super.key,
    required this.children,
    this.spacing = 10,
    this.runSpacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.medium) {
          return Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: children[i]),
              ],
            ],
          );
        }
        // At medium+ width, size each item to roughly a quarter of the
        // available width (minus gaps) so cards stay a sensible card-sized
        // width instead of stretching to fill a tablet-wide row.
        final itemWidth = (constraints.maxWidth - spacing * (children.length - 1)) / 4;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final c in children) SizedBox(width: itemWidth.clamp(140, 220), child: c),
          ],
        );
      },
    );
  }
}
