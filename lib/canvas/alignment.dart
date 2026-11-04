import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart' show Axis;

import 'geometry.dart';

/// Kazi 7 za kupanga (ya 8 ni "align to key object" — ni lengo, si
/// mwelekeo; tazama [AlignTo] kwenye layout.dart).
enum AlignOp { left, hCenter, right, top, vCenter, bottom, centerBoth }

enum DistributeOp { left, hCenter, right, top, vCenter, bottom }

/// Panga [rects] dhidi ya [target]. Ukubwa wa kila kipengele haubadiliki;
/// [keyId] (kipengele kikuu) hakisogei.
Map<String, Rect> alignRects(
  Map<String, Rect> rects,
  AlignOp op,
  Rect target, {
  String? keyId,
}) {
  return {
    for (final MapEntry(key: id, value: r) in rects.entries)
      id: id == keyId ? r : _alignOne(r, op, target),
  };
}

Rect _alignOne(Rect r, AlignOp op, Rect t) {
  final dx = switch (op) {
    AlignOp.left => t.left - r.left,
    AlignOp.hCenter || AlignOp.centerBoth => t.center.dx - r.center.dx,
    AlignOp.right => t.right - r.right,
    _ => 0.0,
  };
  final dy = switch (op) {
    AlignOp.top => t.top - r.top,
    AlignOp.vCenter || AlignOp.centerBoth => t.center.dy - r.center.dy,
    AlignOp.bottom => t.bottom - r.bottom,
    _ => 0.0,
  };
  return r.shift(Offset(tidy(dx), tidy(dy)));
}

double _anchor(Rect r, DistributeOp op) => switch (op) {
  DistributeOp.left => r.left,
  DistributeOp.hCenter => r.center.dx,
  DistributeOp.right => r.right,
  DistributeOp.top => r.top,
  DistributeOp.vCenter => r.center.dy,
  DistributeOp.bottom => r.bottom,
};

bool _horizontal(DistributeOp op) =>
    op == DistributeOp.left ||
    op == DistributeOp.hCenter ||
    op == DistributeOp.right;

/// Sambaza kingo/vituo kwa umbali sawa. Vya kwanza na vya mwisho
/// havisogei. Inahitaji vipengele ≥ 3.
Map<String, Rect> distributeRects(Map<String, Rect> rects, DistributeOp op) {
  if (rects.length < 3) return Map.of(rects);
  final sorted = rects.entries.toList()
    ..sort((a, b) => _anchor(a.value, op).compareTo(_anchor(b.value, op)));
  final first = _anchor(sorted.first.value, op);
  final last = _anchor(sorted.last.value, op);
  final step = (last - first) / (sorted.length - 1);
  final h = _horizontal(op);
  return {
    for (final (i, e) in sorted.indexed)
      e.key: e.value.shift(
        h
            ? Offset(tidy(first + step * i - _anchor(e.value, op)), 0)
            : Offset(0, tidy(first + step * i - _anchor(e.value, op))),
      ),
  };
}

/// Nafasi sawa kati ya vipengele (vya pembeni havisogei). ≥ 3.
Map<String, Rect> distributeSpacing(Map<String, Rect> rects, Axis axis) {
  if (rects.length < 3) return Map.of(rects);
  final h = axis == Axis.horizontal;
  final sorted = rects.entries.toList()
    ..sort(
      (a, b) => h
          ? a.value.left.compareTo(b.value.left)
          : a.value.top.compareTo(b.value.top),
    );
  final span = h
      ? sorted.last.value.right - sorted.first.value.left
      : sorted.last.value.bottom - sorted.first.value.top;
  final total = sorted.fold(
    0.0,
    (s, e) => s + (h ? e.value.width : e.value.height),
  );
  final gap = (span - total) / (sorted.length - 1);
  return _stack(sorted, axis, gap);
}

/// Weka vipengele mfululizo kwa nafasi [gap] (kuanzia cha kwanza). ≥ 2.
Map<String, Rect> applyGap(Map<String, Rect> rects, Axis axis, double gap) {
  if (rects.length < 2) return Map.of(rects);
  final h = axis == Axis.horizontal;
  final sorted = rects.entries.toList()
    ..sort(
      (a, b) => h
          ? a.value.left.compareTo(b.value.left)
          : a.value.top.compareTo(b.value.top),
    );
  return _stack(sorted, axis, gap);
}

Map<String, Rect> _stack(
  List<MapEntry<String, Rect>> sorted,
  Axis axis,
  double gap,
) {
  final h = axis == Axis.horizontal;
  var cursor = h ? sorted.first.value.left : sorted.first.value.top;
  final out = <String, Rect>{};
  for (final e in sorted) {
    final r = e.value;
    out[e.key] = h
        ? Rect.fromLTWH(tidy(cursor), r.top, r.width, r.height)
        : Rect.fromLTWH(r.left, tidy(cursor), r.width, r.height);
    cursor += (h ? r.width : r.height) + gap;
  }
  return out;
}

/// Tidy up: gawa vipengele kwenye mistari (rows) kulingana na nafasi
/// zao, kisha panga kila mstari kushoto→kulia kwa [hGap] na mistari juu→
/// chini kwa [vGap], kuanzia kona ya juu-kushoto ya uteuzi.
Map<String, Rect> tidyUp(
  Map<String, Rect> rects, {
  required double hGap,
  required double vGap,
}) {
  if (rects.length < 2) return Map.of(rects);
  final origin = boundsOf(rects.values).topLeft;
  final byTop = rects.entries.toList()
    ..sort((a, b) => a.value.center.dy.compareTo(b.value.center.dy));

  // Mistari: kipengele kinaingia mstari ikiwa kituo chake kiko ndani ya
  // urefu wa mstari huo.
  final rows = <List<MapEntry<String, Rect>>>[];
  for (final e in byTop) {
    final row = rows.lastOrNull;
    if (row != null) {
      final band = boundsOf(row.map((r) => r.value));
      if (e.value.center.dy <= band.bottom) {
        row.add(e);
        continue;
      }
    }
    rows.add([e]);
  }

  final out = <String, Rect>{};
  var y = origin.dy;
  for (final row in rows) {
    row.sort((a, b) => a.value.left.compareTo(b.value.left));
    var x = origin.dx;
    var rowHeight = 0.0;
    for (final e in row) {
      out[e.key] = Rect.fromLTWH(
        tidy(x),
        tidy(y),
        e.value.width,
        e.value.height,
      );
      x += e.value.width + hGap;
      rowHeight = max(rowHeight, e.value.height);
    }
    y += rowHeight + vGap;
  }
  return out;
}

/// Smart arrange: kama tidy up, lakini nafasi zinachukuliwa kutoka kwenye
/// nafasi za sasa (wastani, si chini ya 0).
Map<String, Rect> smartArrange(Map<String, Rect> rects) {
  double avgGap(Axis axis) {
    final h = axis == Axis.horizontal;
    final sorted = rects.values.toList()
      ..sort((a, b) => h ? a.left.compareTo(b.left) : a.top.compareTo(b.top));
    final gaps = [
      for (var i = 1; i < sorted.length; i++)
        h
            ? sorted[i].left - sorted[i - 1].right
            : sorted[i].top - sorted[i - 1].bottom,
    ].where((g) => g >= 0);
    if (gaps.isEmpty) return 16;
    return (gaps.reduce((a, b) => a + b) / gaps.length).roundToDouble();
  }

  return tidyUp(
    rects,
    hGap: avgGap(Axis.horizontal),
    vGap: avgGap(Axis.vertical),
  );
}
