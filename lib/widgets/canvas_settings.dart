import 'package:flutter/material.dart';

import '../canvas/layout.dart';
import '../icons/app_icons.dart';
import '../state/editor_controller.dart';
import 'layout_panels.dart';

/// Opens the "Settings" dialog: pen and fingers, view (rulers, guides,
/// grid), snapping and keyboard shortcuts. Changes show up right away and
/// are saved with the project.
Future<void> showCanvasSettings(
  BuildContext context,
  EditorController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: CanvasSettings(controller: controller),
      ),
    ),
  );
}

class CanvasSettings extends StatelessWidget {
  const CanvasSettings({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final v = c.view;
        void set(ViewSettings next) => c.setView(next);

        Widget toggle(
          String title,
          bool value,
          ValueChanged<bool> onChanged, {
          String? subtitle,
          IconData? icon,
        }) => SwitchListTile(
          secondary: icon == null ? null : Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          value: value,
          onChanged: onChanged,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(
                children: [
                  Icon(AppIcons.settings, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  const _Header('Pen and fingers'),
                  toggle(
                    'Pen only (palm rejection)',
                    v.penMode,
                    (on) => set(v.copyWith(penOnly: on)),
                    icon: AppIcons.pen,
                    subtitle:
                        'The pen edits; a single finger doesn\'t touch elements. '
                        'Two fingers: zoom and pan the canvas.',
                  ),
                  toggle(
                    'Lock view',
                    v.lockView,
                    (on) => set(v.copyWith(lockView: on)),
                    icon: AppIcons.lock,
                    subtitle:
                        'The canvas doesn\'t pan or zoom while you edit a '
                        'detail (the zoom buttons still work).',
                  ),
                  const _Header('View'),
                  toggle(
                    'Rulers',
                    v.showRulers,
                    (on) => set(v.copyWith(showRulers: on)),
                    icon: AppIcons.ruler,
                  ),
                  toggle(
                    'Guides',
                    v.showGuides,
                    (on) => set(v.copyWith(showGuides: on)),
                  ),
                  toggle(
                    'Lock guides',
                    v.guidesLocked,
                    (on) => set(v.copyWith(guidesLocked: on)),
                  ),
                  ListTile(
                    title: const Text('Guide color'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        for (final col in ViewSettings.guideColors)
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => set(v.copyWith(guideColor: col)),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: col,
                              child: col == v.guideColor
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: c.page.guides.isEmpty
                              ? null
                              : c.clearGuides,
                          child: const Text('Clear all guides'),
                        ),
                        OutlinedButton(
                          onPressed: c.page.rulerOrigin == Offset.zero
                              ? null
                              : c.resetRulerOrigin,
                          child: const Text('Reset ruler origin'),
                        ),
                      ],
                    ),
                  ),
                  const _Header('Grid (this screen)'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridSection(controller: c),
                  ),
                  const _Header('Snapping'),
                  toggle('Snapping', v.snap, (on) => set(v.copyWith(snap: on))),
                  if (v.snap) ...[
                    toggle(
                      'Snap to grid',
                      v.snapGrid,
                      (on) => set(v.copyWith(snapGrid: on)),
                    ),
                    toggle(
                      'Snap to guides',
                      v.snapGuides,
                      (on) => set(v.copyWith(snapGuides: on)),
                    ),
                    toggle(
                      'Snap to elements',
                      v.snapObjects,
                      (on) => set(v.copyWith(snapObjects: on)),
                    ),
                    toggle(
                      'Snap to screen edges',
                      v.snapArtboard,
                      (on) => set(v.copyWith(snapArtboard: on)),
                    ),
                  ],
                  toggle(
                    'Smart guides',
                    v.smartGuides,
                    (on) => set(v.copyWith(smartGuides: on)),
                  ),
                  toggle(
                    'Distance measurements',
                    v.showDistances,
                    (on) => set(v.copyWith(showDistances: on)),
                  ),
                  const ExpansionTile(
                    title: Text('Keyboard shortcuts'),
                    childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(_shortcuts)],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

const _shortcuts =
    '• Delete — delete · Cmd/Ctrl + A — select all\n'
    '• Shift + tap / drag on the screen — multi-select\n'
    '• Cmd/Ctrl + D — duplicate · Cmd/Ctrl + Z — undo\n'
    '• Arrows — move (Shift = 10)\n'
    '• Alt + A/H/D — align left/center/right\n'
    '• Alt + W/V/S — align top/middle/bottom\n'
    '• Shift + R — rulers · Cmd/Ctrl + ; — guides\n'
    "• Cmd/Ctrl + ' — grid · Ctrl while dragging — no snap\n"
    '• Alt — show distances · scroll — pan · Cmd + scroll — zoom\n'
    '• Drag a screen name — move the artboard';

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
