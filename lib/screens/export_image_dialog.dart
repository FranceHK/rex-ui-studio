import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../icons/app_icons.dart';
import '../models/ui_element.dart';
import '../services/flutter_export.dart' show className;
import '../widgets/element_view.dart';

/// One screen drawn as an image: the background color plus its elements.
class ArtboardPicture extends StatelessWidget {
  const ArtboardPicture({super.key, required this.page, this.background});

  final DesignPage page;

  /// null = the screen's background color; [Colors.transparent] = no background.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: page.size,
      child: ColoredBox(
        color: background ?? page.background,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final e in page.visibleElements)
              Positioned.fromRect(
                rect: e.rect,
                child: ElementView(element: e),
              ),
          ],
        ),
      ),
    );
  }
}

/// The image file name, e.g. "LoginScreen@2x.png".
String imageFileName(DesignPage page, double scale) {
  final s = scale == scale.roundToDouble()
      ? scale.toInt().toString()
      : scale.toString();
  return '${className(page.name)}@${s}x.png';
}

/// The "Export image" dialog: pick a screen, a scale (1x–4x) and background.
Future<void> showExportImage(
  BuildContext context, {
  required List<DesignPage> pages,
  required int initialIndex,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ExportImageDialog(pages: pages, initialIndex: initialIndex),
  );
}

class ExportImageDialog extends StatefulWidget {
  const ExportImageDialog({
    super.key,
    required this.pages,
    this.initialIndex = 0,
  });

  final List<DesignPage> pages;
  final int initialIndex;

  @override
  State<ExportImageDialog> createState() => _ExportImageDialogState();
}

class _ExportImageDialogState extends State<ExportImageDialog> {
  final _boundary = GlobalKey();
  late int _index = widget.initialIndex.clamp(0, widget.pages.length - 1);
  double _scale = 2;
  bool _transparent = false;
  bool _busy = false;
  String? _error;

  DesignPage get page => widget.pages[_index];

  /// PNG image of the selected screen at [_scale].
  Future<Uint8List> _render() async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: _scale);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await _render();
      final name = imageFileName(page, _scale);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: name)],
          fileNameOverrides: [name],
          downloadFallbackEnabled: true,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not export the image: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final px = page.size * _scale;
    return AlertDialog(
      title: const Text('Export image'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.pages.length > 1) ...[
              DropdownButtonFormField<int>(
                initialValue: _index,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Screen'),
                items: [
                  for (final (i, p) in widget.pages.indexed)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${p.name} · ${p.device.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (i) => setState(() => _index = i ?? _index),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              height: 260,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FittedBox(
                child: RepaintBoundary(
                  key: _boundary,
                  child: ArtboardPicture(
                    page: page,
                    background: _transparent ? Colors.transparent : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Scale'),
            const SizedBox(height: 6),
            SegmentedButton<double>(
              segments: [
                for (final s in const [1.0, 2.0, 3.0, 4.0])
                  ButtonSegment(value: s, label: Text('${s.toInt()}x')),
              ],
              selected: {_scale},
              onSelectionChanged: (v) => setState(() => _scale = v.first),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transparent background'),
              value: _transparent,
              onChanged: (v) => setState(() => _transparent = v),
            ),
            Text(
              'PNG · ${px.width.round()} × ${px.height.round()} px · '
              '${imageFileName(page, _scale)}',
              style: TextStyle(color: scheme.outline, fontSize: 12),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 8),
              Text(error, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _export,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.image, size: 18),
          label: const Text('Export PNG'),
        ),
      ],
    );
  }
}
