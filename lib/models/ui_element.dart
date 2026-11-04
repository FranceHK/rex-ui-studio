import 'package:flutter/material.dart';

import '../canvas/layout.dart';
import '../icons/app_icons.dart';
import '../icons/icon_style.dart';
import 'device_frame.dart';

const brandColor = Color(0xFF4F46E5);
const inkColor = Color(0xFF101828);
const mutedColor = Color(0xFF667085);

enum ElementType {
  text('Text', AppIcons.text, Size(220, 32)),
  button('Button', AppIcons.button, Size(160, 48)),
  input('Text field', AppIcons.input, Size(280, 52)),
  image('Image', AppIcons.image, Size(240, 160)),
  container('Box', AppIcons.container, Size(200, 120)),
  appBar('App bar', AppIcons.appBar, Size(393, 64)),
  navBar('Bottom nav', AppIcons.navBar, Size(393, 72)),
  iconItem('Icon', AppIcons.star, Size(40, 40)),
  avatar('Avatar', AppIcons.avatar, Size(56, 56)),
  toggle('Switch', AppIcons.toggle, Size(52, 32)),
  divider('Divider', AppIcons.divider, Size(280, 12));

  const ElementType(this.label, this.icon, this.defaultSize);

  final String label;
  final IconData icon;
  final Size defaultSize;

  /// Elements that span the full width of the screen.
  bool get fullWidth => this == appBar || this == navBar;

  bool get hasText =>
      this == text ||
      this == button ||
      this == input ||
      this == appBar ||
      this == avatar;

  bool get hasRadius =>
      this == button || this == input || this == image || this == container;

  /// Elements that can take a different shape (circle, star, …).
  bool get hasShape => this == container || this == image;
}

/// Shape of a box or image. The corner radius ([UiElement.radius]) rounds
/// the rectangle's corners and softens polygon and star points.
enum ElementShape {
  rectangle('Rectangle'),
  ellipse('Ellipse'),
  triangle('Triangle'),
  diamond('Diamond'),
  pentagon('Pentagon'),
  hexagon('Hexagon'),
  star('Star');

  const ElementShape(this.label);
  final String label;

  /// How much to round the points (0–1), from the radius and size.
  static double _rounding(double radius, Size size) {
    final half = size.shortestSide / 2;
    return half <= 0 ? 0 : (radius / half).clamp(0.0, 1.0);
  }

  /// A [ShapeBorder] that fills the element's whole rectangle.
  ShapeBorder border(double radius, Size size) {
    final r = _rounding(radius, size);
    return switch (this) {
      rectangle => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      ellipse => const OvalBorder(),
      triangle => StarBorder.polygon(sides: 3, squash: 1, pointRounding: r),
      diamond => StarBorder.polygon(sides: 4, squash: 1, pointRounding: r),
      pentagon => StarBorder.polygon(sides: 5, squash: 1, pointRounding: r),
      hexagon => StarBorder.polygon(sides: 6, squash: 1, pointRounding: r),
      star => StarBorder(
        points: 5,
        innerRadiusRatio: 0.45,
        squash: 1,
        pointRounding: r,
      ),
    };
  }

  /// Dart code for [border] (for "Get code").
  String code(double radius, Size size) {
    String n(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
    final r = n(_rounding(radius, size));
    return switch (this) {
      rectangle =>
        'RoundedRectangleBorder(borderRadius: BorderRadius.circular(${n(radius)}))',
      ellipse => 'const OvalBorder()',
      triangle => 'StarBorder.polygon(sides: 3, squash: 1, pointRounding: $r)',
      diamond => 'StarBorder.polygon(sides: 4, squash: 1, pointRounding: $r)',
      pentagon => 'StarBorder.polygon(sides: 5, squash: 1, pointRounding: $r)',
      hexagon => 'StarBorder.polygon(sides: 6, squash: 1, pointRounding: $r)',
      star =>
        'StarBorder(points: 5, innerRadiusRatio: 0.45, squash: 1, pointRounding: $r)',
    };
  }
}

/// Vertical text alignment inside its box.
enum VAlign {
  top(-1),
  middle(0),
  bottom(1);

