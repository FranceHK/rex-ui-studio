import 'dart:math';

import 'package:flutter/material.dart';

import '../canvas/geometry.dart';
import '../canvas/layout.dart';
import '../canvas/snapping.dart';

const rulerSize = 20.0;

/// Ruler ya juu (horizontal) au ya kushoto (vertical). Namba ni kwenye
/// nafasi ya design (pt/dp), zikianzia [origin] (world), na hatua
/// inabadilika na zoom ([rulerStep]).
class RulerPainter extends CustomPainter {
  RulerPainter({
    required this.view,
    required this.origin,
    required this.horizontal,
    required this.colors,
    this.cursor,
    this.highlight,
  });

  final CanvasTransform view;
  final Offset origin;
  final bool horizontal;
  final ColorScheme colors;

  /// Nafasi ya kielekezi (world) — alama ndogo kwenye ruler.
  final Offset? cursor;

  /// Bendi ya uteuzi (world), kama Figma.
  final Rect? highlight;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.surface);
    final length = horizontal ? size.width : size.height;
    final scale = view.scale;
    final base = horizontal ? view.offset.dx : view.offset.dy;
    final o = horizontal ? origin.dx : origin.dy;

    double toScreen(double coord) => (coord + o) * scale + base;

    if (highlight case final h?) {
      final a = toScreen((horizontal ? h.left : h.top) - o);
      final b = toScreen((horizontal ? h.right : h.bottom) - o);
      final band = horizontal
          ? Rect.fromLTRB(a, 0, b, size.height)
          : Rect.fromLTRB(0, a, size.width, b);
      canvas.drawRect(
        band,
        Paint()..color = colors.primary.withValues(alpha: 0.14),
      );
    }

    final step = rulerStep(scale);
    final minor = step % 5 == 0
        ? step / 5
        : step % 2 == 0
        ? step / 2
        : step;
    final startCoord = ((-base) / scale) - o;
    final endCoord = ((length - base) / scale) - o;
    final first = (startCoord / minor).floor();

    final tick = Paint()
      ..color = colors.outline
      ..strokeWidth = 1;
    for (var n = first; n * minor <= endCoord; n++) {
      final c = n * minor;
      final p = toScreen(c).roundToDouble() + 0.5;
      final major = ((c / step) - (c / step).roundToDouble()).abs() < 1e-6;
      final len = major ? size.shortestSide * 0.55 : size.shortestSide * 0.25;
      if (horizontal) {
        canvas.drawLine(
          Offset(p, size.height),
          Offset(p, size.height - len),
          tick,
        );
      } else {
        canvas.drawLine(
          Offset(size.width, p),
          Offset(size.width - len, p),
          tick,
        );
      }
      if (major) {
        final tp = TextPainter(
          text: TextSpan(
            text: _label(c),
            style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        if (horizontal) {
          tp.paint(canvas, Offset(p + 2, 1));
        } else {
          canvas.save();
          canvas.translate(1, p - 2);
          canvas.rotate(-pi / 2);
          tp.paint(canvas, Offset.zero);
          canvas.restore();
        }
      }
    }

    if (cursor case final cur?) {
      final p = horizontal ? view.toScreen(cur).dx : view.toScreen(cur).dy;
      final paint = Paint()
        ..color = colors.primary
        ..strokeWidth = 1;
      if (horizontal) {
        canvas.drawLine(Offset(p, 0), Offset(p, size.height), paint);
      } else {
        canvas.drawLine(Offset(0, p), Offset(size.width, p), paint);
      }
    }

    final border = Paint()..color = colors.outlineVariant;
    if (horizontal) {
      canvas.drawLine(
        Offset(0, size.height - 0.5),
        Offset(size.width, size.height - 0.5),
        border,
      );
    } else {
      canvas.drawLine(
        Offset(size.width - 0.5, 0),
        Offset(size.width - 0.5, size.height),
        border,
      );
    }
  }

  String _label(double v) {
    final r = tidy(v);
    return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  }

  @override
  bool shouldRepaint(RulerPainter old) =>
      old.view.scale != view.scale ||
      old.view.offset != view.offset ||
      old.origin != origin ||
      old.cursor != cursor ||
      old.highlight != highlight ||
      old.colors != colors;
}

