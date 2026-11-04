import 'package:flutter/material.dart';

import '../canvas/layout.dart';
import '../icons/app_icons.dart';
import '../icons/icon_style.dart';
import 'device_frame.dart';

const brandColor = Color(0xFF4F46E5);
const inkColor = Color(0xFF101828);
const mutedColor = Color(0xFF667085);

enum ElementType {
  text('Maandishi', AppIcons.text, Size(220, 32)),
  button('Kitufe', AppIcons.button, Size(160, 48)),
  input('Sehemu ya kuandika', AppIcons.input, Size(280, 52)),
  image('Picha', AppIcons.image, Size(240, 160)),
  container('Kisanduku', AppIcons.container, Size(200, 120)),
  appBar('App bar', AppIcons.appBar, Size(393, 64)),
  navBar('Bottom nav', AppIcons.navBar, Size(393, 72)),
  iconItem('Icon', AppIcons.star, Size(40, 40)),
  avatar('Avatar', AppIcons.avatar, Size(56, 56)),
  toggle('Swichi', AppIcons.toggle, Size(52, 32)),
  divider('Mstari', AppIcons.divider, Size(280, 12));

  const ElementType(this.label, this.icon, this.defaultSize);

  final String label;
  final IconData icon;
  final Size defaultSize;

  /// Vipengele vinavyochukua upana wote wa skrini.
  bool get fullWidth => this == appBar || this == navBar;

  bool get hasText =>
      this == text ||
      this == button ||
      this == input ||
      this == appBar ||
      this == avatar;

  bool get hasRadius =>
      this == button || this == input || this == image || this == container;
}

/// Mpangilio wima wa maandishi ndani ya kisanduku chake.
enum VAlign {
  top(-1),
  middle(0),
  bottom(1);

  const VAlign(this.y);
  final double y;
}

/// Kipengele kipya kinachoburutwa au kubofywa kutoka paneli ya kushoto.
class NewElement {
  const NewElement(this.type, {this.text, this.iconStyle});

  final ElementType type;
  final String? text;
  final IconStyle? iconStyle;
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
  });

  /// Kipengele kipya chenye mtindo wa kawaida kwa aina yake.
  factory UiElement.create(ElementType type, String id, Rect rect) {
    return switch (type) {
      ElementType.text => UiElement(
        id: id,
        type: type,
        rect: rect,
        text: 'Kichwa cha habari',
        fontSize: 22,
        bold: true,
      ),
      ElementType.button => UiElement(
        id: id,
        type: type,
        rect: rect,
        text: 'Endelea',
        color: brandColor,
        textColor: Colors.white,
        radius: 12,
        bold: true,
      ),
      ElementType.input => UiElement(
        id: id,
        type: type,
        rect: rect,
        text: 'Barua pepe',
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
        text: 'Nyumbani',
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

  /// Maandishi; kwa [ElementType.iconItem] ni jina la icon.
  final String text;
  final Color color;
  final Color textColor;
  final double fontSize;
  final double radius;
  final bool bold;

  /// Kipengele kilichofungwa hakisogei wala kubadilika ukubwa.
  final bool locked;
  final IconStyle iconStyle;

  /// Mpangilio wa maandishi NDANI ya kisanduku (si kusogeza kipengele).
  /// null = kawaida ya aina hii (k.m. kitufe → katikati).
  final TextAlign? textAlign;
  final VAlign vAlign;

  /// Prototype: kubonyeza kipengele kwenye "Run" kunaenda skrini hii (id).
  final String? link;

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
  };

  factory UiElement.fromJson(Map<String, dynamic> json) {
    final r = [for (final v in json['rect'] as List) (v as num).toDouble()];
    final type = switch (json['type']) {
      'icon' => ElementType.iconItem,
      final String name => ElementType.values.byName(name),
      _ => throw const FormatException('Aina ya kipengele haijulikani'),
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
    );
  }
}

/// Skrini moja ya muundo (k.m. "Login" kwenye iPhone).
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

  /// Kifaa kimelazwa (mlalo) badala ya kusimama (wima).
  final bool landscape;

  /// Ukubwa wa artboard uliobadilishwa na mtumiaji (ukiwa wima). Kwa
  /// kifaa cha "Ukubwa maalum" ni ukubwa wake; kwa vifaa vingine ni
  /// "responsive resize" — kifaa (na metadata yake) kinabaki.
  final Size? customSize;

  /// Onyesha miongozo ya safe area kwenye canvas.
  final bool showSafeArea;
  final Color background;
  final List<UiElement> elements;

  /// Mahali pa artboard kwenye canvas (world). null = itapangwa yenyewe.
  final Offset? position;
  final List<Guide> guides;
  final GridSettings grid;

  /// Mwanzo (0,0) wa rulers ndani ya artboard; Offset.zero = kona ya
  /// juu-kushoto.
  final Offset rulerOrigin;

  /// Ukubwa wa artboard ukiwa wima.
  Size get portraitSize => customSize ?? device.size;

  /// Ukubwa halisi wa skrini kwa kuzingatia mlalo na ukubwa maalum.
  Size get size => landscape ? portraitSize.flipped : portraitSize;

  /// Artboard imebadilishwa kutoka ukubwa wa kifaa.
  bool get resized => customSize != null && customSize != device.size;

  /// Safe area kwa mwelekeo wa sasa (null kama haijulikani).
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

  /// Mstatili wa artboard kwenye canvas (world).
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
    // Metadata ya kifaa (kwa kumbukumbu na export; haisomwi tena)
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
    // Toleo la zamani: weka ukubwa wa zamani ili vipengele visisogee
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

/// Safe area ya wima ikigeuzwa kuwa mlalo (simu imezungushwa kushoto):
/// sehemu ya juu (notch / Dynamic Island) inakuwa upande, na home
/// indicator inabaki chini.
EdgeInsets rotateSafeArea(EdgeInsets s) {
  if (s.bottom == 0) return EdgeInsets.zero; // k.m. iPhone SE
  return EdgeInsets.only(left: s.top, right: s.top, bottom: 21);
}
