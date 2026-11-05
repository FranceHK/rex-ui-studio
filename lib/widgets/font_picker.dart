import 'package:flutter/material.dart';

import '../fonts/app_fonts.dart';
import '../icons/app_icons.dart';

const _systemFont = 'System font';

/// Shows the current font family in its own font; tapping opens a list of
/// every family, each previewed in itself.
class FontFamilyField extends StatelessWidget {
  const FontFamilyField({
    super.key,
    required this.value,
    required this.weight,
    required this.onChanged,
  });

  final String? value;
  final int weight;
  final ValueChanged<String?> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<(String?,)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FontSheet(value: value, weight: weight),
    );
    if (picked != null && picked.$1 != value) onChanged(picked.$1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      key: const ValueKey('font-family'),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      onPressed: () => _open(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value ?? _systemFont,
              overflow: TextOverflow.ellipsis,
              style: styleWithFont(
                value,
                TextStyle(
                  fontSize: 16,
                  color: scheme.onSurface,
                  fontWeight: fontWeightOf(weight),
                ),
              ),
            ),
          ),
          Icon(AppIcons.backward, size: 16, color: scheme.outline),
        ],
      ),
    );
  }
}

class _FontSheet extends StatefulWidget {
  const _FontSheet({required this.value, required this.weight});

  final String? value;
  final int weight;

  @override
  State<_FontSheet> createState() => _FontSheetState();
}

class _FontSheetState extends State<_FontSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _query.toLowerCase();
    final families = <String?>[
      if (_systemFont.toLowerCase().contains(q)) null,
      for (final f in fontFamilies)
        if (f.toLowerCase().contains(q)) f,
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(AppIcons.search, size: 18),
                hintText: 'Search fonts',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final f in families)
                  ListTile(
                    key: ValueKey('font-${f ?? 'system'}'),
                    selected: f == widget.value,
                    title: Text(
                      f ?? _systemFont,
                      style: styleWithFont(
                        f,
                        TextStyle(
                          fontSize: 20,
                          color: scheme.onSurface,
                          fontWeight: fontWeightOf(widget.weight),
                        ),
                      ),
                    ),
                    subtitle: Text(
                      'The quick brown fox jumps over the lazy dog',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: styleWithFont(
                        f,
                        TextStyle(fontSize: 13, color: scheme.outline),
                      ),
                    ),
                    trailing: f == widget.value
                        ? const Icon(AppIcons.check, size: 18)
                        : null,
                    onTap: () => Navigator.pop(context, (f,)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks one of the nine weights, each item drawn at its own weight.
class FontWeightField extends StatelessWidget {
  const FontWeightField({
    super.key,
    required this.family,
    required this.value,
    required this.onChanged,
  });

  final String? family;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = FontWeightName.of(value);
    return DropdownButtonFormField<FontWeightName>(
      key: const ValueKey('font-weight'),
      initialValue: current,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: [
        for (final w in FontWeightName.values)
          DropdownMenuItem(
            value: w,
            child: Text(
              '${w.label} · ${w.value}',
              style: styleWithFont(
                family,
                TextStyle(fontWeight: fontWeightOf(w.value)),
              ),
            ),
          ),
      ],
      onChanged: (w) {
        if (w != null) onChanged(w.value);
      },
    );
  }
}
