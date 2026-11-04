import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment, Axis;

import 'geometry.dart';

/// Sababu ya snap (inaamua rangi/mtindo wa mstari wa muda).
enum SnapKind { object, artboard, guide, grid, spacing }

/// Mstari wa muda unaoonyeshwa wakati wa kusogeza. Kwa [Axis.vertical]
/// mstari uko kwenye X = [position] kutoka Y = [start] hadi [end].
/// Vipimo vyote viko kwenye nafasi ya artboard.
class SnapLine {
  const SnapLine(this.axis, this.position, this.start, this.end, this.kind);
  final Axis axis;
  final double position;
  final double start;
  final double end;
  final SnapKind kind;
}

/// Kipimo cha umbali kati ya nukta [a] na [b] (nafasi ya artboard).
class Measure {
  const Measure(this.a, this.b);
  final Offset a;
  final Offset b;
  double get value => (b - a).distance;
}

class _Candidate {
  const _Candidate(this.value, this.kind, [this.source]);
  final double value;
  final SnapKind kind;
  final Rect? source;
}

/// Malengo ya snapping yaliyohesabiwa mara moja mwanzoni mwa kusogeza
/// (cache). Kila harakati inatafuta kwa binary search, si kwa kupitia
/// vipengele vyote.
class SnapTargets {
  SnapTargets({
    required this.artboard,
    this.others = const [],
    List<double> guideX = const [],
    List<double> guideY = const [],
    this.grid,
    this.gridOffset = Offset.zero,
    List<double> columnX = const [],
    List<double> rowY = const [],
    this.objects = true,
    this.guides = true,
    this.artboardEdges = true,
  }) {
    void add(List<_Candidate> list, double v, SnapKind k, [Rect? r]) =>
        list.add(_Candidate(v, k, r));
    if (objects) {
      for (final r in others) {
        for (final v in [r.left, r.center.dx, r.right]) {
          add(_x, v, SnapKind.object, r);
        }
        for (final v in [r.top, r.center.dy, r.bottom]) {
          add(_y, v, SnapKind.object, r);
        }
      }
    }
    if (artboardEdges) {
      for (final v in [0.0, artboard.width / 2, artboard.width]) {
        add(_x, v, SnapKind.artboard);
      }
      for (final v in [0.0, artboard.height / 2, artboard.height]) {
        add(_y, v, SnapKind.artboard);
      }
    }
    if (guides) {
      for (final v in guideX) {
        add(_x, v, SnapKind.guide);
      }
      for (final v in guideY) {
        add(_y, v, SnapKind.guide);
      }
    }
    for (final v in columnX) {
      add(_x, v, SnapKind.grid);
    }
    for (final v in rowY) {
      add(_y, v, SnapKind.grid);
    }
    _x.sort((a, b) => a.value.compareTo(b.value));
    _y.sort((a, b) => a.value.compareTo(b.value));
  }

  final Size artboard;
  final List<Rect> others;

  /// Ukubwa wa gridi ya miraba (null = hakuna snap kwa gridi).
  final double? grid;
  final Offset gridOffset;
  final bool objects;
  final bool guides;
  final bool artboardEdges;

  final _x = <_Candidate>[];
  final _y = <_Candidate>[];

  /// Lengo la karibu zaidi la [value] ndani ya [tolerance] (binary search).
  _Candidate? _nearest(List<_Candidate> list, double value, double tol) {
    var lo = 0, hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid].value < value) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    _Candidate? best;
    for (final i in [lo - 1, lo]) {
      if (i < 0 || i >= list.length) continue;
      final c = list[i];
      final d = (c.value - value).abs();
      if (d <= tol && (best == null || d < (best.value - value).abs())) {
        best = c;
      }
    }
    return best;
  }
}

class SnapResult {
  const SnapResult(this.rect, this.lines);
  final Rect rect;
  final List<SnapLine> lines;
}