  const VAlign(this.y);
  final double y;
}

/// A new element dragged or tapped in from the left panel.
class NewElement {
  const NewElement(this.type, {this.text, this.iconStyle, this.shape});

  final ElementType type;
  final String? text;
  final IconStyle? iconStyle;
  final ElementShape? shape;
}

class UiElement {
  const UiElement({
    required this.id,
    required this.type,
    required this.rect,
    this.text = '',
    this.color = Colors.transparent,
    this.textColor = inkColor,
    this.fontSize = 16,
    this.radius = 0,
    this.bold = false,
    this.locked = false,
    this.iconStyle = IconStyle.broken,
    this.textAlign,
    this.vAlign = VAlign.middle,
    this.link,
    this.shape = ElementShape.rectangle,
  });

  /// A new element with the default style for its type.
  factory UiElement.create(ElementType type, String id, Rect rect) {
    return switch (type) {
      ElementType.text => UiElement(
        id: id,
        type: type,
        rect: rect,
        text: 'Heading',
        fontSize: 22,
        bold: true,
      ),
      ElementType.button => UiElement(
        id: id,
        type: type,
        rect: rect,
        text: 'Continue',
        color: brandColor,
        textColor: Colors.white,
        radius: 12,
        bold: true,
      ),
      ElementType.input => UiElement(
        id: id,
        type: type,
        rect: rect,
        text: 'Email',
        color: const Color(0xFFD0D5DD),
        textColor: mutedColor,
        fontSize: 15,
        radius: 12,
      ),
      ElementType.image => UiElement(
        id: id,
        type: type,
        rect: rect,
        color: const Color(0xFFE4E7EC),
        textColor: const Color(0xFF98A2B3),
        radius: 16,
      ),
      ElementType.container => UiElement(
        id: id,
        type: type,
        rect: rect,
        color: const Color(0xFFF2F4F7),
        radius: 16,
      ),
      ElementType.appBar => UiElement(
        id: id,
        type: type,
        rect: rect,
        text: 'Home',
        color: Colors.white,
        fontSize: 18,
        bold: true,
      ),
      ElementType.navBar => UiElement(
        id: id,
        type: type,
        rect: rect,
        color: Colors.white,
        textColor: brandColor,
      ),
      ElementType.iconItem => UiElement(
        id: id,
        type: type,
        rect: rect,
        text: 'star',
        color: brandColor,
      ),
      ElementType.avatar => UiElement(
        id: id,
        type: type,
        rect: rect,
        text: 'RA',
        color: const Color(0xFFE0E7FF),
        textColor: brandColor,
        fontSize: 18,
        bold: true,
      ),
      ElementType.toggle => UiElement(
        id: id,
        type: type,
        rect: rect,
        color: brandColor,
      ),
      ElementType.divider => UiElement(
        id: id,
        type: type,
        rect: rect,
        color: const Color(0xFFE4E7EC),
      ),
    };
  }

  final String id;
  final ElementType type;
  final Rect rect;

  /// The text; for [ElementType.iconItem] it's the icon name.
  final String text;
  final Color color;
  final Color textColor;
  final double fontSize;
  final double radius;
  final bool bold;

  /// A locked element can't be moved or resized.
  final bool locked;
  final IconStyle iconStyle;

  /// Text alignment INSIDE the box (not moving the element).
  /// null = the type's default (e.g. button → center).
  final TextAlign? textAlign;
  final VAlign vAlign;

  /// Prototype: tapping the element in "Run" goes to this screen (id).
  final String? link;

  /// Shape (for [ElementType.hasShape]).
  final ElementShape shape;

  ShapeBorder get shapeBorder => shape.border(radius, rect.size);

  TextAlign get effectiveTextAlign =>
      textAlign ??
      switch (type) {
        ElementType.button || ElementType.avatar => TextAlign.center,
        _ => TextAlign.left,
      };

