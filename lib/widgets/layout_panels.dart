import 'package:flutter/material.dart';

import '../canvas/alignment.dart';
import '../canvas/layout.dart';
import '../icons/app_icons.dart';
import '../models/ui_element.dart';
import '../state/editor_controller.dart';
import 'properties_panel.dart' show PropField;

/// A small section heading (e.g. "Alignment").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _ToolButton extends StatelessWidget {
  const _ToolButton(this.icon, this.tooltip, this.onPressed, {this.child});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
    icon: child ?? Icon(icon, size: 20),
  );
}

/// Distribute icon: three equal bars (vertical or horizontal).
class _DistIcon extends StatelessWidget {
  const _DistIcon({required this.vertical, required this.at});

  final bool vertical;

  /// -1 = start edges, 0 = centers, 1 = end edges
  final double at;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.black;
    return SizedBox.square(
      dimension: 20,
      child: CustomPaint(painter: _DistPainter(vertical, at, color)),
    );
  }
}

class _DistPainter extends CustomPainter {
  _DistPainter(this.vertical, this.at, this.color);
  final bool vertical;
  final double at;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    for (var i = 0; i < 3; i++) {
      final c = 3 + i * 7.0;
      final r = vertical
          ? Rect.fromCenter(center: Offset(10, c), width: 12, height: 4)
          : Rect.fromCenter(center: Offset(c, 10), width: 4, height: 12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(1)),
        box,
      );
      final edge = vertical
          ? r.center.dy + at * r.height / 2
          : r.center.dx + at * r.width / 2;
      if (vertical) {
        canvas.drawLine(Offset(0, edge), Offset(3, edge), line);
      } else {
        canvas.drawLine(Offset(edge, 17), Offset(edge, 20), line);
      }
    }
  }

  @override
  bool shouldRepaint(_DistPainter old) =>
      old.vertical != vertical || old.at != at || old.color != color;
}

