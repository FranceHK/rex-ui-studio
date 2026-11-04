import 'package:flutter/material.dart';

import '../devices/device_preset.dart';

/// Preview ya kifaa kwa uwiano sahihi: bezel, safe area na cutouts.
///
/// [size] ni ukubwa wa kimantiki kwa mwelekeo wa sasa; [safeArea] na
/// [cutouts] tayari zimegeuzwa kwa mwelekeo huo.
class DevicePreview extends StatelessWidget {
  const DevicePreview({
    super.key,
    required this.size,
    this.cornerRadius = 44,
    this.bezel = true,
    this.safeArea,
    this.showSafeArea = false,
    this.cutouts = const [],
    this.background = Colors.white,
    this.label,
  });

  final Size size;
  final double cornerRadius;
  final bool bezel;
  final EdgeInsets? safeArea;
  final bool showSafeArea;
  final List<DisplayCutout> cutouts;
  final Color background;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Bezel ni sehemu ndogo ya upande mfupi wa skrini
    final bezelWidth = bezel ? size.shortestSide * 0.035 + 4 : 0.0;
    final outer = Size(
      size.width + bezelWidth * 2,
      size.height + bezelWidth * 2,
    );

    final screen = ClipRRect(
      borderRadius: BorderRadius.circular(cornerRadius),
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: background)),
            if (label != null)
              Center(
                child: Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: size.shortestSide * 0.06,
                    fontWeight: FontWeight.w600,
                    color: background.computeLuminance() > 0.5
                        ? Colors.black26
                        : Colors.white38,
                  ),
                ),
              ),
            if (showSafeArea && safeArea != null)
              Positioned.fill(child: SafeAreaGuides(insets: safeArea!)),
            for (final c in cutouts)
              Positioned(
                left: c.rect.left * size.width,
                top: c.rect.top * size.height,
                width: c.rect.width * size.width,
                height: c.rect.height * size.height,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: c.circle ? 1 : c.rect.width / c.rect.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: c.circle ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: c.circle
                            ? null
                            : BorderRadius.circular(size.shortestSide * 0.08),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return FittedBox(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: outer.width,
        height: outer.height,
        padding: EdgeInsets.all(bezelWidth),
        decoration: BoxDecoration(
          color: bezel ? const Color(0xFF1D2433) : Colors.transparent,
          borderRadius: BorderRadius.circular(cornerRadius + bezelWidth),
          border: bezel
              ? null
              : Border.all(color: scheme.outlineVariant, width: 1),
          boxShadow: bezel
              ? const [
                  BoxShadow(
                    color: Color(0x33101828),
                    blurRadius: 40,
                    offset: Offset(0, 16),
                  ),
                ]
              : null,
        ),
        child: screen,
      ),
    );
  }
}

/// Mikanda ya safe area (inatumika kwenye preview na kwenye canvas).
class SafeAreaGuides extends StatelessWidget {
  const SafeAreaGuides({super.key, required this.insets, this.scale = 1});

  final EdgeInsets insets;
  final double scale;

  @override
  Widget build(BuildContext context) {
    const fill = Color(0x26F04438);
    const line = Color(0xAAF04438);
    final i = insets * scale;
    Widget band({
      double? l,
      double? t,
      double? r,
      double? b,
      double? w,
      double? h,
    }) => Positioned(
      left: l,
      top: t,
      right: r,
      bottom: b,
      width: w,
      height: h,
      child: const ColoredBox(color: fill),
    );
    return IgnorePointer(
      child: Stack(
        children: [
          if (i.top > 0) band(l: 0, t: 0, r: 0, h: i.top),
          if (i.bottom > 0) band(l: 0, b: 0, r: 0, h: i.bottom),
          if (i.left > 0) band(l: 0, t: 0, b: 0, w: i.left),
          if (i.right > 0) band(r: 0, t: 0, b: 0, w: i.right),
          Positioned(
            left: i.left,
            top: i.top,
            right: i.right,
            bottom: i.bottom,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: line)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Geuza cutout ya wima kuwa mlalo (simu imezungushwa kushoto).
DisplayCutout rotateCutout(DisplayCutout c) => DisplayCutout(
  Rect.fromLTWH(
    c.rect.top,
    1 - c.rect.left - c.rect.width,
    c.rect.height,
    c.rect.width,
  ),
  circle: c.circle,
);