  UiElement copyWith({
    String? id,
    Rect? rect,
    String? text,
    Color? color,
    Color? textColor,
    double? fontSize,
    double? radius,
    bool? bold,
    bool? locked,
    IconStyle? iconStyle,
    TextAlign? textAlign,
    VAlign? vAlign,
    String? link,
    bool clearLink = false,
    ElementShape? shape,
  }) {
    return UiElement(
      id: id ?? this.id,
      type: type,
      rect: rect ?? this.rect,
      text: text ?? this.text,
      color: color ?? this.color,
      textColor: textColor ?? this.textColor,
      fontSize: fontSize ?? this.fontSize,
      radius: radius ?? this.radius,
      bold: bold ?? this.bold,
      locked: locked ?? this.locked,
      iconStyle: iconStyle ?? this.iconStyle,
      textAlign: textAlign ?? this.textAlign,
      vAlign: vAlign ?? this.vAlign,
      link: clearLink ? null : link ?? this.link,
      shape: shape ?? this.shape,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'rect': [rect.left, rect.top, rect.width, rect.height],
    'text': text,
    'color': color.toARGB32(),
    'textColor': textColor.toARGB32(),
    'fontSize': fontSize,
    'radius': radius,
    'bold': bold,
    'locked': locked,
    'iconStyle': iconStyle.name,
    'textAlign': ?textAlign?.name,
    if (vAlign != VAlign.middle) 'vAlign': vAlign.name,
    'link': ?link,
    if (shape != ElementShape.rectangle) 'shape': shape.name,
  };

  factory UiElement.fromJson(Map<String, dynamic> json) {
    final r = [for (final v in json['rect'] as List) (v as num).toDouble()];
    final type = switch (json['type']) {
      'icon' => ElementType.iconItem,
      final String name => ElementType.values.byName(name),
      _ => throw const FormatException('Unknown element type'),
    };
    return UiElement(
      id: json['id'] as String,
      type: type,
      rect: Rect.fromLTWH(r[0], r[1], r[2], r[3]),
      text: json['text'] as String? ?? '',
      color: Color(json['color'] as int),
      textColor: Color(json['textColor'] as int),
      fontSize: (json['fontSize'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
      bold: json['bold'] as bool? ?? false,
      locked: json['locked'] as bool? ?? false,
      iconStyle:
          IconStyle.values.asNameMap()[json['iconStyle']] ?? IconStyle.broken,
      textAlign: TextAlign.values.asNameMap()[json['textAlign']],
      vAlign: VAlign.values.asNameMap()[json['vAlign']] ?? VAlign.middle,
      link: json['link'] as String?,
      shape:
          ElementShape.values.asNameMap()[json['shape']] ??
          ElementShape.rectangle,
    );
  }
}

/// One design screen (e.g. "Login" on an iPhone).
class DesignPage {
  const DesignPage({
    required this.id,
    required this.name,
    required this.device,
    this.landscape = false,
    this.customSize,
    this.showSafeArea = false,
    this.background = Colors.white,
    this.elements = const [],
    this.position,
    this.guides = const [],
    this.grid = const GridSettings(),
    this.rulerOrigin = Offset.zero,
  });

  final String id;
  final String name;
  final DeviceFrame device;

  /// The device is in landscape instead of portrait.
  final bool landscape;

  /// Artboard size changed by the user (in portrait). For the
  /// "Custom size" device it's its size; for other devices it's a
  /// "responsive resize" — the device (and its metadata) stays.
  final Size? customSize;

  /// Show the safe area guides on the canvas.
  final bool showSafeArea;
  final Color background;
  final List<UiElement> elements;

  /// Position of the artboard on the canvas (world). null = laid out automatically.
  final Offset? position;
  final List<Guide> guides;
  final GridSettings grid;

  /// Origin (0,0) of the rulers inside the artboard; Offset.zero = the
  /// top-left corner.
  final Offset rulerOrigin;

  /// Artboard size in portrait.
  Size get portraitSize => customSize ?? device.size;

  /// The real screen size, taking landscape and custom size into account.
  Size get size => landscape ? portraitSize.flipped : portraitSize;

  /// The artboard differs from the device size.
  bool get resized => customSize != null && customSize != device.size;

  /// Safe area for the current orientation (null if unknown).
  EdgeInsets? get safeArea {
    final s = device.display?.safeArea;
    if (s == null) return null;
    return landscape ? rotateSafeArea(s) : s;
  }

  DesignPage copyWith({
    String? name,
    DeviceFrame? device,
    bool? landscape,
    Size? customSize,
    bool clearCustomSize = false,
    bool? showSafeArea,
    Color? background,
    List<UiElement>? elements,
    Offset? position,
    List<Guide>? guides,
    GridSettings? grid,
    Offset? rulerOrigin,
  }) {
    return DesignPage(
      id: id,
      name: name ?? this.name,
      device: device ?? this.device,
      landscape: landscape ?? this.landscape,
      customSize: clearCustomSize ? null : customSize ?? this.customSize,
      showSafeArea: showSafeArea ?? this.showSafeArea,
      background: background ?? this.background,
      elements: elements ?? this.elements,
      position: position ?? this.position,
      guides: guides ?? this.guides,
      grid: grid ?? this.grid,
      rulerOrigin: rulerOrigin ?? this.rulerOrigin,
    );
  }

  /// The artboard rectangle on the canvas (world).
  Rect get worldRect => (position ?? Offset.zero) & size;

  Map<String, dynamic> toJson() => {
    'v': 2,
    'id': id,
    'name': name,
    'device': device.id,
    'landscape': landscape,
    if (customSize case final s?) 'customSize': [s.width, s.height],
    if (showSafeArea) 'safeArea': true,
    'background': background.toARGB32(),
    // Device metadata (for reference and export; never read back)
    if (device.display case final d?)
      'meta': {
        'physical': [d.physical.width, d.physical.height],
        'logical': [device.size.width, device.size.height],
        'logicalVerified': d.logicalVerified,
        'unit': device.preset!.logicalUnit.name,
        'scale': ?d.scale,
        'diagonal': ?d.diagonal,
        'display': d.role.name,
      },
    'elements': [for (final e in elements) e.toJson()],
    if (position case final p?) 'pos': [p.dx, p.dy],
    if (guides.isNotEmpty) 'guides': [for (final g in guides) g.toJson()],
    'grid': grid.toJson(),
    if (rulerOrigin != Offset.zero) 'origin': [rulerOrigin.dx, rulerOrigin.dy],
  };

  factory DesignPage.fromJson(Map<String, dynamic> json) {
    final custom = json['customSize'] as List?;
    final deviceId = json['device'] as String?;
    final device = deviceById(deviceId);
    var customSize = custom == null
        ? null
        : Size((custom[0] as num).toDouble(), (custom[1] as num).toDouble());
    // Old format: keep the old size so elements don't move
    if (json['v'] == null && customSize == null) {
      if (legacyDevices[deviceId] case (_, final old) when old != device.size) {
        customSize = old;
      }
    }
    return DesignPage(
      id: json['id'] as String,
      name: json['name'] as String,
      device: device,
      landscape: json['landscape'] as bool? ?? false,
      customSize: customSize,
      showSafeArea: json['safeArea'] as bool? ?? false,
      background: Color(json['background'] as int),
      elements: [
        for (final e in json['elements'] as List)
          UiElement.fromJson(e as Map<String, dynamic>),
      ],
      position: _offset(json['pos']),
      guides: [
        for (final g in json['guides'] as List? ?? const [])
          Guide.fromJson(g as Map<String, dynamic>),
      ],
      grid: json['grid'] == null
          ? const GridSettings()
          : GridSettings.fromJson(json['grid'] as Map<String, dynamic>),
      rulerOrigin: _offset(json['origin']) ?? Offset.zero,
    );
  }
}

Offset? _offset(Object? v) => v is List
    ? Offset((v[0] as num).toDouble(), (v[1] as num).toDouble())
    : null;

/// The portrait safe area turned to landscape (phone rotated left):
/// the top part (notch / Dynamic Island) moves to the side, and the home
/// indicator stays at the bottom.
EdgeInsets rotateSafeArea(EdgeInsets s) {
  if (s.bottom == 0) return EdgeInsets.zero; // k.m. iPhone SE
  return EdgeInsets.only(left: s.top, right: s.top, bottom: 21);
}
