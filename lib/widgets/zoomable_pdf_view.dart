import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../theme/app_theme.dart';

/// A directly pinch-zoomable PDF preview. The printing package's `PdfPreview`
/// only zooms after a double-tap; here every page is rasterized once and laid
/// out inside a single [InteractiveViewer], so a two-finger pinch zooms
/// immediately and you can drag to pan/scroll through pages at any zoom level.
class ZoomablePdfView extends StatelessWidget {
  final Future<Uint8List> pdf;
  const ZoomablePdfView({super.key, required this.pdf});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: pdf,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || snap.data == null) {
          return const _PreviewError();
        }
        return _RasterPages(bytes: snap.data!);
      },
    );
  }
}

class _RasterPages extends StatefulWidget {
  final Uint8List bytes;
  const _RasterPages({required this.bytes});

  @override
  State<_RasterPages> createState() => _RasterPagesState();
}

class _RasterPagesState extends State<_RasterPages> {
  late Future<List<Uint8List>> _pages = _raster();

  @override
  void didUpdateWidget(covariant _RasterPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The preview's PDF can change (e.g. after translating the resume) — the
    // parent hands us new bytes, so re-rasterize when that happens.
    if (!identical(oldWidget.bytes, widget.bytes)) {
      _pages = _raster();
    }
  }

  Future<List<Uint8List>> _raster() async {
    final out = <Uint8List>[];
    // 200 DPI keeps text crisp even when pinched in toward the 5x max.
    await for (final page in Printing.raster(widget.bytes, dpi: 200)) {
      out.add(await page.toPng());
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Uint8List>>(
      future: _pages,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final pages = snap.data ?? const <Uint8List>[];
        if (pages.isEmpty) return const _PreviewError();

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const pad = 16.0;
            return InteractiveViewer(
              constrained: false,
              minScale: 1,
              maxScale: 5,
              boundaryMargin: const EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(
                width: width,
                child: Padding(
                  padding: const EdgeInsets.all(pad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < pages.length; i++) ...[
                        if (i > 0) const SizedBox(height: 14),
                        _PageCard(png: pages[i], width: width - pad * 2),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PageCard extends StatelessWidget {
  final Uint8List png;
  final double width;
  const _PageCard({required this.png, required this.width});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1030).withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(png, width: width, fit: BoxFit.fitWidth),
      ),
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          "Couldn't render this preview. Try again.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.slate600),
        ),
      ),
    );
  }
}
