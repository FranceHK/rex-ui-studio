import 'package:flutter/material.dart';

import '../canvas/layout.dart';
import '../icons/app_icons.dart';
import '../state/editor_controller.dart';
import 'layout_panels.dart';

/// Fungua dirisha la "Mipangilio": kalamu na vidole, mwonekano (rulers,
/// guides, gridi), snapping na njia za mkato za kibodi. Mabadiliko
/// yanaonekana papo hapo na yanahifadhiwa pamoja na mradi.
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
                      'Mipangilio',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Funga',
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
                  const _Header('Kalamu na vidole'),
                  toggle(
                    'Kalamu tu (zuia kiganja)',
                    v.penMode,
                    (on) => set(v.copyWith(penOnly: on)),
                    icon: AppIcons.pen,
                    subtitle:
                        'Kalamu inahariri; kidole kimoja hakigusi vitu. '
                        'Vidole viwili: zoom na kusogeza canvas.',
                  ),
                  toggle(
                    'Funga mwonekano',
                    v.lockView,
                    (on) => set(v.copyWith(lockView: on)),
                    icon: AppIcons.lock,
                    subtitle:
                        'Canvas haisogei wala kuzoom ukiwa unahariri sehemu '
                        'fulani (vitufe vya zoom bado vinafanya kazi).',
                  ),
                  const _Header('Mwonekano'),
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
                    'Funga guides',
                    v.guidesLocked,
                    (on) => set(v.copyWith(guidesLocked: on)),
                  ),
                  ListTile(
                    title: const Text('Rangi ya guides'),
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
                          child: const Text('Futa guides zote'),
                        ),
                        OutlinedButton(
                          onPressed: c.page.rulerOrigin == Offset.zero
                              ? null
                              : c.resetRulerOrigin,
                          child: const Text('Rudisha origin ya rulers'),
                        ),
                      ],
                    ),
                  ),
                  const _Header('Gridi (skrini hii)'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridSection(controller: c),
                  ),
                  const _Header('Snapping'),
                  toggle('Snapping', v.snap, (on) => set(v.copyWith(snap: on))),
                  if (v.snap) ...[
                    toggle(
                      'Snap kwenye gridi',
                      v.snapGrid,
                      (on) => set(v.copyWith(snapGrid: on)),
                    ),
                    toggle(
                      'Snap kwenye guides',
                      v.snapGuides,
                      (on) => set(v.copyWith(snapGuides: on)),
                    ),
                    toggle(
                      'Snap kwenye vipengele',
                      v.snapObjects,
                      (on) => set(v.copyWith(snapObjects: on)),
                    ),
                    toggle(
                      'Snap kwenye kingo za skrini',
                      v.snapArtboard,
                      (on) => set(v.copyWith(snapArtboard: on)),
                    ),
                  ],
                  toggle(
                    'Smart guides (mistari ya kupanga)',
                    v.smartGuides,
                    (on) => set(v.copyWith(smartGuides: on)),
                  ),
                  toggle(
                    'Vipimo vya umbali',
                    v.showDistances,
                    (on) => set(v.copyWith(showDistances: on)),
                  ),
                  const ExpansionTile(
                    title: Text('Njia za mkato (kibodi)'),
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
    '• Delete — futa · Cmd/Ctrl + A — chagua vyote\n'
    '• Shift + bonyeza / buruta kwenye skrini — chagua vingi\n'
    '• Cmd/Ctrl + D — nakili · Cmd/Ctrl + Z — rudisha\n'
    '• Mishale — sogeza (Shift = 10)\n'
    '• Alt + A/H/D — panga kushoto/katikati/kulia\n'
    '• Alt + W/V/S — panga juu/katikati/chini\n'
    '• Shift + R — rulers · Cmd/Ctrl + ; — guides\n'
    "• Cmd/Ctrl + ' — gridi · Ctrl wakati wa kuburuta — bila snap\n"
    '• Alt — ona umbali · scroll — sogeza · Cmd + scroll — zoom\n'
    '• Buruta jina la skrini — hamisha artboard';

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
