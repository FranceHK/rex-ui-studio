import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Mwongozo (guide) wa artboard. [axis] = vertical → mstari wima kwenye
/// X = [position]; horizontal → mstari mlalo kwenye Y = [position].
/// [position] iko kwenye nafasi ya artboard (artboard-local).
class Guide {
  const Guide({
    required this.id,
    required this.axis,
    required this.position,
    this.locked = false,
  });

  final String id;
  final Axis axis;
  final double position;
  final bool locked;

  bool get vertical => axis == Axis.vertical;

  /// Maandishi ya kuonyesha, k.m. "X = 120".
  String get label => '${vertical ? 'X' : 'Y'} = ${_n(position)}';

  Guide copyWith({double? position, bool? locked}) => Guide(
    id: id,
    axis: axis,
    position: position ?? this.position,
    locked: locked ?? this.locked,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'axis': axis.name,
    'pos': position,
    if (locked) 'locked': true,
  };

  factory Guide.fromJson(Map<String, dynamic> json) => Guide(
    id: json['id'] as String,
    axis: Axis.values.byName(json['axis'] as String),
    position: (json['pos'] as num).toDouble(),
    locked: json['locked'] as bool? ?? false,
  );
}

String _n(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Gridi ya safu (columns) au mistari (rows) ya artboard.
///
/// [size] = null → safu "zinanyooka" (stretch) kujaza nafasi kati ya
/// margin; vinginevyo kila safu ina upana [size] na zimewekwa katikati.
class TrackGrid {
  const TrackGrid({
    this.enabled = false,
    this.count = 4,
    this.gutter = 16,
    this.margin = 16,
    this.size,
  });

  final bool enabled;
  final int count;
  final double gutter;
  final double margin;
  final double? size;

  bool get stretch => size == null;

  /// Sehemu (mwanzo, mwisho) za kila safu kwa urefu [length] wa artboard.
  List<(double, double)> tracks(double length) {
    if (count < 1) return const [];
    final double track;
    final double start;
    if (size case final s?) {
      track = s;
      final total = s * count + gutter * (count - 1);
      start = (length - total) / 2;
    } else {
      track = (length - margin * 2 - gutter * (count - 1)) / count;
      start = margin;
    }
    if (track <= 0) return const [];
    return [
      for (var i = 0; i < count; i++)
        (start + i * (track + gutter), start + i * (track + gutter) + track),
    ];
  }

  TrackGrid copyWith({
    bool? enabled,
    int? count,
    double? gutter,
    double? margin,
    double? size,
    bool clearSize = false,
  }) => TrackGrid(
    enabled: enabled ?? this.enabled,
    count: count ?? this.count,
    gutter: gutter ?? this.gutter,
    margin: margin ?? this.margin,
    size: clearSize ? null : size ?? this.size,
  );

  Map<String, dynamic> toJson() => {
    'on': enabled,
    'count': count,
    'gutter': gutter,
    'margin': margin,
    'size': ?size,
  };

  factory TrackGrid.fromJson(Map<String, dynamic> json) => TrackGrid(
    enabled: json['on'] as bool? ?? false,
    count: json['count'] as int? ?? 4,
    gutter: (json['gutter'] as num?)?.toDouble() ?? 16,
    margin: (json['margin'] as num?)?.toDouble() ?? 16,
    size: (json['size'] as num?)?.toDouble(),
  );
}

/// Mipangilio ya gridi ya artboard moja.
class GridSettings {
  const GridSettings({
    this.show = false,
    this.size = 8,
    this.color = const Color(0xFFF04438),
    this.opacity = 0.12,
    this.offset = Offset.zero,
    this.columns = const TrackGrid(),
    this.rows = const TrackGrid(count: 6),
  });

  /// Gridi ya miraba inaonekana.
  final bool show;
  final double size;
  final Color color;
  final double opacity;
  final Offset offset;
  final TrackGrid columns;
  final TrackGrid rows;

  static const sizes = [4.0, 8.0, 10.0, 16.0, 20.0, 24.0, 32.0];

  bool get anyVisible => show || columns.enabled || rows.enabled;

  GridSettings copyWith({
    bool? show,
    double? size,
    Color? color,
    double? opacity,
    Offset? offset,
    TrackGrid? columns,
    TrackGrid? rows,
  }) => GridSettings(
    show: show ?? this.show,
    size: size ?? this.size,
    color: color ?? this.color,
    opacity: opacity ?? this.opacity,
    offset: offset ?? this.offset,
    columns: columns ?? this.columns,
    rows: rows ?? this.rows,
  );

  Map<String, dynamic> toJson() => {
    'show': show,
    'size': size,
    'color': color.toARGB32(),
    'opacity': opacity,
    'offset': [offset.dx, offset.dy],
    'columns': columns.toJson(),
    'rows': rows.toJson(),
  };

  factory GridSettings.fromJson(Map<String, dynamic> json) {
    final o = json['offset'] as List?;
    return GridSettings(
      show: json['show'] as bool? ?? false,
      size: (json['size'] as num?)?.toDouble() ?? 8,
      color: Color(json['color'] as int? ?? 0xFFF04438),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.12,
      offset: o == null
          ? Offset.zero
          : Offset((o[0] as num).toDouble(), (o[1] as num).toDouble()),
      columns: TrackGrid.fromJson(
        json['columns'] as Map<String, dynamic>? ?? const {},
      ),
      rows: TrackGrid.fromJson(
        json['rows'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

/// Alignment inalenga nini.
enum AlignTo {
  selection('Uteuzi (selection)'),
  artboard('Artboard'),
  keyObject('Kipengele kikuu (key object)'),
  parent('Fremu mzazi (parent frame)');

  const AlignTo(this.label);
  final String label;
}

/// Mapendeleo ya mwonekano ya mradi (yanahifadhiwa pamoja na mradi).
class ViewSettings {
  const ViewSettings({
    this.showRulers = true,
    this.showGuides = true,
    this.guidesLocked = false,
    this.guideColor = const Color(0xFF06AED4),
    this.snap = true,
    this.snapObjects = true,
    this.snapGuides = true,
    this.snapGrid = false,
    this.snapArtboard = true,
    this.smartGuides = true,
    this.showDistances = true,
    this.alignTo = AlignTo.selection,
    this.hGap = 16,
    this.vGap = 16,
    this.penOnly,
    this.lockView = false,
  });

  final bool showRulers;
  final bool showGuides;
  final bool guidesLocked;
  final Color guideColor;
  final bool snap;
  final bool snapObjects;
  final bool snapGuides;
  final bool snapGrid;
  final bool snapArtboard;
  final bool smartGuides;
  final bool showDistances;
  final AlignTo alignTo;
  final double hGap;
  final double vGap;

  /// Hali ya kalamu: kidole kimoja hakihariri canvas (kiganja hakigusi
  /// vitu kwa bahati mbaya); kalamu/kipanya vinahariri, vidole viwili
  /// vinazoom na kusogeza. null = chaguo-msingi la kifaa ([penMode]).
  final bool? penOnly;

  /// Mwonekano umefungwa: canvas haisogei wala kuzoom kwa ishara.
  final bool lockView;

  /// Kwenye tablet/simu hali ya kalamu inawashwa kwa chaguo-msingi.
  bool get penMode =>
      penOnly ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));

  static const guideColors = [
    Color(0xFF06AED4),
    Color(0xFFF04438),
    Color(0xFF7A5AF8),
    Color(0xFF12B76A),
    Color(0xFFF79009),
  ];

  ViewSettings copyWith({
    bool? showRulers,
    bool? showGuides,
    bool? guidesLocked,
    Color? guideColor,
    bool? snap,
    bool? snapObjects,
    bool? snapGuides,
    bool? snapGrid,
    bool? snapArtboard,
    bool? smartGuides,
    bool? showDistances,
    AlignTo? alignTo,
    double? hGap,
    double? vGap,
    bool? penOnly,
    bool? lockView,
  }) => ViewSettings(
    showRulers: showRulers ?? this.showRulers,
    showGuides: showGuides ?? this.showGuides,
    guidesLocked: guidesLocked ?? this.guidesLocked,
    guideColor: guideColor ?? this.guideColor,
    snap: snap ?? this.snap,
    snapObjects: snapObjects ?? this.snapObjects,
    snapGuides: snapGuides ?? this.snapGuides,
    snapGrid: snapGrid ?? this.snapGrid,
    snapArtboard: snapArtboard ?? this.snapArtboard,
    smartGuides: smartGuides ?? this.smartGuides,
    showDistances: showDistances ?? this.showDistances,
    alignTo: alignTo ?? this.alignTo,
    hGap: hGap ?? this.hGap,
    vGap: vGap ?? this.vGap,
    penOnly: penOnly ?? this.penOnly,
    lockView: lockView ?? this.lockView,
  );

  Map<String, dynamic> toJson() => {
    'rulers': showRulers,
    'guides': showGuides,
    'guidesLocked': guidesLocked,
    'guideColor': guideColor.toARGB32(),
    'snap': snap,
    'snapObjects': snapObjects,
    'snapGuides': snapGuides,
    'snapGrid': snapGrid,
    'snapArtboard': snapArtboard,
    'smartGuides': smartGuides,
    'distances': showDistances,
    'alignTo': alignTo.name,
    'hGap': hGap,
    'vGap': vGap,
    'penOnly': ?penOnly,
    'lockView': lockView,
  };

  factory ViewSettings.fromJson(Map<String, dynamic> j) => ViewSettings(
    showRulers: j['rulers'] as bool? ?? true,
    showGuides: j['guides'] as bool? ?? true,
    guidesLocked: j['guidesLocked'] as bool? ?? false,
    guideColor: Color(j['guideColor'] as int? ?? 0xFF06AED4),
    snap: j['snap'] as bool? ?? true,
    snapObjects: j['snapObjects'] as bool? ?? true,
    snapGuides: j['snapGuides'] as bool? ?? true,
    snapGrid: j['snapGrid'] as bool? ?? false,
    snapArtboard: j['snapArtboard'] as bool? ?? true,
    smartGuides: j['smartGuides'] as bool? ?? true,
    showDistances: j['distances'] as bool? ?? true,
    alignTo: AlignTo.values.asNameMap()[j['alignTo']] ?? AlignTo.selection,
    hGap: (j['hGap'] as num?)?.toDouble() ?? 16,
    vGap: (j['vGap'] as num?)?.toDouble() ?? 16,
    penOnly: j['penOnly'] as bool?,
    lockView: j['lockView'] as bool? ?? false,
  );
}
