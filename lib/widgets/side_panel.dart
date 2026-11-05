import 'package:flutter/material.dart';

import '../devices/device_preset.dart';
import '../icons/app_icons.dart';
import '../models/device_frame.dart';
import '../models/ui_element.dart';
import '../screens/new_design_screen.dart';
import '../state/editor_controller.dart';
import 'icon_browser.dart';
import 'properties_panel.dart' show PropField;
import 'shape_picker.dart';

enum SideTab {
  components('Components', AppIcons.components),
  icons('Icons', AppIcons.icons),
  devices('Devices', AppIcons.devices),
  screens('Screens', AppIcons.screens),
  layers('Layers', AppIcons.layers);

  const SideTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// The left navigation rail plus the panel of the selected tab.
class SidePanel extends StatefulWidget {
  const SidePanel({
    super.key,
    required this.controller,
    this.expanded = true,
    this.onToggle,
  });

  final EditorController controller;

  /// false = the panel is collapsed: only the icon rail is visible.
  final bool expanded;

  /// Collapse/expand the panel (null = not collapsible, e.g. in a drawer).
  final VoidCallback? onToggle;

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  SideTab _tab = SideTab.components;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Row(
      // When collapsed, the width is just the rail's
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        NavigationRail(
          labelType: NavigationRailLabelType.all,
          minWidth: 76,
          backgroundColor: Colors.transparent,
          leading: widget.onToggle == null
              ? null
              : IconButton(
                  tooltip: widget.expanded
                      ? 'Collapse panel (Cmd/Ctrl + \\)'
                      : 'Expand panel',
                  icon: const Icon(AppIcons.panelLeft),
                  onPressed: widget.onToggle,
                ),
          onDestinationSelected: (i) {
            setState(() => _tab = SideTab.values[i]);
            // Tapping a tab while collapsed expands the panel
            if (!widget.expanded) widget.onToggle?.call();
          },
          selectedIndex: widget.expanded ? _tab.index : null,
          destinations: [
            for (final t in SideTab.values)
              NavigationRailDestination(
                icon: Icon(t.icon),
                label: Text(t.label),
              ),
          ],
        ),
        if (widget.expanded) ...[
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                  child: Text(
                    _tab.label,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: switch (_tab) {
                    SideTab.components => _ComponentsTab(controller: c),
                    SideTab.icons => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: IconBrowser(
                        draggable: true,
                        onPick: (style, name) => c.addElement(
                          ElementType.iconItem,
                          text: name,
                          iconStyle: style,
                        ),
                      ),
                    ),
                    SideTab.devices => _DevicesTab(controller: c),
                    SideTab.screens => _ScreensTab(controller: c),
                    SideTab.layers => _LayersTab(controller: c),
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ComponentsTab extends StatelessWidget {
  const _ComponentsTab({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(
          'Drag onto the screen, or tap to add it in the center.',
          style: TextStyle(color: scheme.outline, fontSize: 12),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          childAspectRatio: 0.85,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final t in ElementType.values)
              Draggable<NewElement>(
                data: NewElement(t),
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 18, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text(t.label),
                      ],
                    ),
                  ),
                ),
                child: _ComponentTile(
                  type: t,
                  // Box: pick a shape first
                  onTap: t == ElementType.container
                      ? (tile) async {
                          final shape = await showShapeMenu(tile);
                          if (shape != null) {
                            controller.addElement(t, shape: shape);
                          }
                        }
                      : (_) => controller.addElement(t),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Shapes',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final shape in ElementShape.values)
              Draggable<NewElement>(
                data: NewElement(ElementType.container, shape: shape),
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: ShapePreview(shape, size: 48),
                child: Tooltip(
                  message: shape.label,
                  child: Material(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => controller.addElement(
                        ElementType.container,
                        shape: shape,
                      ),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(child: ShapePreview(shape, size: 24)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ComponentTile extends StatelessWidget {
  const _ComponentTile({required this.type, required this.onTap});

  final ElementType type;

  /// Gets the tile's context (for the menu that opens over it).
  final void Function(BuildContext tile) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTap(context),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(type.icon, color: scheme.primary),
              const SizedBox(height: 6),
              Text(
                type.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevicesTab extends StatefulWidget {
  const _DevicesTab({required this.controller});

  final EditorController controller;

  @override
  State<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<_DevicesTab> {
  late DeviceBrand _brand = widget.controller.page.device.brand;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final page = c.page;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final words = _query.toLowerCase().split(' ').where((w) => w.isNotEmpty);
    final brandDevices = devices.where(
      (d) =>
          d.brand == _brand &&
          words.every((w) => d.name.toLowerCase().contains(w)),
    );
    final display = page.device.display;
    final partner = foldPartner(page.device);
    final unit = page.device.preset?.logicalUnit.label ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        // Current device and orientation
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(page.device.icon, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.device.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${page.size.width.round()} × ${page.size.height.round()}'
                      ' $unit${page.resized ? ' · resized' : ''}',
                      style: text.bodySmall,
                    ),
                    if (display != null)
                      Text(
                        '${display.physical.width.round()} × '
                        '${display.physical.height.round()} px physical'
                        '${display.logicalVerified ? '' : ' · dp estimated'}',
                        style: text.bodySmall?.copyWith(color: scheme.outline),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Portrait')),
            ButtonSegment(value: true, label: Text('Landscape')),
          ],
          selected: {page.landscape},
          onSelectionChanged: (s) => c.setLandscape(s.first),
        ),
        if (partner != null) ...[
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(value: false, label: Text('Unfolded')),
              ButtonSegment(
                value: true,
                label: Text(
                  page.device.preset!.displays.any(
                        (d) => d.role == DisplayRole.cover,
                      )
                      ? 'Cover'
                      : 'Folded',
                ),
              ),
            ],
            selected: {display!.role.folded},
            onSelectionChanged: (_) => c.toggleFold(),
          ),
        ],
        if (display?.safeArea != null)
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            dense: true,
            title: const Text('Safe area guides'),
            subtitle: display!.safeAreaVerified
                ? null
                : const Text('Estimated guide'),
            value: page.showSafeArea,
            onChanged: c.setShowSafeArea,
          ),
        ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PropField(
                  key: ValueKey(
                    '${page.id}-${page.device.id}-${page.customSize}-cw',
                  ),
                  label: 'Width',
                  numeric: true,
                  value: page.portraitSize.width.round().toString(),
                  onFocus: c.checkpoint,
                  onChanged: (v) => _setCustom(width: double.tryParse(v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PropField(
                  key: ValueKey(
                    '${page.id}-${page.device.id}-${page.customSize}-ch',
                  ),
                  label: 'Height',
                  numeric: true,
                  value: page.portraitSize.height.round().toString(),
                  onFocus: c.checkpoint,
                  onChanged: (v) => _setCustom(height: double.tryParse(v)),
                ),
              ),
            ],
          ),
          if (page.resized && page.device.id != customDeviceId)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: c.resetSize,
                icon: const Icon(AppIcons.undo, size: 16),
                label: Text(
                  'Reset to ${page.device.size.width.round()}×'
                  '${page.device.size.height.round()}',
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        Text(
          'Tap a device to add a new screen to the canvas. '
          'The ⇄ button changes this screen\'s device.',
          style: text.bodySmall?.copyWith(color: scheme.outline),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search devices…',
            prefixIcon: const Icon(AppIcons.search, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final b in DeviceBrand.values)
              ChoiceChip(
                label: Text(b.label),
                selected: b == _brand,
                showCheckmark: false,
                onSelected: (_) => setState(() => _brand = b),
              ),
          ],
        ),
        for (final kind in DeviceKind.values)
          if (brandDevices.where((d) => d.kind == kind).toList() case final list
              when list.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
              child: Row(
                children: [
                  Icon(kind.icon, size: 16, color: scheme.outline),
                  const SizedBox(width: 6),
                  Text(
                    kind.label.toUpperCase(),
                    style: text.labelSmall?.copyWith(
                      color: scheme.outline,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            for (final d in list)
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                selected: d.id == page.device.id,
                selectedTileColor: scheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                title: Text(d.name),
                subtitle: Text(
                  d.id == customDeviceId
                      ? 'any size'
                      : '${d.size.width.round()}×${d.size.height.round()}',
                  style: text.labelSmall?.copyWith(color: scheme.outline),
                ),
                trailing: IconButton(
                  tooltip: 'Change this screen\'s device',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(AppIcons.swap, size: 18),
                  onPressed: () => c.setDevice(d),
                ),
                // Tapping a device adds a new artboard (it doesn't change the current one)
                onTap: () => c.addPage(d),
              ),
          ],
      ],
    );
  }

  void _setCustom({double? width, double? height}) {
    final c = widget.controller;
    final current = c.page.portraitSize;
    final w = (width ?? current.width).clamp(50.0, 8000.0);
    final h = (height ?? current.height).clamp(50.0, 8000.0);
    if (width == null && height == null) return;
    c.setCustomSize(Size(w, h), record: false);
  }
}

class _ScreensTab extends StatelessWidget {
  const _ScreensTab({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        for (final (i, p) in c.pages.indexed)
          ListTile(
            selected: i == c.pageIndex,
            selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Icon(p.device.icon),
            title: Text(p.name),
            subtitle: Text(
              '${p.device.name} · ${p.size.width.round()}×'
              '${p.size.height.round()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => c.selectPage(i),
            trailing: c.pages.length > 1
                ? IconButton(
                    tooltip: 'Delete screen',
                    icon: const Icon(AppIcons.trash, size: 18),
                    onPressed: () => c.deletePage(i),
                  )
                : null,
          ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () async {
            final build = await showNewDesign(
              context,
              createLabel: 'Add artboard',
            );
            if (build != null) c.addArtboard(build);
          },
          icon: const Icon(AppIcons.add),
          label: const Text('New artboard from device…'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => c.addPage(c.page.device),
          icon: const Icon(AppIcons.copy),
          label: const Text('Add screen'),
        ),
        const SizedBox(height: 6),
        Text(
          '"Add screen" uses the current screen\'s device; change it '
          'in the Devices tab.',
          style: TextStyle(color: scheme.outline, fontSize: 12),
        ),
      ],
    );
  }
}

class _LayersTab extends StatelessWidget {
  const _LayersTab({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final scheme = Theme.of(context).colorScheme;
    if (c.page.elements.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No elements yet.',
          style: TextStyle(color: scheme.outline),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        for (final e in c.page.elements.reversed)
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            selected: e.id == c.selectedId,
            selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            leading: e.type == ElementType.iconItem
                ? SizedBox.square(
                    dimension: 20,
                    child: FittedBox(
                      child: e.iconStyle.build(
                        e.text,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Icon(e.type.icon, size: 20),
            title: Text(
              e.type.hasText || e.type == ElementType.iconItem
                  ? e.text
                  : e.type.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => c.select(e.id),
            // Hidden layers are dimmed
            textColor: e.hidden ? scheme.outline : null,
            iconColor: e.hidden ? scheme.outline : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: e.hidden ? 'Show' : 'Hide',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    e.hidden ? AppIcons.hidden : AppIcons.view,
                    size: 18,
                    color: e.hidden ? scheme.primary : scheme.outline,
                  ),
                  onPressed: () => c.toggleHidden(e.id),
                ),
                IconButton(
                  tooltip: e.locked ? 'Unlock' : 'Lock',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    e.locked ? AppIcons.lock : AppIcons.unlock,
                    size: 18,
                    color: e.locked ? scheme.primary : scheme.outline,
                  ),
                  onPressed: () => c.toggleLock(e.id),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
