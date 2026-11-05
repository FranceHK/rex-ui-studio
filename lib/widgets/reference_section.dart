import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../models/reference_image.dart';
import '../services/reference_import.dart';
import '../state/editor_controller.dart';
import 'layout_panels.dart' show SectionLabel;

/// Loads a picture (e.g. a screenshot of an app to clone) onto the screen
/// to trace over, and controls how it is shown.
class ReferenceSection extends StatelessWidget {
  const ReferenceSection({super.key, required this.controller, this.pick});

  final EditorController controller;

  /// Picks the image; defaults to the system file picker (tests swap it).
  final Future<ReferenceImage?> Function()? pick;

  Future<void> _load(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final image = await (pick ?? pickReferenceImage)();
      if (image == null) return;
      final old = controller.page.reference;
      // A replaced image keeps the previous display settings
      controller.setReference(
        old == null
            ? image
            : ReferenceImage(
                bytes: image.bytes,
                pixelSize: image.pixelSize,
                opacity: old.opacity,
                onTop: old.onTop,
                fit: old.fit,
              ),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not load the image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final r = c.page.reference;
    final scheme = Theme.of(context).colorScheme;

    if (r == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Reference image'),
          OutlinedButton.icon(
            icon: const Icon(AppIcons.image, size: 18),
            label: const Text('Add reference image'),
            onPressed: () => _load(context),
          ),
          const SizedBox(height: 6),
          Text(
            'Put a screenshot of an app on this screen and trace over it. '
            'It is never exported.',
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Reference image',
          trailing: IconButton(
            tooltip: r.visible ? 'Hide reference' : 'Show reference',
            visualDensity: VisualDensity.compact,
            icon: Icon(r.visible ? AppIcons.view : AppIcons.hidden, size: 18),
            onPressed: () => c.setReference(r.copyWith(visible: !r.visible)),
          ),
        ),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                r.bytes,
                width: 40,
                height: 56,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${r.pixelSize.width.round()} × '
                '${r.pixelSize.height.round()} px',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Opacity ${(r.opacity * 100).round()}%'),
        Slider(
          value: r.opacity,
          min: 0.05,
          divisions: 19,
          onChangeStart: (_) => c.checkpoint(),
          onChanged: (o) =>
              c.setReference(r.copyWith(opacity: o), record: false),
        ),
        SegmentedButton<ReferenceFit>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            for (final f in ReferenceFit.values)
              ButtonSegment(value: f, label: Text(f.label)),
          ],
          selected: {r.fit},
          onSelectionChanged: (s) => c.setReference(
            // Custom starts from where the picture is now
            r.copyWith(fit: s.first, rect: r.rectIn(c.page.size)),
          ),
        ),
        const SizedBox(height: 8),
        c.adjustingReference
            ? FilledButton.icon(
                icon: const Icon(AppIcons.check, size: 18),
                label: const Text('Done adjusting'),
                onPressed: () => c.setAdjustingReference(false),
              )
            : FilledButton.tonalIcon(
                icon: const Icon(AppIcons.bezier, size: 18),
                label: const Text('Move & resize on screen'),
                onPressed: r.visible
                    ? () => c.setAdjustingReference(true)
                    : null,
              ),
        if (c.adjustingReference)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Drag the picture to move it; drag a grip to resize. '
              'Corners keep its proportions.',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Show above elements'),
          value: r.onTop,
          onChanged: (on) => c.setReference(r.copyWith(onTop: on)),
        ),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                icon: const Icon(AppIcons.image, size: 18),
                label: const Text('Replace'),
                onPressed: () => _load(context),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                icon: const Icon(AppIcons.trash, size: 18),
                label: const Text('Remove'),
                onPressed: () => c.setReference(null),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