/// Alignment, distribution and spacing for the selected elements.
class AlignmentSection extends StatelessWidget {
  const AlignmentSection({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final v = c.view;
    final can = c.canAlign;
    final dist = c.canDistribute;
    final space = c.canSpace;
    final single = c.selectedIds.length == 1;

    VoidCallback? a(AlignOp op) => can ? () => c.align(op) : null;
    VoidCallback? d(DistributeOp op) => dist ? () => c.distribute(op) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Alignment',
          trailing: Text(
            single ||
                    v.alignTo == AlignTo.artboard ||
                    v.alignTo == AlignTo.parent
                ? 'to artboard'
                : v.alignTo == AlignTo.keyObject
                ? 'to key object'
                : 'to selection',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        Wrap(
          children: [
            _ToolButton(
              AppIcons.alignLeft,
              'Align left (Alt+A)',
              a(AlignOp.left),
            ),
            _ToolButton(
              AppIcons.alignHCenter,
              'Align horizontal centers (Alt+H)',
              a(AlignOp.hCenter),
            ),
            _ToolButton(
              AppIcons.alignRight,
              'Align right (Alt+D)',
              a(AlignOp.right),
            ),
            _ToolButton(AppIcons.alignTop, 'Align top (Alt+W)', a(AlignOp.top)),
            _ToolButton(
              AppIcons.alignVCenter,
              'Align vertical centers (Alt+V)',
              a(AlignOp.vCenter),
            ),
            _ToolButton(
              AppIcons.alignBottom,
              'Align bottom (Alt+S)',
              a(AlignOp.bottom),
            ),
            _ToolButton(
              AppIcons.alignCenter,
              'Center both ways (Alt+C)',
              a(AlignOp.centerBoth),
            ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<AlignTo>(
          key: ValueKey('alignTo-${v.alignTo}'),
          initialValue: v.alignTo,
          isDense: true,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Align to',
            isDense: true,
          ),
          items: [
            for (final t in AlignTo.values)
              DropdownMenuItem(
                value: t,
                child: Text(t.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (t) => c.setView(v.copyWith(alignTo: t)),
        ),
        if (v.alignTo == AlignTo.keyObject)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              c.selectedIds.length > 1
                  ? 'The key object has a thick border; tap another '
                        'selected element to change it. It stays put.'
                  : 'Select 2+ elements (Shift + tap).',
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        const SectionLabel('Distribution (3+ elements)'),
        Wrap(
          children: [
            _ToolButton(
              AppIcons.distributeH,
              'Distribute left edges',
              d(DistributeOp.left),
              child: const _DistIcon(vertical: false, at: -1),
            ),
            _ToolButton(
              AppIcons.distributeH,
              'Distribute horizontal centers',
              d(DistributeOp.hCenter),
              child: const _DistIcon(vertical: false, at: 0),
            ),
            _ToolButton(
              AppIcons.distributeH,
              'Distribute right edges',
              d(DistributeOp.right),
              child: const _DistIcon(vertical: false, at: 1),
            ),
            _ToolButton(
              AppIcons.distributeV,
              'Distribute top edges',
              d(DistributeOp.top),
              child: const _DistIcon(vertical: true, at: -1),
            ),
            _ToolButton(
              AppIcons.distributeV,
              'Distribute vertical centers',
              d(DistributeOp.vCenter),
              child: const _DistIcon(vertical: true, at: 0),
            ),
            _ToolButton(
              AppIcons.distributeV,
              'Distribute bottom edges',
              d(DistributeOp.bottom),
              child: const _DistIcon(vertical: true, at: 1),
            ),
            _ToolButton(
              AppIcons.spaceH,
              'Equal horizontal spacing',
              dist ? () => c.distributeSpacingOn(Axis.horizontal) : null,
            ),
            _ToolButton(
              AppIcons.spaceV,
              'Equal vertical spacing',
              dist ? () => c.distributeSpacingOn(Axis.vertical) : null,
            ),
          ],
        ),
        const SectionLabel('Spacing'),
        _GapRow(
          label: 'Horizontal',
          value: v.hGap,
          enabled: space,
          onChanged: (g) => c.setView(v.copyWith(hGap: g)),
          onApply: () => c.applyGapOn(Axis.horizontal),
        ),
        const SizedBox(height: 8),
        _GapRow(
          label: 'Vertical',
          value: v.vGap,
          enabled: space,
          onChanged: (g) => c.setView(v.copyWith(vGap: g)),
          onApply: () => c.applyGapOn(Axis.vertical),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: space ? c.tidySelection : null,
                icon: const Icon(AppIcons.tidy, size: 18),
                label: const Text('Tidy up'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: space ? c.smartArrangeSelection : null,
                child: const Text('Smart arrange'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onApply,
  });

  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final VoidCallback onApply;

  static const presets = [0.0, 4.0, 8.0, 12.0, 16.0, 24.0, 32.0];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 48, child: Text(label)),
        Expanded(
          child: _NumberBox(
            key: ValueKey('gap-$label'),
            value: value,
            onChanged: onChanged,
            suffix: 'px',
          ),
        ),
        PopupMenuButton<double>(
          tooltip: 'Common spacings',
          icon: const Icon(AppIcons.more, size: 18),
          onSelected: onChanged,
          itemBuilder: (_) => [
            for (final p in presets)
              PopupMenuItem(value: p, child: Text('${p.toInt()} px')),
          ],
        ),
        FilledButton.tonal(
          onPressed: enabled ? onApply : null,
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/// A small number field (uses [PropField]: it keeps focus and never
/// deletes the element while typing).
class _NumberBox extends StatelessWidget {
  const _NumberBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.suffix,
    this.label,
    this.onFocus,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String? suffix;
  final String? label;
  final VoidCallback? onFocus;

  @override
  Widget build(BuildContext context) {
    final text = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    return PropField(
      label: [?label, ?suffix].join(' · '),
      value: text,
      numeric: true,
      onFocus: onFocus,
      onChanged: (s) {
        if (double.tryParse(s) case final n? when n >= 0) onChanged(n);
      },
    );
  }
}

/// Text alignment INSIDE the element (not moving the element).
class TextAlignSection extends StatelessWidget {
  const TextAlignSection({
    super.key,
    required this.controller,
    required this.element,
  });

  final EditorController controller;
  final UiElement element;

  @override
  Widget build(BuildContext context) {
    final e = element;
    final align = e.effectiveTextAlign;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Text alignment (inside the box)'),
        SegmentedButton<TextAlign>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(
              value: TextAlign.left,
              icon: Icon(AppIcons.textLeft, size: 18),
              tooltip: 'Left',
            ),
            ButtonSegment(
              value: TextAlign.center,
              icon: Icon(AppIcons.textCenter, size: 18),
              tooltip: 'Center',
            ),
            ButtonSegment(
              value: TextAlign.right,
              icon: Icon(AppIcons.textRight, size: 18),
              tooltip: 'Right',
            ),
            ButtonSegment(
              value: TextAlign.justify,
              icon: Icon(AppIcons.textJustify, size: 18),
              tooltip: 'Justify',
            ),
          ],
          selected: {align},
          onSelectionChanged: (s) =>
              controller.updateElement(e.copyWith(textAlign: s.first)),
        ),
        const SizedBox(height: 8),
        SegmentedButton<VAlign>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: VAlign.top, label: Text('Top')),
            ButtonSegment(value: VAlign.middle, label: Text('Middle')),
            ButtonSegment(value: VAlign.bottom, label: Text('Bottom')),
          ],
          selected: {e.vAlign},
          onSelectionChanged: (s) =>
              controller.updateElement(e.copyWith(vAlign: s.first)),
        ),
      ],
    );
  }
}

/// Prototype: tapping the element in "Run" opens another screen.
class LinkSection extends StatelessWidget {
  const LinkSection({
    super.key,
    required this.controller,
    required this.element,
  });

  final EditorController controller;
  final UiElement element;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final targets = [
      for (final p in c.pages)
        if (p.id != c.page.id) p,
    ];
    final current = targets.any((p) => p.id == element.link)
        ? element.link
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Prototype (Run)'),
        DropdownButtonFormField<String?>(
          key: ValueKey('link-${element.id}-$current'),
          initialValue: current,
          isDense: true,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'On tap, go to',
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(child: Text('— none —')),
            for (final p in targets)
              DropdownMenuItem(value: p.id, child: Text(p.name)),
          ],
          onChanged: (id) => c.updateElement(
            id == null
                ? element.copyWith(clearLink: true)
                : element.copyWith(link: id),
          ),
        ),
      ],
    );
  }
}

