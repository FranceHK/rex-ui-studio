import 'package:amazing_icons/broken.dart';
import 'package:flutter/widgets.dart';

import 'icon_catalog.dart';

/// The amazing_icons styles the user can choose from.
enum IconStyle {
  broken('Broken', 'AmazingIconBroken'),
  outlined('Outlined', 'AmazingIconOutlined'),
  filled('Filled', 'AmazingIconFilled'),
  bulk('Bulk', 'AmazingIconBulk'),
  twotone('TwoTone', 'AmazingIconTwotone'),
  payment('Payment', 'AmazingIconPayment');

  const IconStyle(this.label, this.className);

  final String label;
  final String className;

  Iterable<String> get names => switch (this) {
    broken => brokenIcons.keys,
    outlined => outlinedIcons.keys,
    filled => filledIcons.keys,
    bulk => bulkIcons.keys,
    twotone => twotoneIcons.keys,
    payment => paymentIcons.keys,
  };

  bool has(String name) => switch (this) {
    broken => brokenIcons.containsKey(name),
    outlined => outlinedIcons.containsKey(name),
    filled => filledIcons.containsKey(name),
    bulk => bulkIcons.containsKey(name),
    twotone => twotoneIcons.containsKey(name),
    payment => paymentIcons.containsKey(name),
  };

  /// Payment icons keep their own original colors.
  bool get colorable => this != payment;

  /// The file to import in the generated code.
  String get importPath => 'package:amazing_icons/$name.dart';

  Widget build(String icon, {required double size, required Color color}) {
    final missing = Icon(AmazingIconBroken.danger, size: size, color: color);
    return switch (this) {
      broken => _font(brokenIcons[icon], size, color) ?? missing,
      outlined => _font(outlinedIcons[icon], size, color) ?? missing,
      filled => _font(filledIcons[icon], size, color) ?? missing,
      bulk =>
        bulkIcons[icon]?.call(size: size, color: color, opacity: 0.4) ??
            missing,
      twotone =>
        twotoneIcons[icon]?.call(size: size, color: color, opacity: 0.4) ??
            missing,
      payment => paymentIcons[icon]?.call(size: size) ?? missing,
    };
  }

  static Widget? _font(IconData? data, double size, Color color) =>
      data == null ? null : Icon(data, size: size, color: color);

  /// Dart code that draws this icon.
  String code(String icon, {required String size, required String color}) {
    return switch (this) {
      broken ||
      outlined ||
      filled => 'Icon($className.$icon, size: $size, color: $color)',
      bulk || twotone => '$className.$icon(size: $size, color: $color)',
      payment => '$className.$icon(size: $size)',
    };
  }
}

/// Matches a name against a search: "arrow left" finds "arrowLeft".
bool iconMatches(String name, String query) {
  final q = query.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  return q.isEmpty || name.toLowerCase().contains(q);
}