/// Gridi ya miraba, safu na mistari ndani ya artboard (nafasi ya artboard;
/// inachorwa ndani ya FittedBox kwa hiyo [pixelScale] ni pixel kwa unit).
class GridPainter extends CustomPainter {
  GridPainter(this.grid, this.pixelScale);

  final GridSettings grid;
  final double pixelScale;

  @override
  void paint(Canvas canvas, Size size) {
    final band = Paint()..color = grid.color.withValues(alpha: grid.opacity);
    if (grid.columns.enabled) {
      for (final (a, b) in grid.columns.tracks(size.width)) {
        canvas.drawRect(Rect.fromLTRB(a, 0, b, size.height), band);
      }
    }
    if (grid.rows.enabled) {
      for (final (a, b) in grid.rows.tracks(size.height)) {
        canvas.drawRect(Rect.fromLTRB(0, a, size.width, b), band);
      }
    }
    // Gridi ya miraba: ichore tu ikiwa mistari haijabanana sana (≥ 4 px)
    if (grid.show && grid.size * pixelScale >= 4) {
      final line = Paint()
        ..color = grid.color.withValues(alpha: min(1, grid.opacity * 2.5))
        ..strokeWidth = 1 / pixelScale;
      final g = grid.size;
      final ox = grid.offset.dx % g, oy = grid.offset.dy % g;
      for (var x = ox; x <= size.width; x += g) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
      }
      for (var y = oy; y <= size.height; y += g) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
    }
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.grid != grid || old.pixelScale != pixelScale;
}

/// Mistari ya snapping, vipimo vya umbali na marquee (nafasi ya skrini).
class OverlayPainter extends CustomPainter {
  OverlayPainter({
    required this.view,
    required this.artboardOrigin,
    this.lines = const [],
    this.measures = const [],
    this.marquee,
    required this.color,
  });

  final CanvasTransform view;

  /// Kona ya juu-kushoto ya artboard ya sasa (world).
  final Offset artboardOrigin;
  final List<SnapLine> lines;
  final List<Measure> measures;

  /// Mstatili wa kuchagua (nafasi ya artboard).
  final Rect? marquee;
  final Color color;

  Offset _s(Offset local) => view.toScreen(local + artboardOrigin);

  @override
  void paint(Canvas canvas, Size size) {
    const snapColor = Color(0xFFF04438);
    final paint = Paint()
      ..color = snapColor
      ..strokeWidth = 1;
    for (final l in lines) {
      final (a, b) = l.axis == Axis.vertical
          ? (Offset(l.position, l.start), Offset(l.position, l.end))
          : (Offset(l.start, l.position), Offset(l.end, l.position));
      canvas.drawLine(_s(a), _s(b), paint);
    }

    for (final m in measures) {
      final a = _s(m.a), b = _s(m.b);
      canvas.drawLine(a, b, paint);
      final horizontal = (a.dy - b.dy).abs() < 0.5;
      final cap = horizontal ? const Offset(0, 4) : const Offset(4, 0);
      canvas.drawLine(a - cap, a + cap, paint);
      canvas.drawLine(b - cap, b + cap, paint);
      _pill(canvas, (a + b) / 2, _n(m.value), snapColor);
    }

    if (marquee case final r?) {
      final rect = Rect.fromPoints(_s(r.topLeft), _s(r.bottomRight));
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.08));
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(OverlayPainter old) => true;
}

String _n(double v) {
  final r = tidy(v);
  return r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1);
}

/// Kibao kidogo cha namba (k.m. umbali "16").
void _pill(Canvas canvas, Offset center, String text, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 10,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final rect = Rect.fromCenter(
    center: center,
    width: tp.width + 8,
    height: tp.height + 4,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(4)),
    Paint()..color = color,
  );
  tp.paint(canvas, rect.topLeft + const Offset(4, 2));
}
