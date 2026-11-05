import 'dart:math';
import 'dart:ui';

import '../models/ui_element.dart';

// Helpers shared by the SwiftUI, Compose, HTML and React generators:
// numbers, colors, shapes and icon names.

/// 12.0 → "12", 12.5 → "12.5".
String fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// A 0–1 fraction with at most 3 decimals: 0.33333 → "0.333".
String fmt3(double v) => ((v * 1000).round() / 1000).toString();

/// Color channels as 0–1 values (r, g, b, a).
(double, double, double, double) rgba(Color c) => (c.r, c.g, c.b, c.a);

/// "#RRGGBB", or "#RRGGBBAA" when the color is translucent.
String hexColor(Color c) {
  String two(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  final rgb = '#${two(c.r)}${two(c.g)}${two(c.b)}'.toUpperCase();
  return c.a >= 1 ? rgb : '$rgb${two(c.a).toUpperCase()}';
}

/// lowerCamelCase: "Login screen" → "loginScreen".
String camelName(String name) {
  final words = name
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'design';
  final first = words.first.toLowerCase();
  return first +
      words.skip(1).map((w) => w[0].toUpperCase() + w.substring(1)).join();
}

/// Corner points of a polygon or star shape in a 0–1 square, stretched to
/// fill the bounds like Flutter's `squash: 1`. null for rectangle/ellipse.
List<Offset>? shapePoints(ElementShape shape) {
  final raw = switch (shape) {
    ElementShape.rectangle || ElementShape.ellipse => null,
    ElementShape.triangle => _polygon(3),
    ElementShape.diamond => _polygon(4),
    ElementShape.pentagon => _polygon(5),
    ElementShape.hexagon => _polygon(6),
    ElementShape.star => _star(5, 0.45),
  };
  if (raw == null) return null;
  final xs = raw.map((p) => p.dx), ys = raw.map((p) => p.dy);
  final minX = xs.reduce(min), maxX = xs.reduce(max);
  final minY = ys.reduce(min), maxY = ys.reduce(max);
  double r(double v) => (v * 1000).roundToDouble() / 1000;
  return [
    for (final p in raw)
      Offset(
        r((p.dx - minX) / (maxX - minX)),
        r((p.dy - minY) / (maxY - minY)),
      ),
  ];
}

/// A regular polygon with a vertex at the top.
List<Offset> _polygon(int sides) => [
  for (var i = 0; i < sides; i++)
    Offset(sin(2 * pi * i / sides), -cos(2 * pi * i / sides)),
];

List<Offset> _star(int points, double inner) => [
  for (var i = 0; i < points * 2; i++)
    Offset(
      sin(pi * i / points) * (i.isEven ? 1 : inner),
      -cos(pi * i / points) * (i.isEven ? 1 : inner),
    ),
];

/// "arrowLeft" → "arrow_left" (Material Symbols names).
String snakeIcon(String name) => name
    .replaceAllMapped(RegExp(r'([a-z])([A-Z0-9])'), (m) => '${m[1]}_${m[2]}')
    .replaceAll(RegExp(r'_?\d+$'), '')
    .toLowerCase();

/// Closest SF Symbol for an amazing_icons name (SwiftUI).
String sfSymbol(String name) {
  final n = name.toLowerCase();
  for (final (key, symbol) in _sfSymbols) {
    if (n.contains(key)) return symbol;
  }
  return 'star';
}

const _sfSymbols = [
  ('home', 'house'),
  ('search', 'magnifyingglass'),
  ('user', 'person'),
  ('profile', 'person'),
  ('menu', 'line.3.horizontal'),
  ('heart', 'heart'),
  ('setting', 'gearshape'),
  ('notification', 'bell'),
  ('arrowleft', 'arrow.left'),
  ('arrowright', 'arrow.right'),
  ('add', 'plus'),
  ('close', 'xmark'),
  ('wallet', 'wallet.pass'),
  ('message', 'message'),
  ('call', 'phone'),
  ('camera', 'camera'),
  ('lock', 'lock'),
  ('calendar', 'calendar'),
  ('location', 'mappin'),
  ('cart', 'cart'),
  ('shop', 'bag'),
  ('mail', 'envelope'),
  ('star', 'star'),
];

/// Closest Compose Material icon (Icons.Default.*) for an icon name.
String composeIcon(String name) {
  final n = name.toLowerCase();
  for (final (key, icon) in _composeIcons) {
    if (n.contains(key)) return icon;
  }
  return 'Star';
}

const _composeIcons = [
  ('home', 'Home'),
  ('search', 'Search'),
  ('user', 'Person'),
  ('profile', 'Person'),
  ('menu', 'Menu'),
  ('heart', 'Favorite'),
  ('setting', 'Settings'),
  ('notification', 'Notifications'),
  ('arrowleft', 'ArrowBack'),
  ('arrowright', 'ArrowForward'),
  ('add', 'Add'),
  ('close', 'Close'),
  ('call', 'Call'),
  ('lock', 'Lock'),
  ('mail', 'Email'),
  ('cart', 'ShoppingCart'),
  ('location', 'LocationOn'),
  ('calendar', 'DateRange'),
  ('star', 'Star'),
];

/// Font families used by the visible text elements, sorted.
List<String> usedFonts(DesignPage page) => {
  for (final e in page.visibleElements)
    if (e.type.hasText && e.fontFamily != null) e.fontFamily!,
}.toList()..sort();

/// Google Fonts stylesheet that loads [fonts] with every weight.
String googleFontsUrl(List<String> fonts) =>
    'https://fonts.googleapis.com/css2?'
    '${fonts.map((f) => 'family=${f.replaceAll(' ', '+')}:wght@100..900').join('&')}'
    '&display=swap';
