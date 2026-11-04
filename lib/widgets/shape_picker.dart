import 'package:flutter/material.dart';

import '../models/ui_element.dart';

/// Picha ndogo ya umbo (kwa vitufe na menyu).
class ShapePreview extends StatelessWidget {
  const ShapePreview(this.shape, {super.key, this.size = 20, this.color});

  final ElementShape shape;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = Size.square(size);
    return SizedBox.fromSize(
      size: s,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: color ?? Theme.of(context).colorScheme.primary,
          shape: shape.border(size * 0.15, s),
        ),
      ),
    );
  }
}

/// Chagua umbo: vitufe vya maumbo yote, kilichochaguliwa kimeangaziwa.
class ShapePicker extends StatelessWidget {
  const ShapePicker({super.key, required this.value, required this.onChanged});

  final ElementShape value;
  final ValueChanged<ElementShape> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in ElementShape.values)
          Tooltip(
            message: s.label,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged(s),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: s == value ? scheme.primaryContainer : null,
                  border: Border.all(
                    color: s == value ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
                child: ShapePreview(
                  s,
                  color: s == value ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Menyu ya maumbo inayotokea juu ya [context] (k.m. kigae cha Box).
Future<ElementShape?> showShapeMenu(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final position = RelativeRect.fromRect(
    box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
    Offset.zero & overlay.size,
  );
  return showMenu<ElementShape>(
    context: context,
    position: position,
    items: [
      for (final s in ElementShape.values)
        PopupMenuItem(
          value: s,
          child: Row(
            children: [
              ShapePreview(s),
              const SizedBox(width: 12),
              Text(s.label),
            ],
          ),
        ),
    ],
  );
}