/// Snap mstatili unaosogezwa. Kubadilisha ukubwa: [handle] ni kishiko
/// kinachoburutwa (k.m. [Alignment.centerLeft] = ukingo wa kushoto tu,
/// [Alignment.bottomRight] = kona); [resize] = true ni sawa na
/// bottomRight. [tolerance] iko kwenye nafasi ya artboard.
SnapResult snapRect(
  Rect moving,
  SnapTargets t,
  double tolerance, {
  bool resize = false,
  Alignment? handle,
}) {
  final h = handle ?? (resize ? Alignment.bottomRight : null);
  final (dx, lineX) = _snapAxis(moving, t, tolerance, Axis.vertical, h?.x);
  final (dy, lineY) = _snapAxis(moving, t, tolerance, Axis.horizontal, h?.y);
  final rect = h != null
      ? Rect.fromLTRB(
          moving.left + (h.x < 0 ? dx : 0),
          moving.top + (h.y < 0 ? dy : 0),
          moving.right + (h.x > 0 ? dx : 0),
          moving.bottom + (h.y > 0 ? dy : 0),
        )
      : moving.shift(Offset(dx, dy));
  // Ondoa makosa madogo ya float (k.m. 119.99999) kwenye mhimili uliosnap
  final r = rect;
  final exact = Rect.fromLTRB(
    lineX == null ? r.left : tidy(r.left),
    lineY == null ? r.top : tidy(r.top),
    lineX == null ? r.right : tidy(r.right),
    lineY == null ? r.bottom : tidy(r.bottom),
  );

  // Mistari inahesabiwa baada ya snap ili ifike kwenye nafasi mpya
  final lines = <SnapLine>[
    if (lineX case final l?) _lineFor(l, exact, t, Axis.vertical),
    if (lineY case final l?) _lineFor(l, exact, t, Axis.horizontal),
  ];
  return SnapResult(exact, lines);
}

(double, _Candidate?) _snapAxis(
  Rect r,
  SnapTargets t,
  double tol,
  Axis lineAxis,
  // Kubadilisha ukubwa: -1 = ukingo wa mwanzo (kushoto/juu), 1 = wa mwisho,
  // 0 = mhimili huu haubadiliki. null = kusogeza kipengele chote.
  double? side,
) {
  // lineAxis = vertical → tunasogeza X
  final isX = lineAxis == Axis.vertical;
  final resize = side != null;
  if (side == 0) return (0.0, null);
  final anchors = resize
      ? [isX ? (side < 0 ? r.left : r.right) : (side < 0 ? r.top : r.bottom)]
      : isX
      ? [r.left, r.center.dx, r.right]
      : [r.top, r.center.dy, r.bottom];
  final list = isX ? t._x : t._y;

  var bestDelta = 0.0;
  _Candidate? best;
  void consider(_Candidate c, double anchor) {
    final d = c.value - anchor;
    if (d.abs() <= tol && (best == null || d.abs() < bestDelta.abs())) {
      best = c;
      bestDelta = d;
    }
  }

  for (final a in anchors) {
    if (t._nearest(list, a, tol) case final c?) consider(c, a);
  }

  // Nafasi sawa: katikati ya majirani wawili (kushoto/kulia au juu/chini)
  if (!resize && t.objects) {
    final spacing = _equalSpacing(r, t.others, isX);
    if (spacing != null) consider(spacing, isX ? r.left : r.top);
  }

  // Gridi ya miraba: kona ya juu-kushoto (au kingo za resize)
  if (t.grid case final g? when best == null) {
    final off = isX ? t.gridOffset.dx : t.gridOffset.dy;
    for (final a in anchors.take(1)) {
      final v = ((a - off) / g).roundToDouble() * g + off;
      consider(_Candidate(v, SnapKind.grid), a);
    }
  }
  return (tidy(bestDelta), best);
}

