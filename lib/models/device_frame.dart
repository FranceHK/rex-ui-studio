import 'package:flutter/widgets.dart';

import '../devices/device_preset.dart';
import '../devices/phone_catalog.dart';
import '../icons/app_icons.dart';

enum DeviceBrand {
  apple('Apple'),
  samsung('Samsung'),
  google('Google'),
  generic('Other');

  const DeviceBrand(this.label);
  final String label;
}

enum DeviceKind {
  phone('Phones', AppIcons.phone),
  foldable('Foldables', AppIcons.foldable),
  tablet('Tablets', AppIcons.tablet),
  computer('Computers', AppIcons.computer),
  watch('Watches', AppIcons.watch);

  const DeviceKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// The device a screen is designed for. [size] is the logical size
/// (points on Apple, dp on Android) in portrait.
class DeviceFrame {
  const DeviceFrame(
    this.id,
    this.brand,
    this.kind,
    this.name,
    this.size, {
    this.radius,
    this.round = false,
    this.preset,
    this.display,
  });

  final String id;
  final DeviceBrand brand;
  final DeviceKind kind;
  final String name;
  final Size size;
  final double? radius;

  /// Watches with a round screen (Galaxy Watch, Pixel Watch).
  final bool round;

  /// The full catalog record for phones (null for tablets, computers, watches).
  final DevicePreset? preset;
  final DeviceDisplay? display;

  IconData get icon => kind.icon;

  /// Physical resolution (px) in portrait, if known.
  Size? get physical => display?.physical;

