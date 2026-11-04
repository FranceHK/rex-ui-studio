import 'package:flutter/widgets.dart';

/// Manufacturers covered by the phone catalog.
enum Manufacturer {
  apple(
    'Apple',
    'iPhone',
    LogicalUnit.pt,
    'https://www.apple.com/iphone/compare/',
  ),
  samsung('Samsung', 'Galaxy', LogicalUnit.dp, 'https://www.samsung.com/'),
  google(
    'Google',
    'Pixel',
    LogicalUnit.dp,
    'https://support.google.com/pixelphone/answer/7158570',
  );

  const Manufacturer(this.label, this.line, this.unit, this.primarySource);
  final String label;
  final String line;
  final LogicalUnit unit;

  /// The main official source used to verify the specs.
  final String primarySource;
}

/// Unit of the logical size: points (iOS) or dp (Android).
enum LogicalUnit {
  pt('pt'),
  dp('dp');

  const LogicalUnit(this.label);
  final String label;
}

/// How well a device record is verified.
enum VerificationStatus {
  /// Name, resolution, screen size and logical frame are
  /// verified against official sources.
  verified('Verified'),

  /// Screen specs are verified, but at least one value
  /// (usually the Android logical size) is still an estimate.
  partial('Partly verified'),

  /// Values come from a reference table only; not yet compared
  /// with the manufacturer's official page.
  unverified('Not verified');

  const VerificationStatus(this.label);
  final String label;
}

/// Where the screen sits on the device.
enum DisplayRole {
  main('Main screen'),
  inner('Inner · unfolded'),
  outer('Outer · folded'),
  cover('Cover · folded');

  const DisplayRole(this.label);
  final String label;

  /// The screen visible when the device is folded.
  bool get folded => this == outer || this == cover;
}

/// Unusable parts of the screen (e.g. the cameras on the Z Flip cover).
/// [rect] is a fraction (0..1) of the screen in portrait.
class DisplayCutout {
  const DisplayCutout(this.rect, {this.circle = false});
  final Rect rect;
  final bool circle;
}

/// One screen of a device. A foldable has two screens.
class DeviceDisplay {
  const DeviceDisplay({
    this.role = DisplayRole.main,
    required this.physical,
    this.diagonal,
    this.ppi,
    this.refresh,
    this.type,
    this.logical,
    this.estimatedLogical,
    this.scale,
    this.densityDpi,
    this.logicalSource,
    this.cornerRadius,
    this.safeArea,
    this.safeAreaVerified = false,
    this.cutouts = const [],
    this.unverified = const {},
  }) : assert(logical != null || estimatedLogical != null);

  final DisplayRole role;

  /// Physical resolution (px) in portrait.
  final Size physical;

  /// Screen size (inches, diagonal).
  final double? diagonal;

  /// Physical pixels per inch. NOT the Android density.
  final double? ppi;

  /// Refresh rate, e.g. "1–120 Hz". null = unknown.
  final String? refresh;

  /// Panel type, e.g. "Super Retina XDR OLED".
  final String? type;

  /// The verified logical frame (pt on iOS, dp on Android).
  final Size? logical;

  /// Working frame when [logical] isn't verified. Shown as an
  /// estimate and the user can change it.
  final Size? estimatedLogical;

  /// iOS scale (@2x/@3x) or Android density ÷ 160.
  final double? scale;

  /// Official Android density (the SDK profile's dpi bucket).
  final int? densityDpi;

  /// Where the logical size came from.
  final String? logicalSource;

  /// Screen corner radius in pt/dp.
  final double? cornerRadius;

  /// Safe area in portrait. When [safeAreaVerified] is false it's only
  /// an estimated guide.
  final EdgeInsets? safeArea;
  final bool safeAreaVerified;

  final List<DisplayCutout> cutouts;

  /// Names of fields that aren't verified yet
  /// (e.g. 'refresh', 'type', 'diagonal', 'physical', 'cutouts').
  final Set<String> unverified;

  bool get logicalVerified => logical != null;

  /// Artboard size: the verified one first, otherwise the estimate.
  Size get artboard => logical ?? estimatedLogical!;

  bool isVerified(String field) => !unverified.contains(field);
}

/// One phone record in the catalog.
class DevicePreset {
  const DevicePreset({
    required this.id,
    required this.manufacturer,
    required this.family,
    required this.model,
    required this.releaseYear,
    required this.displays,
    required this.sourceUrl,
    required this.status,
    this.notes = const [],
  });

  final String id;
  final Manufacturer manufacturer;
  final String family;
  final String model;
  final int releaseYear;
  final List<DeviceDisplay> displays;
  final String sourceUrl;
  final VerificationStatus status;
  final List<String> notes;

  LogicalUnit get logicalUnit => manufacturer.unit;
  bool get foldable => displays.length > 1;

  DeviceDisplay get primary => displays.first;

  DeviceDisplay display(DisplayRole role) =>
      displays.firstWhere((d) => d.role == role, orElse: () => primary);

  /// DeviceFrame id for a given screen of this device.
  String frameId(DisplayRole role) => foldable ? '$id-${role.name}' : id;

  /// Artboard name for a given screen.
  String frameName(DisplayRole role) {
    if (!foldable) return model;
    return switch (role) {
      DisplayRole.inner => '$model (inner)',
      DisplayRole.outer => '$model (outer)',
      DisplayRole.cover => '$model (cover)',
      DisplayRole.main => model,
    };
  }

  /// All searchable text.
  String get searchText =>
      '${manufacturer.label} ${manufacturer.line} $family $model $releaseYear '
      '${foldable ? 'fold foldable folding' : ''}';
}