/// Lengo la "nafasi sawa": weka [r] katikati ya jirani wa kushoto na wa
/// kulia (wanaopishana nayo kwenye mhimili mwingine).
_Candidate? _equalSpacing(Rect r, List<Rect> others, bool isX) {
  Rect? before, after;
  for (final o in others) {
    final overlap = isX
        ? o.top < r.bottom && o.bottom > r.top
        : o.left < r.right && o.right > r.left;
    if (!overlap) continue;
    if (isX) {
      if (o.right <= r.left + r.width / 2 &&
          (before == null || o.right > before.right)) {
        before = o;
      }
      if (o.left >= r.right - r.width / 2 &&
          (after == null || o.left < after.left)) {
        after = o;
      }
    } else {
      if (o.bottom <= r.top + r.height / 2 &&
          (before == null || o.bottom > before.bottom)) {
        before = o;
      }
      if (o.top >= r.bottom - r.height / 2 &&
          (after == null || o.top < after.top)) {
        after = o;
      }
    }
  }
  if (before == null || after == null) return null;
  final space = isX ? after.left - before.right : after.top - before.bottom;
  final size = isX ? r.width : r.height;
  if (space <= size) return null;
  final start = (isX ? before.right : before.bottom) + (space - size) / 2;
  return _Candidate(start, SnapKind.spacing);
}

SnapLine _lineFor(_Candidate c, Rect r, SnapTargets t, Axis axis) {
  final isX = axis == Axis.vertical;
  final full = isX ? t.artboard.height : t.artboard.width;
  if (c.kind == SnapKind.spacing) {
    // Mstari wa nafasi sawa unapita katikati ya kipengele
    return SnapLine(
      axis == Axis.vertical ? Axis.horizontal : Axis.vertical,
      isX ? r.center.dy : r.center.dx,
      isX ? r.left : r.top,
      isX ? r.right : r.bottom,
      SnapKind.spacing,
    );
  }
  final position = c.value;
  if (c.source case final s?) {
    return SnapLine(
      axis,
      position,
      min(isX ? r.top : r.left, isX ? s.top : s.left),
      max(isX ? r.bottom : r.right, isX ? s.bottom : s.right),
      c.kind,
    );
  }
  return SnapLine(axis, position, 0, full, c.kind);
}

/// Umbali kutoka [r] hadi kipengele cha karibu (au ukingo wa artboard)
/// kwa kila upande: kushoto, kulia, juu, chini.
List<Measure> measureDistances(Rect r, List<Rect> others, Size artboard) {
  final out = <Measure>[];
  final cy = r.center.dy, cx = r.center.dx;

  double left = 0, right = artboard.width, top = 0, bottom = artboard.height;
  for (final o in others) {
    final vOverlap = o.top < r.bottom && o.bottom > r.top;
    final hOverlap = o.left < r.right && o.right > r.left;
    if (vOverlap && o.right <= r.left) left = max(left, o.right);
    if (vOverlap && o.left >= r.right) right = min(right, o.left);
    if (hOverlap && o.bottom <= r.top) top = max(top, o.bottom);
    if (hOverlap && o.top >= r.bottom) bottom = min(bottom, o.top);
  }
  if (r.left > left) out.add(Measure(Offset(left, cy), Offset(r.left, cy)));
  if (right > r.right) out.add(Measure(Offset(r.right, cy), Offset(right, cy)));
  if (r.top > top) out.add(Measure(Offset(cx, top), Offset(cx, r.top)));
  if (bottom > r.bottom) {
    out.add(Measure(Offset(cx, r.bottom), Offset(cx, bottom)));
  }
  return out;
}

/// Umbali kati ya mistatili miwili (kwa kukagua kwa Alt bila kusogeza).
List<Measure> measureBetween(Rect a, Rect b) {
  final out = <Measure>[];
  final y = (max(a.top, b.top) + min(a.bottom, b.bottom)) / 2;
  final x = (max(a.left, b.left) + min(a.right, b.right)) / 2;
  if (b.left >= a.right) {
    out.add(Measure(Offset(a.right, y), Offset(b.left, y)));
  } else if (a.left >= b.right) {
    out.add(Measure(Offset(b.right, y), Offset(a.left, y)));
  }
  if (b.top >= a.bottom) {
    out.add(Measure(Offset(x, a.bottom), Offset(x, b.top)));
  } else if (a.top >= b.bottom) {
    out.add(Measure(Offset(x, b.bottom), Offset(x, a.top)));
  }
  return out;
}
