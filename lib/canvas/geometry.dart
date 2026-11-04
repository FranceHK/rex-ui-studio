import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment;

/// The single coordinate transform used by the canvas, rulers, guides,
/// snapping and alignment.
///
/// Three spaces:
///  * screen  — pixels of the canvas widget (after zoom and pan)
///  * world   — the whole canvas; each artboard has its `position` here
///  * local   — inside an artboard (elements are stored this way)
///
/// `screen = world × scale + offset`. Elements have no rotation or
/// groups, so their bounds are plain axis-aligned rectangles.
class CanvasTransform {
  const CanvasTransform(this.scale, this.offset);

  final double scale;
  final Offset offset;

  Offset toScreen(Offset world) => world * scale + offset;
  Offset toWorld(Offset screen) => (screen - offset) / scale;

  Rect rectToScreen(Rect world) =>
      Rect.fromPoints(toScreen(world.topLeft), toScreen(world.bottomRight));

  /// Convert a distance in screen pixels to world (e.g. a 6 px snapping
  /// tolerance stays 6 px at any zoom).
  double screenToWorld(double pixels) => pixels / scale;

  /// Zoom around [focal] (screen) so the point under it stays put.
  CanvasTransform zoomAt(double nextScale, Offset focal) {
    final world = toWorld(focal);
    return CanvasTransform(nextScale, focal - world * nextScale);
  }

  CanvasTransform panBy(Offset delta) => CanvasTransform(scale, offset + delta);

  /// The view that fits [world] inside [viewport] (with [pad] padding).
  static CanvasTransform fit(
    Rect world,
    Size viewport, {
    double pad = 56,
    double maxScale = 1,
  }) {
    final s = min(
      (viewport.width - pad * 2) / world.width,
      (viewport.height - pad * 2) / world.height,
    ).clamp(0.02, maxScale);
    final center = Offset(viewport.width / 2, viewport.height / 2);
    return CanvasTransform(s, center - world.center * s);
  }
}

/// "Nice" ruler steps.
const _niceSteps = [
  1.0,
  2.0,
  5.0,
  10.0,
  20.0,
  25.0,
  50.0,
  100.0,
  200.0,
  250.0,
  500.0,
  1000.0,
  2000.0,
  2500.0,
  5000.0,
  10000.0,
];

/// Spacing between ruler numbers at a given [scale]: the smallest step
/// that is at least [minPixels] screen pixels, so the numbers don't
/// overlap (zoomed out → big steps; zoomed in → small steps).
double rulerStep(double scale, {double minPixels = 56}) {
  for (final s in _niceSteps) {
    if (s * scale >= minPixels) return s;
  }
  return _niceSteps.last;
}

/// The rectangle around all the rectangles.
Rect boundsOf(Iterable<Rect> rects) =>
    rects.reduce((a, b) => a.expandToInclude(b));

/// Round to 2 decimal places (avoids 15.000000001).
double tidy(double v) => (v * 100).roundToDouble() / 100;

/// Smallest width/height of an element being resized.
const minElementSize = Size(8, 4);

/// The new rectangle after dragging [handle] by [delta] (artboard
/// coordinates). The opposite edge stays put; [keepAspect] (Shift)
/// keeps the width/height ratio on corners.
Rect resizeRect(
  Rect start,
  Alignment handle,
  Offset delta, {
  bool keepAspect = false,
  Size minSize = minElementSize,
}) {
  var left = start.left, top = start.top;
  var right = start.right, bottom = start.bottom;
  if (handle.x < 0) left = (left + delta.dx).roundToDouble();
  if (handle.x > 0) right = (right + delta.dx).roundToDouble();
  if (handle.y < 0) top = (top + delta.dy).roundToDouble();
  if (handle.y > 0) bottom = (bottom + delta.dy).roundToDouble();

  var w = max(minSize.width, right - left);
  var h = max(minSize.height, bottom - top);
  if (keepAspect && handle.x != 0 && handle.y != 0 && start.height > 0) {
    final ratio = start.width / start.height;
    // Follow the axis that moved the most
    if (w / start.width >= h / start.height) {
      h = (w / ratio).roundToDouble();
    } else {
      w = (h * ratio).roundToDouble();
    }
  }
  // Edges that aren't dragged stay where they are
  final l = handle.x < 0 ? start.right - w : start.left;
  final t = handle.y < 0 ? start.bottom - h : start.top;
  return Rect.fromLTWH(l, t, w, h);
}