/// Artboard grids: squares, columns and rows.
class GridSection extends StatelessWidget {
  const GridSection({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final g = c.page.grid;
    final v = c.view;
    void set(GridSettings next) => c.setGrid(next);

    Widget track(String title, TrackGrid t, ValueChanged<TrackGrid> onToggle) {
      void onChanged(TrackGrid next) =>
          t.enabled == next.enabled && t.stretch == next.stretch
          ? c.setGrid(
              title.startsWith('Columns')
                  ? g.copyWith(columns: next)
                  : g.copyWith(rows: next),
              record: false,
            )
          : onToggle(next);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(title),
            value: t.enabled,
            onChanged: (on) => onChanged(t.copyWith(enabled: on)),
          ),
          if (t.enabled) ...[
            Row(
              children: [
                Expanded(
                  child: _NumberBox(
                    key: ValueKey('$title-count'),
                    onFocus: c.checkpoint,
                    label: 'Count',
                    value: t.count.toDouble(),
                    onChanged: (n) =>
                        onChanged(t.copyWith(count: n.round().clamp(1, 48))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumberBox(
                    key: ValueKey('$title-gutter'),
                    onFocus: c.checkpoint,
                    label: 'Gutter',
                    value: t.gutter,
                    onChanged: (n) => onChanged(t.copyWith(gutter: n)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumberBox(
                    key: ValueKey('$title-margin'),
                    onFocus: c.checkpoint,
                    label: 'Margin',
                    value: t.margin,
                    onChanged: (n) => onChanged(t.copyWith(margin: n)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(value: true, label: Text('Stretch')),
                      ButtonSegment(value: false, label: Text('Center')),
                    ],
                    selected: {t.stretch},
                    onSelectionChanged: (s) => onChanged(
                      s.first
                          ? t.copyWith(clearSize: true)
                          : t.copyWith(size: t.size ?? 64),
                    ),
                  ),
                ),
                if (!t.stretch) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 76,
                    child: _NumberBox(
                      key: ValueKey('$title-size'),
                      onFocus: c.checkpoint,
                      label: 'Width',
                      value: t.size!,
                      onChanged: (n) => onChanged(t.copyWith(size: n)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Grid',
          trailing: Tooltip(
            message: 'Snap to grid',
            child: FilterChip(
              label: const Text('Snap'),
              visualDensity: VisualDensity.compact,
              selected: v.snapGrid,
              onSelected: (on) => c.setView(v.copyWith(snapGrid: on)),
            ),
          ),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Square grid'),
          value: g.show,
          onChanged: (on) => set(g.copyWith(show: on)),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in GridSettings.sizes)
              ChoiceChip(
                label: Text('${s.toInt()}'),
                visualDensity: VisualDensity.compact,
                selected: g.size == s,
                showCheckmark: false,
                onSelected: (_) => set(g.copyWith(size: s)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final col in const [
              Color(0xFFF04438),
              Color(0xFF7A5AF8),
              Color(0xFF06AED4),
              Color(0xFF101828),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => set(g.copyWith(color: col)),
                  child: CircleAvatar(
                    radius: g.color == col ? 12 : 10,
                    backgroundColor: col,
                  ),
                ),
              ),
            Expanded(
              child: Slider(
                value: g.opacity.clamp(0.02, 0.6),
                min: 0.02,
                max: 0.6,
                label: 'Opacity ${(g.opacity * 100).round()}%',
                onChangeStart: (_) => c.checkpoint(),
                onChanged: (o) =>
                    c.setGrid(g.copyWith(opacity: o), record: false),
              ),
            ),
          ],
        ),
        track('Columns', g.columns, (t) => set(g.copyWith(columns: t))),
        track('Rows', g.rows, (t) => set(g.copyWith(rows: t))),
      ],
    );
  }
}

/// The artboard's guides and their exact positions.
class GuidesSection extends StatelessWidget {
  const GuidesSection({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final page = c.page;
    final o = page.rulerOrigin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Guides (${page.guides.length})',
          trailing: page.guides.isEmpty
              ? null
              : TextButton(
                  onPressed: c.clearGuides,
                  child: const Text('Delete all'),
                ),
        ),
        if (page.guides.isEmpty)
          Text(
            'Drag from the top ruler (horizontal) or the left ruler (vertical).',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        for (final g in page.guides)
          Row(
            children: [
              SizedBox(width: 24, child: Text(g.vertical ? 'X' : 'Y')),
              Expanded(
                child: _NumberBox(
                  key: ValueKey('guide-${g.id}'),
                  onFocus: c.checkpoint,
                  value: g.position - (g.vertical ? o.dx : o.dy),
                  suffix: 'px',
                  onChanged: (n) => c.moveGuide(
                    g.id,
                    n + (g.vertical ? o.dx : o.dy),
                    record: false,
                  ),
                ),
              ),
              IconButton(
                tooltip: g.locked ? 'Unlock' : 'Lock',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  g.locked ? AppIcons.lock : AppIcons.unlock,
                  size: 18,
                ),
                onPressed: () => c.toggleGuideLock(g.id),
              ),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                icon: const Icon(AppIcons.trash, size: 18),
                onPressed: () => c.deleteGuide(g.id),
              ),
            ],
          ),
      ],
    );
  }
}
