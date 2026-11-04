import 'dart:math';
import 'dart:ui';

/// Ubadilishaji mmoja wa nafasi unaotumiwa na canvas, rulers, guides,
/// snapping na alignment.
///
/// Nafasi tatu:
///  * screen  — pixel za widget ya canvas (baada ya zoom na pan)
///  * world   — nafasi ya canvas nzima; kila artboard ina `position` hapa
///  * local   — nafasi ndani ya artboard (vipengele vinahifadhiwa hivi)
///
/// `screen = world × scale + offset`. Vipengele havina rotation wala
/// groups, kwa hiyo bounds zake ni mstatili wa kawaida (axis-aligned).
class CanvasTransform {
  const CanvasTransform(this.scale, this.offset);

  final double scale;
  final Offset offset;

  Offset toScreen(Offset world) => world * scale + offset;
  Offset toWorld(Offset screen) => (screen - offset) / scale;

  Rect rectToScreen(Rect world) =>
      Rect.fromPoints(toScreen(world.topLeft), toScreen(world.bottomRight));

  /// Badilisha umbali wa pixel za skrini kuwa world (k.m. tolerance ya
  /// snapping ya pixel 6 inabaki 6 kwa zoom yoyote).
  double screenToWorld(double pixels) => pixels / scale;

  /// Zoom kuzunguka [focal] (screen) ili nukta iliyo chini yake isisogee.
  CanvasTransform zoomAt(double nextScale, Offset focal) {
    final world = toWorld(focal);
    return CanvasTransform(nextScale, focal - world * nextScale);
  }

  CanvasTransform panBy(Offset delta) => CanvasTransform(scale, offset + delta);

  /// Mwonekano unaotosha [world] ndani ya [viewport] (na nafasi [pad]).
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

/// Hatua "nzuri" za rulers.
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

/// Nafasi kati ya namba kwenye ruler kwa [scale] fulani: hatua ndogo
/// kabisa ambayo ina angalau [minPixels] pixel za skrini, ili namba
/// zisigongane (zoom ndogo → hatua kubwa; zoom kubwa → hatua ndogo).
double rulerStep(double scale, {double minPixels = 56}) {
  for (final s in _niceSteps) {
    if (s * scale >= minPixels) return s;
  }
  return _niceSteps.last;
}

/// Mstatili unaozunguka mistatili yote.
Rect boundsOf(Iterable<Rect> rects) =>
    rects.reduce((a, b) => a.expandToInclude(b));

/// Zungusha namba hadi nafasi 2 za desimali (kuepuka 15.000000001).
double tidy(double v) => (v * 100).roundToDouble() / 100;
