import 'dart:math';

import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../icons/icon_style.dart';
import '../models/ui_element.dart';

/// Inachora kipengele kimoja kama kinavyoonekana kwenye skrini.
class ElementView extends StatelessWidget {
  const ElementView({super.key, required this.element});

  final UiElement element;

  @override
  Widget build(BuildContext context) {
    final e = element;
    final radius = BorderRadius.circular(e.radius);
    final textStyle = TextStyle(
      color: e.textColor,
      fontSize: e.fontSize,
      fontWeight: e.bold ? FontWeight.w600 : FontWeight.w400,
    );

    // Mpangilio wa maandishi ndani ya kisanduku (text alignment)
    final align = e.effectiveTextAlign;
    final inside = Alignment(switch (align) {
      TextAlign.center => 0,
      TextAlign.right || TextAlign.end => 1,
      _ => -1,
    }, e.vAlign.y);
    Widget label({int? maxLines}) => SizedBox(
      width: double.infinity,
      child: Text(
        e.text,
        style: textStyle,
        textAlign: align,
        maxLines: maxLines,
      ),
    );

    return switch (e.type) {
      ElementType.text => Align(alignment: inside, child: label()),
      ElementType.button => Container(
        alignment: inside,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: e.color, borderRadius: radius),
        child: label(maxLines: 1),
      ),
      ElementType.input => Container(
        alignment: inside,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: e.color),
        ),
        child: label(maxLines: 1),
      ),
      ElementType.image => Container(
        decoration: BoxDecoration(color: e.color, borderRadius: radius),
        child: Center(
          child: Icon(
            AppIcons.image,
            color: e.textColor,
            size: min(e.rect.width, e.rect.height) * 0.3,
          ),
        ),
      ),
      ElementType.container => DecoratedBox(
        decoration: BoxDecoration(color: e.color, borderRadius: radius),
      ),
      ElementType.appBar => Container(
        color: e.color,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(navBarMenuIcon, color: e.textColor),
            const SizedBox(width: 16),
            Expanded(child: Text(e.text, style: textStyle, maxLines: 1)),
          ],
        ),
      ),
      ElementType.navBar => Container(
        decoration: BoxDecoration(
          color: e.color,
          border: const Border(top: BorderSide(color: Color(0xFFEAECF0))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final (i, name) in navBarIconNames.indexed)
              IconStyle.broken.build(
                name,
                size: 24,
                color: i == 0 ? e.textColor : const Color(0xFF98A2B3),
              ),
          ],
        ),
      ),
      ElementType.iconItem => FittedBox(
        child: e.iconStyle.build(e.text, size: 24, color: e.color),
      ),
      ElementType.avatar => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
        child: Text(e.text, style: textStyle, maxLines: 1),
      ),
      ElementType.toggle => _Toggle(color: e.color),
      ElementType.divider => Center(
        child: Container(height: 1, color: e.color),
      ),
    };
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final knob = box.maxHeight - 6;
        return Container(
          padding: const EdgeInsets.all(3),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(box.maxHeight),
          ),
          child: Container(
            width: knob,
            height: knob,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
