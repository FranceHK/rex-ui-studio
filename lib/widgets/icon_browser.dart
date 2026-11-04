import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../icons/icon_style.dart';
import '../models/ui_element.dart';

/// Kutafuta icons za amazing_icons kwa jina na mtindo.
/// Kubofya icon kunaita [onPick]; ikiwa [draggable], icon inaweza
/// kuburutwa moja kwa moja kwenye skrini.
class IconBrowser extends StatefulWidget {
  const IconBrowser({
    super.key,
    required this.onPick,
    this.initialStyle = IconStyle.broken,
    this.selected,
    this.draggable = false,
  });

  final void Function(IconStyle style, String name) onPick;
  final IconStyle initialStyle;
  final String? selected;
  final bool draggable;

  @override
  State<IconBrowser> createState() => _IconBrowserState();
}

class _IconBrowserState extends State<IconBrowser> {
  late IconStyle _style = widget.initialStyle;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final names = [
      for (final n in _style.names)
        if (iconMatches(n, _query)) n,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Tafuta icon… (k.m. home, arrow, wallet)',
            prefixIcon: Icon(AppIcons.search),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in IconStyle.values)
              ChoiceChip(
                label: Text(s.label),
                selected: s == _style,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _style = s),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${names.length} icons · ${_style.label}'
          '${widget.draggable ? ' · bofya au buruta' : ''}',
          style: TextStyle(color: scheme.outline, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: names.isEmpty
              ? Center(
                  child: Text(
                    'Hakuna icon inayolingana na "$_query"',
                    style: TextStyle(color: scheme.outline),
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 56,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: names.length,
                  itemBuilder: (context, i) => _tile(names[i], scheme),
                ),
        ),
      ],
    );
  }

  Widget _tile(String name, ColorScheme scheme) {
    final selected = name == widget.selected && _style == widget.initialStyle;
    final preview = _style.build(name, size: 24, color: scheme.onSurface);
    final tile = Tooltip(
      message: name,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => widget.onPick(_style, name),
          child: Center(child: preview),
        ),
      ),
    );
    if (!widget.draggable) return tile;

    return Draggable<NewElement>(
      data: NewElement(ElementType.iconItem, text: name, iconStyle: _style),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: _style.build(name, size: 32, color: brandColor),
        ),
      ),
      child: tile,
    );
  }
}