  /// Corner radius of the screen.
  double cornerRadius(Size actual) => round
      ? actual.shortestSide / 2
      : radius ??
            switch (kind) {
              DeviceKind.phone => 44,
              DeviceKind.foldable => 24,
              DeviceKind.tablet => 18,
              DeviceKind.computer => 6,
              DeviceKind.watch => 40,
            };
}

const customDeviceId = 'custom';

const _apple = DeviceBrand.apple;
const _samsung = DeviceBrand.samsung;
const _google = DeviceBrand.google;
const _generic = DeviceBrand.generic;
const _tablet = DeviceKind.tablet;
const _pc = DeviceKind.computer;
const _watch = DeviceKind.watch;

DeviceBrand brandOf(Manufacturer m) => switch (m) {
  Manufacturer.apple => DeviceBrand.apple,
  Manufacturer.samsung => DeviceBrand.samsung,
  Manufacturer.google => DeviceBrand.google,
};

/// DeviceFrame for one phone screen in the catalog.
DeviceFrame frameFor(DevicePreset preset, DeviceDisplay display) => DeviceFrame(
  preset.frameId(display.role),
  brandOf(preset.manufacturer),
  preset.foldable ? DeviceKind.foldable : DeviceKind.phone,
  preset.frameName(display.role),
  display.artboard,
  radius:
      display.cornerRadius ??
      (preset.manufacturer == Manufacturer.apple ? null : 28),
  preset: preset,
  display: display,
);

/// All catalog phones (each screen of a foldable is its own frame).
final List<DeviceFrame> phoneFrames = [
  for (final p in phoneCatalog)
    for (final d in p.displays) frameFor(p, d),
];

/// The other screen of a foldable (folded ↔ unfolded).
DeviceFrame? foldPartner(DeviceFrame device) {
  final preset = device.preset;
  if (preset == null || !preset.foldable) return null;
  final other = preset.displays.firstWhere((d) => d != device.display);
  return deviceById(preset.frameId(other.role));
}

const _otherDevices = <DeviceFrame>[
  // ---------- Apple: iPad ----------
  DeviceFrame('ipad-pro-13', _apple, _tablet, 'iPad Pro 13"', Size(1032, 1376)),
  DeviceFrame('ipad-pro-11', _apple, _tablet, 'iPad Pro 11"', Size(834, 1210)),
  DeviceFrame('ipad-air-13', _apple, _tablet, 'iPad Air 13"', Size(1024, 1366)),
  DeviceFrame('ipad-air-11', _apple, _tablet, 'iPad Air 11"', Size(820, 1180)),
  DeviceFrame('ipad', _apple, _tablet, 'iPad (A16)', Size(820, 1180)),
  DeviceFrame('ipad-mini', _apple, _tablet, 'iPad mini', Size(744, 1133)),
  // ---------- Apple: Mac ----------
  DeviceFrame(
    'macbook-air-13',
    _apple,
    _pc,
    'MacBook Air 13"',
    Size(1470, 956),
  ),
  DeviceFrame(
    'macbook-air-15',
    _apple,
    _pc,
    'MacBook Air 15"',
    Size(1710, 1112),
  ),
  DeviceFrame(
    'macbook-pro-14',
    _apple,
    _pc,
    'MacBook Pro 14"',
    Size(1512, 982),
  ),
  DeviceFrame(
    'macbook-pro-16',
    _apple,
    _pc,
    'MacBook Pro 16"',
    Size(1728, 1117),
  ),
  DeviceFrame('imac-24', _apple, _pc, 'iMac 24"', Size(2240, 1260)),
  DeviceFrame(
    'studio-display',
    _apple,
    _pc,
    'Studio Display 27"',
    Size(2560, 1440),
  ),
  // ---------- Apple Watch: Ultra, Series, SE ----------
  DeviceFrame(
    'watch-ultra-3',
    _apple,
    _watch,
    'Apple Watch Ultra 3 (49mm)',
    Size(211, 257),
    radius: 52,
  ),
  DeviceFrame(
    'watch-ultra-2',
    _apple,
    _watch,
    'Apple Watch Ultra 2 (49mm)',
    Size(205, 251),
    radius: 50,
  ),
  DeviceFrame(
    'watch-s11-46',
    _apple,
    _watch,
    'Apple Watch Series 11 / 10 (46mm)',
    Size(208, 248),
    radius: 50,
  ),
  DeviceFrame(
    'watch-s11-42',
    _apple,
    _watch,
    'Apple Watch Series 11 / 10 (42mm)',
    Size(187, 223),
    radius: 45,
  ),
  DeviceFrame(
    'watch-s9-45',
    _apple,
    _watch,
    'Apple Watch Series 9 / 8 / 7 (45mm)',
    Size(198, 242),
    radius: 46,
  ),
  DeviceFrame(
    'watch-s9-41',
    _apple,
    _watch,
    'Apple Watch Series 9 / 8 / 7 (41mm)',
    Size(176, 215),
    radius: 41,
  ),
  DeviceFrame(
    'watch-se-44',
    _apple,
    _watch,
    'Apple Watch SE (44mm)',
    Size(184, 224),
    radius: 38,
  ),
  DeviceFrame(
    'watch-se-40',
    _apple,
    _watch,
    'Apple Watch SE (40mm)',
    Size(162, 197),
    radius: 34,
  ),

  // ---------- Samsung: Galaxy Tab ----------
  DeviceFrame(
    'galaxy-tab-s10-ultra',
    _samsung,
    _tablet,
    'Galaxy Tab S10 / S9 Ultra',
    Size(924, 1480),
  ),
  DeviceFrame(
    'galaxy-tab-s10-plus',
    _samsung,
    _tablet,
    'Galaxy Tab S10+ / S9+',
    Size(876, 1400),
  ),
  DeviceFrame(
    'galaxy-tab-s9',
    _samsung,
    _tablet,
    'Galaxy Tab S9',
    Size(800, 1280),
  ),
  DeviceFrame(
    'galaxy-tab-s9-fe',
    _samsung,
    _tablet,
    'Galaxy Tab S9 FE',
    Size(720, 1152),
  ),
  DeviceFrame(
    'galaxy-tab-a9-plus',
    _samsung,
    _tablet,
    'Galaxy Tab A9+',
    Size(800, 1280),
  ),
  // ---------- Samsung: Galaxy Watch (round) ----------
  DeviceFrame(
    'galaxy-watch-ultra',
    _samsung,
    _watch,
    'Galaxy Watch Ultra (47mm)',
    Size(226, 226),
    round: true,
  ),
  DeviceFrame(
    'galaxy-watch-44',
    _samsung,
    _watch,
    'Galaxy Watch 8 / 7 (44mm)',
    Size(226, 226),
    round: true,
  ),
  DeviceFrame(
    'galaxy-watch-40',
    _samsung,
    _watch,
    'Galaxy Watch 8 / 7 (40mm)',
    Size(203, 203),
    round: true,
  ),
  DeviceFrame(
    'galaxy-watch-classic-47',
    _samsung,
    _watch,
    'Galaxy Watch Classic (47mm)',
    Size(226, 226),
    round: true,
  ),
  DeviceFrame(
    'galaxy-watch-classic-43',
    _samsung,
    _watch,
    'Galaxy Watch Classic (43mm)',
    Size(203, 203),
    round: true,
  ),

  // ---------- Google: Tablet ----------
  DeviceFrame(
    'pixel-tablet',
    _google,
    _tablet,
    'Pixel Tablet',
    Size(800, 1280),
  ),
  // ---------- Google: Pixel Watch (round) ----------
  DeviceFrame(
    'pixel-watch-45',
    _google,
    _watch,
    'Pixel Watch 4 / 3 (45mm)',
    Size(228, 228),
    round: true,
  ),
  DeviceFrame(
    'pixel-watch-41',
    _google,
    _watch,
    'Pixel Watch 4 / 3 (41mm)',
    Size(204, 204),
    round: true,
  ),
  DeviceFrame(
    'pixel-watch-2',
    _google,
    _watch,
    'Pixel Watch 2',
    Size(192, 192),
    round: true,
  ),

  // ---------- Other ----------
  DeviceFrame(
    'desktop-fhd',
    _generic,
    _pc,
    'Desktop Full HD',
    Size(1920, 1080),
  ),
  DeviceFrame('desktop', _generic, _pc, 'Desktop', Size(1440, 900)),
  DeviceFrame('laptop-hd', _generic, _pc, 'Laptop HD', Size(1366, 768)),
  DeviceFrame(customDeviceId, _generic, _pc, 'Custom size', Size(375, 812)),
];

/// All devices: phones from the catalog, then tablets, computers and
/// watches. Apple sizes are official points; Android sizes are dp.
final List<DeviceFrame> devices = [...phoneFrames, ..._otherDevices];

final Map<String, DeviceFrame> _byId = {for (final d in devices) d.id: d};

DeviceFrame get defaultDevice => _byId['iphone-17-pro']!;

/// Devices from an older app version: old id → (new id, old size).
/// The old size is kept so the design doesn't move.
const legacyDevices = <String, (String, Size)>{
  'iphone-se': ('iphone-se-3', Size(375, 667)),
  'iphone-15': ('iphone-15', Size(393, 852)),
  'iphone-14': ('iphone-14', Size(390, 844)),
  'galaxy-s25-ultra': ('galaxy-s25-ultra', Size(412, 891)),
  'galaxy-s25-plus': ('galaxy-s25-plus', Size(384, 832)),
  'galaxy-s25': ('galaxy-s25', Size(360, 780)),
  'galaxy-s24-ultra': ('galaxy-s24-ultra', Size(384, 824)),
  'galaxy-s24-plus': ('galaxy-s24-plus', Size(384, 832)),
  'galaxy-s24': ('galaxy-s24', Size(360, 780)),
  'galaxy-s23-ultra': ('galaxy-s23-ultra', Size(384, 824)),
  'galaxy-s23': ('galaxy-s23', Size(360, 780)),
  'galaxy-a55': ('galaxy-a55', Size(412, 891)),
  'galaxy-z-fold-cover': ('galaxy-z-fold7-outer', Size(344, 882)),
  'galaxy-z-fold-main': ('galaxy-z-fold7-inner', Size(690, 829)),
  'galaxy-z-flip': ('galaxy-z-flip7-inner', Size(412, 1006)),
  'pixel-10-pro-xl': ('pixel-10-pro-xl', Size(412, 915)),
  'pixel-10-pro': ('pixel-10-pro', Size(410, 914)),
  'pixel-10': ('pixel-10', Size(412, 923)),
  'pixel-9a': ('pixel-9a', Size(412, 915)),
  'pixel-8-pro': ('pixel-8-pro', Size(412, 892)),
  'pixel-8': ('pixel-8', Size(412, 915)),
  'pixel-7': ('pixel-7', Size(412, 915)),
  'pixel-fold-cover': ('pixel-9-pro-fold-outer', Size(412, 869)),
  'pixel-fold-main': ('pixel-9-pro-fold-inner', Size(851, 882)),
  // Old names that merged two models
  'iPhone 15 / 15 Plus': ('iphone-15', Size(393, 852)),
  'iPhone 14 / 13': ('iphone-14', Size(390, 844)),
  'iPhone SE': ('iphone-se-3', Size(375, 667)),
  'Galaxy A55 / A35': ('galaxy-a55', Size(412, 891)),
  'Pixel 10 / 9': ('pixel-10', Size(412, 923)),
  'Pixel 10 Pro / 9 Pro': ('pixel-10-pro', Size(410, 914)),
  'Pixel 10 Pro XL / 9 Pro XL': ('pixel-10-pro-xl', Size(412, 915)),
};

/// Find a device by id (or by name, for projects from older versions).
DeviceFrame deviceById(String? id) {
  if (id == null) return defaultDevice;
  if (_byId[id] case final d?) return d;
  if (legacyDevices[id] case (final newId, _)) return _byId[newId]!;
  return devices.firstWhere((d) => d.name == id, orElse: () => defaultDevice);
}
