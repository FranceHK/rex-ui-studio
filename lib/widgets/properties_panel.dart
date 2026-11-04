import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../icons/icon_style.dart';
import '../models/ui_element.dart';
import '../state/editor_controller.dart';
import 'icon_browser.dart';
import 'layout_panels.dart';
import 'reference_section.dart';
import 'shape_picker.dart';

const swatches = [
  brandColor,
  Color(0xFF0EA5E9),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  inkColor,
  mutedColor,
  Color(0xFFD0D5DD),
  Color(0xFFF2F4F7),
  Colors.white,
  Colors.transparent,
];

/// The right panel: properties of the selected element or the screen.
class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final el = controller.selected;
    final many = controller.selectedIds.length > 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: many
          ? _multiProps(context)
          : el == null
          ? _pageProps(context)
          : _elementProps(context, el),
    );
  }

  /// Several elements are selected (Shift + tap or marquee).
  List<Widget> _multiProps(BuildContext context) {
    final c = controller;
    final els = c.selectedElements;
    final allLocked = els.every((e) => e.locked);
    return [
      Row(
        children: [
          Expanded(child: _Heading('${els.length} elements')),
          IconButton(
            tooltip: allLocked ? 'Unlock all' : 'Lock all',
            icon: Icon(allLocked ? AppIcons.lock : AppIcons.unlock, size: 18),
            onPressed: () {
              c.checkpoint();
              for (final e in els) {
                c.updateElement(e.copyWith(locked: !allLocked), record: false);
              }
            },
          ),
          IconButton(
            tooltip: 'Duplicate all (Cmd+D)',
            icon: const Icon(AppIcons.copy, size: 18),
            onPressed: c.duplicateSelected,
          ),
          IconButton(
            tooltip: 'Delete all',
            icon: const Icon(AppIcons.trash, size: 18),
            onPressed: c.deleteSelected,
          ),
        ],
      ),
      Text(
        'Shift + tap to add/remove · Alt to see distances',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      AlignmentSection(controller: c),
    ];
  }

  List<Widget> _pageProps(BuildContext context) {
    final c = controller;
    final page = c.page;
    return [
      const _Heading('Screen'),
      PropField(
        key: ValueKey('${page.id}-name'),
        label: 'Name',
        value: page.name,
        onFocus: c.checkpoint,
        onChanged: (v) => c.updatePage(page.copyWith(name: v), record: false),
      ),
      const SizedBox(height: 16),
      const _Label('Device'),
      Row(
        children: [
          Icon(page.device.icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${page.device.name} · ${page.size.width.round()}×'
              '${page.size.height.round()}'
              '${page.landscape ? ' (landscape)' : ''}',
            ),
          ),
        ],
      ),
      if (page.device.display case final d?)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${d.diagonal == null ? '' : '${d.diagonal}" · '}'
            '${d.physical.width.round()}×${d.physical.height.round()} px physical'
            '${d.scale == null ? '' : ' · scale ${d.scale}'}'
            '${d.logicalVerified ? '' : ' · dp estimated'}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      const SizedBox(height: 4),
      Text(
        'Change the device in the "Devices" tab on the left.',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      const SizedBox(height: 16),
      const _Label('Background color'),
      ColorSwatches(
        value: page.background,
        onChanged: (col) => c.updatePage(page.copyWith(background: col)),
      ),
      ReferenceSection(controller: c),
      GridSection(controller: c),
      GuidesSection(controller: c),
      const SizedBox(height: 24),
      Text(
        'Select an element on the screen to edit its properties.',
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      ),
    ];
  }

  List<Widget> _elementProps(BuildContext context, UiElement e) {
    final c = controller;
    void update(UiElement next, {bool record = true}) =>
        c.updateElement(next, record: record);
    Widget num(String label, double value, Rect Function(double) apply) {
      return Expanded(
        child: PropField(
          key: ValueKey('${e.id}-$label'),
          label: label,
          value: value.round().toString(),
          numeric: true,
          enabled: !e.locked,
          onFocus: c.checkpoint,
          onChanged: (v) {
            final n = double.tryParse(v);
            if (n != null) update(e.copyWith(rect: apply(n)), record: false);
          },
        ),
      );
    }

    final r = e.rect;
    return [
      Row(
        children: [
          Icon(e.type.icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: _Heading(e.type.label)),
          IconButton(
            tooltip: e.locked ? 'Unlock' : 'Lock',
            isSelected: e.locked,
            icon: Icon(e.locked ? AppIcons.lock : AppIcons.unlock, size: 18),
            onPressed: () => c.toggleLock(e.id),
          ),
          IconButton(
            tooltip: 'Duplicate',
            icon: const Icon(AppIcons.copy, size: 18),
            onPressed: c.duplicateSelected,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(AppIcons.trash, size: 18),
            onPressed: c.deleteSelected,
          ),
        ],
      ),
      Wrap(
        children: [
          TextButton.icon(
            onPressed: c.bringToFront,
            icon: const Icon(AppIcons.front, size: 18),
            label: const Text('Bring forward'),
          ),
          TextButton.icon(
            onPressed: c.sendToBack,
            icon: const Icon(AppIcons.backward, size: 18),
            label: const Text('Send backward'),
          ),
        ],
      ),
      AlignmentSection(controller: c),
      if (e.locked)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(AppIcons.lock, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Locked: it can\'t be moved or resized.')),
            ],
          ),
        ),
      const SizedBox(height: 8),
      const _Label('Layout'),
      Row(
        children: [
          num('X', r.left, (v) => Rect.fromLTWH(v, r.top, r.width, r.height)),
          const SizedBox(width: 8),
          num('Y', r.top, (v) => Rect.fromLTWH(r.left, v, r.width, r.height)),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          num(
            'Width',
            r.width,
            (v) => Rect.fromLTWH(r.left, r.top, v.clamp(4, 5000), r.height),
          ),
          const SizedBox(width: 8),
          num(
            'Height',
            r.height,
            (v) => Rect.fromLTWH(r.left, r.top, r.width, v.clamp(1, 5000)),
          ),
        ],
      ),
      if (e.type.hasText) ...[
        const SizedBox(height: 16),
        PropField(
          key: ValueKey('${e.id}-text'),
          label: 'Text',
          value: e.text,
          onFocus: c.checkpoint,
          onChanged: (v) => update(e.copyWith(text: v), record: false),
        ),
        if (e.type != ElementType.avatar)
          TextAlignSection(controller: c, element: e),
      ],
      if (e.type == ElementType.iconItem) ...[
        const SizedBox(height: 16),
        const _Label('Icon'),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FittedBox(
                child: e.iconStyle.build(e.text, size: 28, color: e.color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.text,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(e.iconStyle.label),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<IconStyle>(
          key: ValueKey('${e.id}-${e.iconStyle.name}'),
          initialValue: e.iconStyle,
          isDense: true,
          decoration: const InputDecoration(labelText: 'Style', isDense: true),
          items: [
            for (final s in IconStyle.values)
              DropdownMenuItem(value: s, child: Text(s.label)),
          ],
          onChanged: (s) => update(e.copyWith(iconStyle: s)),
        ),
        if (!e.iconStyle.has(e.text))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Icon "${e.text}" isn\'t in the ${e.iconStyle.label} style; '
              'pick another.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pickIcon(context, e),
          icon: const Icon(AppIcons.search, size: 18),
          label: const Text('Change icon'),
        ),
      ],
      if (e.type != ElementType.text &&
          !(e.type == ElementType.iconItem && !e.iconStyle.colorable)) ...[
        const SizedBox(height: 16),
        _Label(e.type == ElementType.input ? 'Border color' : 'Color'),
        ColorSwatches(
          value: e.color,
          onChanged: (col) => update(e.copyWith(color: col)),
        ),
      ],
      if (e.type.hasText ||
          e.type == ElementType.navBar ||
          e.type == ElementType.image) ...[
        const SizedBox(height: 16),
        _Label(e.type.hasText ? 'Text color' : 'Icon color'),
        ColorSwatches(
          value: e.textColor,
          onChanged: (col) => update(e.copyWith(textColor: col)),
        ),
      ],
      if (e.type.hasText) ...[
        const SizedBox(height: 16),
        _Label('Font size: ${e.fontSize.round()}'),
        Slider(
          value: e.fontSize.clamp(8, 72),
          min: 8,
          max: 72,
          onChangeStart: (_) => c.checkpoint(),
          onChanged: (v) =>
              update(e.copyWith(fontSize: v.roundToDouble()), record: false),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bold'),
          value: e.bold,
          onChanged: (v) => update(e.copyWith(bold: v)),
        ),
      ],
      if (e.type.hasShape) ...[
        const SizedBox(height: 12),
        const _Label('Shape'),
        const SizedBox(height: 6),
        ShapePicker(
          value: e.shape,
          onChanged: (shape) => update(e.copyWith(shape: shape)),
        ),
      ],
      if (e.type.hasRadius) ...[
        const SizedBox(height: 8),
        _Label('Corner radius: ${e.radius.round()}'),
        Slider(
          value: e.radius.clamp(0, 60),
          max: 60,
          onChangeStart: (_) => c.checkpoint(),
          onChanged: (v) =>
              update(e.copyWith(radius: v.roundToDouble()), record: false),
        ),
      ],
      if (c.pages.length > 1) LinkSection(controller: c, element: e),
    ];
  }

  Future<void> _pickIcon(BuildContext context, UiElement e) async {
    final picked = await showDialog<(IconStyle, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose icon'),
        content: SizedBox(
          width: 560,
          height: 480,
          child: IconBrowser(
            initialStyle: e.iconStyle,
            selected: e.text,
            onPick: (style, name) => Navigator.pop(context, (style, name)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (picked case (final style, final name)) {
      final current = controller.selected;
      if (current == null) return;
      controller.updateElement(current.copyWith(iconStyle: style, text: name));
    }
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

class ColorSwatches extends StatelessWidget {
  const ColorSwatches({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Color value;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final col in swatches)
          Tooltip(
            message: col == Colors.transparent ? 'No color' : hexOf(col),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onChanged(col),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: col,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: col == value
                        ? scheme.primary
                        : scheme.outlineVariant,
                    width: col == value ? 3 : 1,
                  ),
                ),
                child: col == Colors.transparent
                    ? Icon(Icons.block, size: 16, color: scheme.outline)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

String hexOf(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// A text field that follows the outside value except while the user
/// is typing in it.
class PropField extends StatefulWidget {
  const PropField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onFocus,
    this.numeric = false,
    this.enabled = true,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFocus;
  final bool numeric;
  final bool enabled;

  @override
  State<PropField> createState() => _PropFieldState();
}

class _PropFieldState extends State<PropField> {
  late final _ctrl = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) widget.onFocus?.call();
    });
  }

  @override
  void didUpdateWidget(PropField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      enabled: widget.enabled,
      keyboardType: widget.numeric ? TextInputType.number : null,
      decoration: InputDecoration(labelText: widget.label, isDense: true),
      onChanged: widget.onChanged,
    );
  }
}
