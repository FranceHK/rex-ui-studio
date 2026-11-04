import 'package:flutter/widgets.dart';

/// Watengenezaji wanaoungwa mkono na katalogi ya simu.
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

  /// Chanzo rasmi cha msingi kilichotumika kuthibitisha specs.
  final String primarySource;
}

/// Kipimo cha ukubwa wa kimantiki: points (iOS) au dp (Android).
enum LogicalUnit {
  pt('pt'),
  dp('dp');

  const LogicalUnit(this.label);
  final String label;
}

/// Kiwango cha uthibitisho wa rekodi ya kifaa.
enum VerificationStatus {
  /// Jina, resolution, ukubwa wa skrini na frame ya kimantiki
  /// vimethibitishwa kwenye vyanzo rasmi.
  verified('Imethibitishwa'),

  /// Specs za skrini zimethibitishwa, lakini angalau thamani moja
  /// (mara nyingi ukubwa wa kimantiki wa Android) bado ni makisio.
  partial('Sehemu imethibitishwa'),

  /// Thamani zimetoka kwenye jedwali la marejeo tu; bado hazijalinganishwa
  /// na ukurasa rasmi wa mtengenezaji.
  unverified('Haijathibitishwa');

  const VerificationStatus(this.label);
  final String label;
}

/// Nafasi ya skrini kwenye kifaa.
enum DisplayRole {
  main('Skrini kuu'),
  inner('Ndani · imefunguliwa'),
  outer('Nje · imekunjwa'),
  cover('Cover · imekunjwa');

  const DisplayRole(this.label);
  final String label;

  /// Skrini inayoonekana kifaa kikiwa kimekunjwa.
  bool get folded => this == outer || this == cover;
}

/// Sehemu za skrini zisizotumika (k.m. kamera kwenye cover ya Z Flip).
/// [rect] ni sehemu (0..1) ya skrini ikiwa wima.
class DisplayCutout {
  const DisplayCutout(this.rect, {this.circle = false});
  final Rect rect;
  final bool circle;
}

/// Skrini moja ya kifaa. Kifaa kinachokunjika kina skrini mbili.
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

  /// Resolution halisi (px) ikiwa wima.
  final Size physical;

  /// Ukubwa wa skrini (inchi, kipenyo).
  final double? diagonal;

  /// Pixel kwa inchi halisi. SI density ya Android.
  final double? ppi;

  /// Kiwango cha kusasisha, k.m. "1–120 Hz". null = haijulikani.
  final String? refresh;

  /// Aina ya skrini, k.m. "Super Retina XDR OLED".
  final String? type;

  /// Frame ya kimantiki iliyothibitishwa (pt kwa iOS, dp kwa Android).
  final Size? logical;

  /// Frame ya kazi wakati [logical] haijathibitishwa. Inaonyeshwa kama
  /// makisio na mtumiaji anaweza kuibadilisha.
  final Size? estimatedLogical;

  /// Scale ya iOS (@2x/@3x) au density ya Android ÷ 160.
  final double? scale;

  /// Density rasmi ya Android (dpi bucket ya profile ya SDK).
  final int? densityDpi;

  /// Mahali ukubwa wa kimantiki ulipotoka.
  final String? logicalSource;

  /// Mviringo wa kona za skrini kwa pt/dp.
  final double? cornerRadius;

  /// Safe area ikiwa wima. Kama [safeAreaVerified] ni false, ni mwongozo
  /// wa makisio tu.
  final EdgeInsets? safeArea;
  final bool safeAreaVerified;

  final List<DisplayCutout> cutouts;

  /// Majina ya sehemu ambazo bado hazijathibitishwa
  /// (k.m. 'refresh', 'type', 'diagonal', 'physical', 'cutouts').
  final Set<String> unverified;

  bool get logicalVerified => logical != null;

  /// Ukubwa wa artboard: iliyothibitishwa kwanza, vinginevyo makisio.
  Size get artboard => logical ?? estimatedLogical!;

  bool isVerified(String field) => !unverified.contains(field);
}

/// Rekodi ya simu moja kwenye katalogi.
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

  /// Id ya DeviceFrame kwa skrini fulani ya kifaa hiki.
  String frameId(DisplayRole role) => foldable ? '$id-${role.name}' : id;

  /// Jina la artboard kwa skrini fulani.
  String frameName(DisplayRole role) {
    if (!foldable) return model;
    return switch (role) {
      DisplayRole.inner => '$model (ndani)',
      DisplayRole.outer => '$model (nje)',
      DisplayRole.cover => '$model (cover)',
      DisplayRole.main => model,
    };
  }

  /// Maandishi yote yanayotafutika.
  String get searchText =>
      '${manufacturer.label} ${manufacturer.line} $family $model $releaseYear '
      '${foldable ? 'fold foldable inakunjika' : ''}';
}
