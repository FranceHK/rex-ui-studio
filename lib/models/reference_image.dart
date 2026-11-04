import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

/// How a reference image is laid over its artboard.
enum ReferenceFit {
  /// Full artboard width, keeping the aspect ratio (top aligned).
  width('Fit width'),

  /// Stretched to cover the whole artboard.
  fill('Fill screen');

  const ReferenceFit(this.label);
  final String label;
}

/// A picture (e.g. a screenshot of an existing app) shown on an artboard
/// to trace over while cloning a design. It is never exported: not in the
/// PNG, not in the code.
class ReferenceImage {
  ReferenceImage({
    required this.bytes,
    required this.pixelSize,
    this.opacity = 0.5,
    this.visible = true,
    this.onTop = false,
    this.fit = ReferenceFit.width,
  });

  /// Encoded image (PNG/JPEG/…).
  final Uint8List bytes;

  /// Size of the decoded image in pixels.
  final Size pixelSize;
  final double opacity;
  final bool visible;

  /// Drawn above the elements (to compare) instead of beneath them.
  final bool onTop;
  final ReferenceFit fit;

  /// Where the image sits inside an artboard of [artboard] size.
  Rect rectIn(Size artboard) => switch (fit) {
    ReferenceFit.fill => Offset.zero & artboard,
    ReferenceFit.width => Rect.fromLTWH(
      0,
      0,
      artboard.width,
      artboard.width * pixelSize.height / pixelSize.width,
    ),
  };

  ReferenceImage copyWith({
    double? opacity,
    bool? visible,
    bool? onTop,
    ReferenceFit? fit,
  }) => ReferenceImage(
    bytes: bytes,
    pixelSize: pixelSize,
    opacity: opacity ?? this.opacity,
    visible: visible ?? this.visible,
    onTop: onTop ?? this.onTop,
    fit: fit ?? this.fit,
  );

  Map<String, dynamic> toJson() => {
    'data': base64Encode(bytes),
    'size': [pixelSize.width, pixelSize.height],
    'opacity': opacity,
    if (!visible) 'visible': false,
    if (onTop) 'onTop': true,
    'fit': fit.name,
  };

  factory ReferenceImage.fromJson(Map<String, dynamic> json) {
    final size = (json['size'] as List).cast<num>();
    return ReferenceImage(
      bytes: base64Decode(json['data'] as String),
      pixelSize: Size(size[0].toDouble(), size[1].toDouble()),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.5,
      visible: json['visible'] as bool? ?? true,
      onTop: json['onTop'] as bool? ?? false,
      fit: ReferenceFit.values.asNameMap()[json['fit']] ?? ReferenceFit.width,
    );
  }
}
