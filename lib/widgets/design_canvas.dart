import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../canvas/geometry.dart';
import '../canvas/layout.dart';
import '../canvas/snapping.dart';
import '../icons/app_icons.dart';
import '../models/ui_element.dart';
import '../state/editor_controller.dart';
import 'canvas_painters.dart';
import 'device_preview.dart' show SafeAreaGuides;
import 'element_view.dart';

/// Tolerance ya snapping kwa pixel za SKRINI (inabaki sawa kwa zoom yoyote).
const snapTolerancePx = 6.0;

/// Eneo la kazi: artboards zote za mradi zinaonekana pamoja, zinaweza
/// kusogezwa, na kila moja ina vipengele vyake. Rulers, guides, gridi na
/// snapping zote zinatumia [CanvasTransform] moja.
class DesignCanvas extends StatefulWidget {
  const DesignCanvas({super.key, required this.controller});

  final EditorController controller;

  @override
  State<DesignCanvas> createState() => _DesignCanvasState();
}

/// Kinachoburutwa sasa hivi.
sealed class _Drag {}

class _MoveDrag extends _Drag {
  _MoveDrag(this.start, this.pointer, this.targets);
  final Map<String, Rect> start;
  final Offset pointer; // nafasi ya artboard
  final SnapTargets targets;
  bool recorded = false;
}

class _ResizeDrag extends _Drag {
  _ResizeDrag(this.id, this.start, this.pointer, this.targets);
  final String id;
  final Rect start;
  final Offset pointer;
  final SnapTargets targets;
  bool recorded = false;
}

class _MarqueeDrag extends _Drag {
  _MarqueeDrag(this.start, this.add);
  final Offset start;
  final bool add;
  Rect rect = Rect.zero;
}

class _DesignCanvasState extends State<DesignCanvas> {
  final _stackKey = GlobalKey();

  EditorController get c => widget.controller;
  ViewSettings get v => c.view;

  CanvasTransform? _view;
  Size _viewport = Size.zero;
  int _pageCount = 0;
  double _lastPinch = 1;

  _Drag? _drag;
  List<SnapLine> _lines = const [];
  List<Measure> _measures = const [];

  /// Guide inayoburutwa kutoka kwenye ruler (bado haijaongezwa).
  ({Axis axis, double position, bool overCanvas})? _newGuide;
  String? _selectedGuide;
  Offset? _lastGuidePointer;
  bool _guideDragRecorded = false;

  final _cursor = ValueNotifier<Offset?>(null);
  String? _hoverId;
  bool _alt = false;

  /// Vidole vilivyo kwenye canvas (pointer → nafasi, kwa pinch).
  final _touches = <int, Offset>{};
  bool _pinching = false;

  /// Pointer inayovuta guide mpya kutoka kwenye ruler.
  int? _rulerPointer;

  /// Vifaa vinavyoweza kuhariri canvas. Hali ya kalamu: kidole hakihariri
  /// (kiganja hakiguse vitu kwa bahati mbaya); vidole viwili = zoom/sogeza.
  Set<PointerDeviceKind> get _editDevices => v.penMode
      ? const {
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.trackpad,
        }
      : const {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.trackpad,
        };

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _cursor.dispose();
    super.dispose();
  }

  /// Alt (Option) inaonyesha umbali bila kusogeza kitu.
  bool _onKey(KeyEvent event) {
    final alt = HardwareKeyboard.instance.isAltPressed;
    if (alt != _alt && mounted) setState(() => _alt = alt);
    return false;
  }

  // ---------- Nafasi ----------

  Offset _canvasLocal(Offset global) {
    final box = _stackKey.currentContext!.findRenderObject()! as RenderBox;
    return box.globalToLocal(global);
  }

  Offset _world(Offset global) => _view!.toWorld(_canvasLocal(global));

  Offset get _origin => c.page.position ?? Offset.zero;

  /// Nafasi ndani ya artboard ya sasa.
  Offset _local(Offset global) => _world(global) - _origin;

  bool get _snapOn {
    final keys = HardwareKeyboard.instance;
    // Ctrl/Cmd wakati wa kuburuta = zima snapping kwa muda
    return v.snap && !keys.isControlPressed && !keys.isMetaPressed;
  }

  SnapTargets _targets(Set<String> exclude) {
    final p = c.page;
    final grid = p.grid;
    return SnapTargets(
      artboard: p.size,
      others: [
        for (final e in p.elements)
          if (!exclude.contains(e.id)) e.rect,
      ],
      guideX: [
        for (final g in p.guides)
          if (g.vertical) g.position,
      ],
      guideY: [
        for (final g in p.guides)
          if (!g.vertical) g.position,
      ],
      grid: v.snapGrid ? grid.size : null,
      gridOffset: grid.offset,
      columnX: v.snapGrid && grid.columns.enabled
          ? [
              for (final (a, b) in grid.columns.tracks(p.size.width)) ...[a, b],
            ]
          : const [],
      rowY: v.snapGrid && grid.rows.enabled
          ? [
              for (final (a, b) in grid.rows.tracks(p.size.height)) ...[a, b],
            ]
          : const [],
      objects: v.snapObjects,
      guides: v.snapGuides && v.showGuides,
      artboardEdges: v.snapArtboard,
    );
  }

  // ---------- Kusogeza vipengele ----------

  void _focusPage(int index) {
    if (index != c.pageIndex) c.selectPage(index);
  }

  void _tapElement(int pageIndex, UiElement e) {
    _focusPage(pageIndex);
    setState(() => _selectedGuide = null);
    if (HardwareKeyboard.instance.isShiftPressed) {
      c.toggleSelect(e.id);
    } else if (c.selectedIds.contains(e.id) && c.selectedIds.length > 1) {
      // Bonyeza tena kipengele kilichochaguliwa = kiwe kipengele kikuu
      c.setKeyObject(e.id);
    } else {
      c.select(e.id);
    }
  }

  void _beginMove(int pageIndex, UiElement e, Offset global) {
    _focusPage(pageIndex);
    if (!c.selectedIds.contains(e.id)) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        c.toggleSelect(e.id);
      } else {
        c.select(e.id);
      }
    }
    final moving = {
      for (final s in c.selectedElements)
        if (!s.locked) s.id: s.rect,
    };
    if (moving.isEmpty) return;
    _drag = _MoveDrag(moving, _local(global), _targets(moving.keys.toSet()));
  }

  void _updateMove(Offset global) {
    if (_pinching) return;
    final d = _drag;
    if (d is! _MoveDrag) return;
    if (!d.recorded) {
      c.checkpoint();
      d.recorded = true;
    }
    final startBounds = boundsOf(d.start.values);
    final delta = _local(global) - d.pointer;
    final group = startBounds.shift(delta);
    final rounded = Rect.fromLTWH(
      group.left.roundToDouble(),
      group.top.roundToDouble(),
      group.width,
      group.height,
    );
    final snapped = _snapOn
        ? snapRect(rounded, d.targets, snapTolerancePx / _view!.scale)
        : SnapResult(rounded, const []);
    final shift = snapped.rect.topLeft - startBounds.topLeft;
    c.setRects({
      for (final MapEntry(:key, :value) in d.start.entries)
        key: value.shift(shift),
    }, record: false);
    setState(() {
      _lines = v.smartGuides ? snapped.lines : const [];
      _measures = v.showDistances
          ? measureDistances(snapped.rect, d.targets.others, c.page.size)
          : const [];
    });
  }

  void _beginResize(UiElement e, Offset global) {
    _drag = _ResizeDrag(e.id, e.rect, _local(global), _targets({e.id}));
  }

  void _updateResize(Offset global) {
    if (_pinching) return;
    final d = _drag;
    if (d is! _ResizeDrag) return;
    if (!d.recorded) {
      c.checkpoint();
      d.recorded = true;
    }
    final delta = _local(global) - d.pointer;
    final raw = Rect.fromLTWH(
      d.start.left,
      d.start.top,
      max(8, (d.start.width + delta.dx).roundToDouble()),
      max(4, (d.start.height + delta.dy).roundToDouble()),
    );
    final snapped = _snapOn
        ? snapRect(raw, d.targets, snapTolerancePx / _view!.scale, resize: true)
        : SnapResult(raw, const []);
    c.setRects({d.id: snapped.rect}, record: false);
    setState(() => _lines = v.smartGuides ? snapped.lines : const []);
  }

  void _endDrag() {
    final d = _drag;
    if (d is _MarqueeDrag) c.selectInRect(d.rect, add: d.add);
    setState(() {
      _drag = null;
      _lines = const [];
      _measures = const [];
    });
  }

  // ---------- Marquee (kuchagua vingi kwa kuburuta) ----------

  void _beginMarquee(int pageIndex, Offset global) {
    _focusPage(pageIndex);
    final start = _local(global);
    final add = HardwareKeyboard.instance.isShiftPressed;
    setState(() => _drag = _MarqueeDrag(start, add));
  }

  void _updateMarquee(Offset global) {
    if (_pinching) return;
    final d = _drag;
    if (d is! _MarqueeDrag) return;
    setState(() => d.rect = Rect.fromPoints(d.start, _local(global)));
  }

  // ---------- Zoom na pan ----------

  void _zoomAt(double factor, Offset focal) {
    final view = _view!;
    final next = (view.scale * factor).clamp(0.05, 16.0);
    setState(() => _view = view.zoomAt(next, focal));
  }

  void _setZoom(double scale) => setState(
    () => _view = _view!.zoomAt(scale, _viewport.center(Offset.zero)),
  );

  double get _fitPad => v.showRulers ? 64 : 48;

  void _fitPage() => setState(
    () =>
        _view = CanvasTransform.fit(c.page.worldRect, _viewport, pad: _fitPad),
  );

  void _fitAll() => setState(
    () => _view = CanvasTransform.fit(
      boundsOf(c.pages.map((p) => p.worldRect)),
      _viewport,
      pad: _fitPad,
    ),
  );

  /// Lete artboard ya sasa katikati ikiwa iko nje ya mwonekano.
  void _reveal() {
    final view = _view;
    if (view == null) return;
    final screen = view.rectToScreen(c.page.worldRect);
    if (!(Offset.zero & _viewport).overlaps(screen)) {
      _view = view.panBy(_viewport.center(Offset.zero) - screen.center);
    }
  }

  // ---------- Guides ----------

  void _startGuideFromRuler(Axis axis, Offset global) {
    final local = _local(global);
    setState(() {
      _newGuide = (
        axis: axis,
        position: (axis == Axis.vertical ? local.dx : local.dy).roundToDouble(),
        overCanvas: false,
      );
    });
  }

  void _updateNewGuide(Offset global) {
    final g = _newGuide;
    if (g == null) return;
    final local = _local(global);
    final screen = _canvasLocal(global);
    setState(() {
      _newGuide = (
        axis: g.axis,
        position: (g.axis == Axis.vertical ? local.dx : local.dy)
            .roundToDouble(),
        overCanvas: g.axis == Axis.vertical
            ? screen.dx > rulerSize
            : screen.dy > rulerSize,
      );
    });
  }

  void _endNewGuide() {
    final g = _newGuide;
    if (g != null && g.overCanvas) {
      _selectedGuide = c.addGuide(g.axis, g.position);
    }
    setState(() => _newGuide = null);
  }

  void _dragGuide(Guide g, Offset global) {
    if (_pinching) return;
    if (g.locked || v.guidesLocked) return;
    final local = _local(global);
    if (!_guideDragRecorded) {
      c.checkpoint();
      _guideDragRecorded = true;
    }
    c.moveGuide(
      g.id,
      (g.vertical ? local.dx : local.dy).roundToDouble(),
      record: false,
    );
  }

  void _endGuideDrag(Guide g) {
    _guideDragRecorded = false;
    final last = _lastGuidePointer;
    _lastGuidePointer = null;
    // Kuirudisha guide kwenye ruler = kuifuta
    if (last != null && v.showRulers && !g.locked && !v.guidesLocked) {
      final s = _canvasLocal(last);
      if ((g.vertical && s.dx < rulerSize) ||
          (!g.vertical && s.dy < rulerSize)) {
        c.deleteGuide(g.id);
        setState(() => _selectedGuide = null);
      }
    }
  }

  Future<void> _editGuide(Guide g) async {
    final origin = g.vertical ? c.page.rulerOrigin.dx : c.page.rulerOrigin.dy;
    final ctrl = TextEditingController(text: '${tidy(g.position - origin)}');
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(g.vertical ? 'Guide wima (X)' : 'Guide mlalo (Y)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: g.vertical ? 'X' : 'Y',
            suffixText: 'px',
          ),
          onSubmitted: (s) => Navigator.pop(context, double.tryParse(s)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ghairi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text)),
            child: const Text('Weka'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value != null) c.moveGuide(g.id, value + origin);
  }

  // ---------- Artboards ----------

  Offset? _artboardStart;
  Offset? _artboardPointer;
  bool _artboardRecorded = false;
  bool _resizeRecorded = false;

  void _beginArtboardMove(int i, Offset global) {
    _focusPage(i);
    _artboardStart = c.pages[i].position ?? Offset.zero;
    _artboardPointer = _world(global);
    _artboardRecorded = false;
  }

  void _updateArtboardMove(int i, Offset global) {
    if (_pinching) return;
    if (_artboardStart == null) return;
    c.moveArtboard(
      i,
      _artboardStart! + (_world(global) - _artboardPointer!),
      record: !_artboardRecorded,
    );
    _artboardRecorded = true;
  }

  /// Badilisha ukubwa wa artboard (k.m. kuirefusha chini kwa skrini
  /// ndefu inayoscroll kwenye "Run").
  void _resizeArtboard(
    Offset global, {
    required bool width,
    required bool height,
  }) {
    final p = c.page;
    final local = _local(global);
    final next = Size(
      width ? max(80, local.dx.roundToDouble()) : p.size.width,
      height ? max(80, local.dy.roundToDouble()) : p.size.height,
    );
    c.setCustomSize(
      p.landscape ? next.flipped : next,
      record: !_resizeRecorded,
    );
    _resizeRecorded = true;
  }

  // ---------- Vidole viwili: zoom na sogeza ----------

  void _touchDown(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch) return;
    _touches[e.pointer] = e.localPosition;
    if (_touches.length == 2) {
      // Ishara ya vidole viwili inasimamisha uhariri wowote unaoendelea
      _endDrag();
      _artboardStart = null;
      setState(() {
        _pinching = true;
        _newGuide = null;
        _rulerPointer = null;
      });
    }
  }

  void _touchMove(PointerMoveEvent e) {
    if (!_touches.containsKey(e.pointer)) return;
    if (!_pinching || _touches.length < 2) {
      _touches[e.pointer] = e.localPosition;
      return;
    }
    final before = _touches.values.take(2).toList();
    _touches[e.pointer] = e.localPosition;
    final after = _touches.values.take(2).toList();
    if (v.lockView) return;
    final c0 = (before[0] + before[1]) / 2;
    final c1 = (after[0] + after[1]) / 2;
    final d0 = (before[0] - before[1]).distance;
    final d1 = (after[0] - after[1]).distance;
    var next = _view!.panBy(c1 - c0);
    if (d0 > 0 && d1 > 0) {
      next = next.zoomAt((next.scale * d1 / d0).clamp(0.05, 16.0), c1);
    }
    setState(() => _view = next);
  }

  void _touchUp(PointerEvent e) {
    _touches.remove(e.pointer);
    if (_touches.isEmpty && _pinching) setState(() => _pinching = false);
  }

  void _toggleLockView() => c.setView(v.copyWith(lockView: !v.lockView));

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, box) {
        _viewport = box.biggest;
        _view ??= CanvasTransform.fit(
          c.page.worldRect,
          _viewport,
          pad: _fitPad,
        );
        // Artboard mpya ikiongezwa, ionyeshe
        if (c.pages.length != _pageCount) {
          if (c.pages.length > _pageCount && _pageCount != 0) _reveal();
          _pageCount = c.pages.length;
        }
        final view = _view!;
        final page = c.page;
        final selection = c.selectedElements;
        final selBounds = selection.isEmpty
            ? null
            : boundsOf(selection.map((e) => e.rect));

        // Alt: kagua umbali bila kusogeza
        var measures = _measures;
        if (_alt && _drag == null && selBounds != null && v.showDistances) {
          final hovered = page.elements
              .where((e) => e.id == _hoverId && !c.selectedIds.contains(e.id))
              .firstOrNull;
          measures = hovered != null
              ? measureBetween(selBounds, hovered.rect)
              : measureDistances(selBounds, [
                  for (final e in page.elements)
                    if (!c.selectedIds.contains(e.id)) e.rect,
                ], page.size);
        }

        return Listener(
          onPointerHover: (e) => _cursor.value = view.toWorld(e.localPosition),
          onPointerMove: (e) {
            _cursor.value = _view!.toWorld(e.localPosition);
            _touchMove(e);
          },
          onPointerDown: _touchDown,
          onPointerUp: _touchUp,
          onPointerCancel: _touchUp,
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent || v.lockView) return;
            final keys = HardwareKeyboard.instance;
            if (keys.isControlPressed || keys.isMetaPressed) {
              _zoomAt(
                event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1,
                event.localPosition,
              );
            } else if (keys.isShiftPressed) {
              setState(
                () => _view = _view!.panBy(
                  Offset(-event.scrollDelta.dy, -event.scrollDelta.dx),
                ),
              );
            } else {
              setState(() => _view = _view!.panBy(-event.scrollDelta));
            }
          },
          onPointerPanZoomStart: (_) => _lastPinch = 1,
          onPointerPanZoomUpdate: (event) {
            if (v.lockView) return;
            setState(() => _view = _view!.panBy(event.panDelta));
            if (event.scale != _lastPinch) {
              _zoomAt(event.scale / _lastPinch, event.localPosition);
              _lastPinch = event.scale;
            }
          },
          child: GestureDetector(
            // Kalamu/kipanya kwenye nafasi tupu = sogeza mwonekano. Kidole
            // kimoja kinasogeza tu nje ya hali ya kalamu.
            supportedDevices: _editDevices,
            onTap: () {
              c.select(null);
              setState(() => _selectedGuide = null);
            },
            onPanUpdate: (d) {
              if (v.lockView || _pinching || _newGuide != null) return;
              setState(() => _view = _view!.panBy(d.delta));
            },
            child: ColoredBox(
              color: scheme.surfaceContainerLow,
              child: Stack(
                key: _stackKey,
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final (i, p) in c.pages.indexed) ...[
                    _artboardTitle(i, p, view, scheme),
                    _artboard(i, p, view, scheme),
                  ],
                  if (v.showGuides) ..._guides(view),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: OverlayPainter(
                          view: view,
                          artboardOrigin: _origin,
                          lines: _lines,
                          measures: measures,
                          marquee: switch (_drag) {
                            _MarqueeDrag(:final rect) => rect,
                            _ => null,
                          },
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                  if (_newGuide case final g?)
                    _guideLine(
                      view,
                      g.axis,
                      g.position,
                      v.guideColor.withValues(alpha: g.overCanvas ? 1 : 0.4),
                      key: const ValueKey('guide-new'),
                      label: _guideLabel(g.axis, g.position),
                    ),
                  if (v.showRulers) ..._rulers(view, scheme, selBounds),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _ZoomBar(
                      percent: (view.scale * 100).round(),
                      onZoomIn: () =>
                          _zoomAt(1.25, _viewport.center(Offset.zero)),
                      onZoomOut: () =>
                          _zoomAt(1 / 1.25, _viewport.center(Offset.zero)),
                      onFit: _fitPage,
                      onFitAll: _fitAll,
                      onPreset: _setZoom,
                      locked: v.lockView,
                      onToggleLock: _toggleLockView,
                    ),
                  ),
                  if (page.guides
                          .where((g) => g.id == _selectedGuide)
                          .firstOrNull
                      case final g?)
                    Positioned(
                      left: (v.showRulers ? rulerSize : 0) + 12,
                      bottom: 16,
                      child: _GuideChip(
                        label: _guideLabel(g.axis, g.position),
                        locked: g.locked,
                        onEdit: () => _editGuide(g),
                        onLock: () => c.toggleGuideLock(g.id),
                        onDelete: () {
                          c.deleteGuide(g.id);
                          setState(() => _selectedGuide = null);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// "X = 120" kulingana na origin ya rulers.
  String _guideLabel(Axis axis, double position) {
    final o = c.page.rulerOrigin;
    final vertical = axis == Axis.vertical;
    final value = tidy(position - (vertical ? o.dx : o.dy));
    final text = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    return '${vertical ? 'X' : 'Y'} = $text px';
  }

  Widget _artboardTitle(
    int i,
    DesignPage p,
    CanvasTransform view,
    ColorScheme scheme,
  ) {
    final rect = view.rectToScreen(p.worldRect);
    final active = i == c.pageIndex;
    return Positioned(
      key: ValueKey('title-${p.id}'),
      left: rect.left,
      top: rect.top - 24,
      width: max(rect.width, 80),
      height: 22,
      child: GestureDetector(
        supportedDevices: _editDevices,
        onTap: () => _focusPage(i),
        onPanStart: (d) => _beginArtboardMove(i, d.globalPosition),
        onPanUpdate: (d) => _updateArtboardMove(i, d.globalPosition),
        onPanEnd: (_) => _artboardStart = null,
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              '${p.name} · ${p.size.width.round()}×${p.size.height.round()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? scheme.primary : scheme.outline,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _artboard(
    int i,
    DesignPage p,
    CanvasTransform view,
    ColorScheme scheme,
  ) {
    final rect = view.rectToScreen(p.worldRect);
    final active = i == c.pageIndex;
    final scale = view.scale;
    final corner = p.device.cornerRadius(p.size) * scale;
    const handle = 10.0;

    final content = DragTarget<NewElement>(
      onAcceptWithDetails: (d) {
        _focusPage(i);
        c.addElement(
          d.data.type,
          at: _local(d.offset),
          text: d.data.text,
          iconStyle: d.data.iconStyle,
        );
      },
      builder: (context, candidates, _) => Container(
        foregroundDecoration: BoxDecoration(
          border: Border.all(
            color: candidates.isNotEmpty
                ? scheme.primary
                : active
                ? scheme.primary.withValues(alpha: 0.45)
                : Colors.transparent,
            width: candidates.isNotEmpty ? 3 : 1.5,
          ),
          borderRadius: BorderRadius.circular(corner),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(corner),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(corner),
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox.fromSize(
              size: p.size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Mandhari: bonyeza = ondoa uteuzi; buruta = marquee
                  Positioned.fill(
                    child: GestureDetector(
                      supportedDevices: _editDevices,
                      onTap: () {
                        _focusPage(i);
                        c.select(null);
                        setState(() => _selectedGuide = null);
                      },
                      onPanStart: (d) => _beginMarquee(i, d.globalPosition),
                      onPanUpdate: (d) => _updateMarquee(d.globalPosition),
                      onPanEnd: (_) => _endDrag(),
                      child: ColoredBox(color: p.background),
                    ),
                  ),
                  for (final e in p.elements)
                    _element(
                      i,
                      e,
                      selected: active && c.selectedIds.contains(e.id),
                      isKey:
                          active &&
                          e.id == c.selectedId &&
                          c.selectedIds.length > 1,
                      single: active && c.selectedIds.length == 1,
                      scale: scale,
                    ),
                  if (p.grid.anyVisible)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: GridPainter(p.grid, scale)),
                      ),
                    ),
                  if (p.safeArea case final insets? when p.showSafeArea)
                    Positioned.fill(child: SafeAreaGuides(insets: insets)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!active) return Positioned.fromRect(rect: rect, child: content);

    return Positioned.fromRect(
      key: ValueKey('artboard-${p.id}'),
      rect: rect.inflate(handle / 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: handle / 2,
            top: handle / 2,
            right: handle / 2,
            bottom: handle / 2,
            child: content,
          ),
          // Kurefusha chini / kupanua kulia
          _edgeHandle(
            left: handle,
            right: handle,
            bottom: 0,
            height: handle,
            cursor: SystemMouseCursors.resizeUpDown,
            onUpdate: (g) => _resizeArtboard(g, width: false, height: true),
          ),
          _edgeHandle(
            top: handle,
            bottom: handle,
            right: 0,
            width: handle,
            cursor: SystemMouseCursors.resizeLeftRight,
            onUpdate: (g) => _resizeArtboard(g, width: true, height: false),
          ),
          _edgeHandle(
            right: 0,
            bottom: 0,
            width: handle * 1.6,
            height: handle * 1.6,
            cursor: SystemMouseCursors.resizeDownRight,
            onUpdate: (g) => _resizeArtboard(g, width: true, height: true),
          ),
        ],
      ),
    );
  }

  Widget _edgeHandle({
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? width,
    double? height,
    required MouseCursor cursor,
    required void Function(Offset global) onUpdate,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: GestureDetector(
        supportedDevices: _editDevices,
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => onUpdate(d.globalPosition),
        onPanEnd: (_) => _resizeRecorded = false,
        child: MouseRegion(cursor: cursor),
      ),
    );
  }

  Widget _element(
    int pageIndex,
    UiElement e, {
    required bool selected,
    required bool isKey,
    required bool single,
    required double scale,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final handle = 12 / scale;

    return Positioned.fromRect(
      rect: e.rect,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: MouseRegion(
              onEnter: (_) => setState(() => _hoverId = e.id),
              onExit: (_) {
                if (_hoverId == e.id) setState(() => _hoverId = null);
              },
              cursor: e.locked
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.move,
              child: GestureDetector(
                supportedDevices: _editDevices,
                onTap: () => _tapElement(pageIndex, e),
                onPanStart: (d) => _beginMove(pageIndex, e, d.globalPosition),
                onPanUpdate: (d) => _updateMove(d.globalPosition),
                onPanEnd: (_) => _endDrag(),
                child: ElementView(element: e),
              ),
            ),
          ),
          if (selected) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: primary,
                      width: (isKey ? 3 : 1.5) / scale,
                    ),
                  ),
                ),
              ),
            ),
            if (e.locked)
              Positioned(
                right: 0,
                top: 0,
                child: IgnorePointer(
                  child: Container(
                    padding: EdgeInsets.all(3 / scale),
                    color: primary,
                    child: Icon(
                      AppIcons.lock,
                      size: 12 / scale,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else if (single)
              Positioned(
                right: -handle / 2,
                bottom: -handle / 2,
                width: handle,
                height: handle,
                child: GestureDetector(
                  supportedDevices: _editDevices,
                  onPanStart: (d) => _beginResize(e, d.globalPosition),
                  onPanUpdate: (d) => _updateResize(d.globalPosition),
                  onPanEnd: (_) => _endDrag(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeDownRight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: primary, width: 1.5 / scale),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (_alt && _hoverId == e.id && !selected)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFF04438),
                      width: 1 / scale,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Guides za artboard ya sasa: mstari + eneo la kushika.
  List<Widget> _guides(CanvasTransform view) {
    return [
      for (final g in c.page.guides)
        _guideLine(
          view,
          g.axis,
          g.position,
          v.guideColor,
          key: ValueKey('guide-${g.id}'),
          thick: g.id == _selectedGuide,
          label: g.id == _selectedGuide
              ? _guideLabel(g.axis, g.position)
              : null,
          interactive: (child) => GestureDetector(
            supportedDevices: _editDevices,
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(() => _selectedGuide = g.id),
            onDoubleTap: () => _editGuide(g),
            onPanStart: (_) => setState(() => _selectedGuide = g.id),
            onPanUpdate: (d) {
              _lastGuidePointer = d.globalPosition;
              _dragGuide(g, d.globalPosition);
            },
            onPanEnd: (_) => _endGuideDrag(g),
            child: MouseRegion(
              cursor: g.locked || v.guidesLocked
                  ? SystemMouseCursors.basic
                  : g.vertical
                  ? SystemMouseCursors.resizeLeftRight
                  : SystemMouseCursors.resizeUpDown,
              child: child,
            ),
          ),
        ),
    ];
  }

  /// Mstari wa guide unaovuka mwonekano wote (kama Figma/Illustrator).
  Widget _guideLine(
    CanvasTransform view,
    Axis axis,
    double position,
    Color color, {
    Key? key,
    bool thick = false,
    String? label,
    Widget Function(Widget child)? interactive,
  }) {
    final vertical = axis == Axis.vertical;
    final s = view.toScreen(
      vertical
          ? Offset(position + _origin.dx, 0)
          : Offset(0, position + _origin.dy),
    );
    const hit = 8.0;
    Widget line = Stack(
      clipBehavior: Clip.none,
      children: [
        Center(
          child: vertical
              ? Container(width: thick ? 2 : 1, color: color)
              : Container(height: thick ? 2 : 1, color: color),
        ),
        if (label != null)
          Positioned(
            left: vertical ? hit / 2 + 4 : 28,
            top: vertical ? 28 : hit / 2 + 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
    line = interactive?.call(line) ?? IgnorePointer(child: line);
    return vertical
        ? Positioned(
            key: key,
            left: s.dx - hit / 2,
            top: 0,
            bottom: 0,
            width: hit,
            child: line,
          )
        : Positioned(
            key: key,
            top: s.dy - hit / 2,
            left: 0,
            right: 0,
            height: hit,
            child: line,
          );
  }

  /// Kuvuta guide kutoka kwenye ruler. Inatumia pointer events moja kwa
  /// moja (si gesture arena) ili kuburuta kusikatike, na guide iwekwe
  /// pale kalamu/kidole kinapoachiwa.
  Widget _rulerListener(Axis axis, {required Widget child}) => Listener(
    onPointerDown: (e) {
      if (!_editDevices.contains(e.kind) || _pinching) return;
      _rulerPointer = e.pointer;
      _startGuideFromRuler(axis, e.position);
    },
    onPointerMove: (e) {
      if (e.pointer == _rulerPointer) _updateNewGuide(e.position);
    },
    onPointerUp: (e) {
      if (e.pointer != _rulerPointer) return;
      _rulerPointer = null;
      _updateNewGuide(e.position);
      _endNewGuide();
    },
    onPointerCancel: (e) {
      if (e.pointer != _rulerPointer) return;
      _rulerPointer = null;
      setState(() => _newGuide = null);
    },
    child: child,
  );

  List<Widget> _rulers(CanvasTransform view, ColorScheme scheme, Rect? sel) {
    final page = c.page;
    final origin = _origin + page.rulerOrigin;
    final highlight = sel?.shift(_origin);
    Widget ruler(bool horizontal) => ValueListenableBuilder<Offset?>(
      valueListenable: _cursor,
      builder: (context, cursor, _) => CustomPaint(
        painter: RulerPainter(
          view: view,
          origin: origin,
          horizontal: horizontal,
          colors: scheme,
          cursor: cursor,
          highlight: highlight,
        ),
      ),
    );
    return [
      Positioned(
        key: const ValueKey('ruler-top'),
        left: rulerSize,
        right: 0,
        top: 0,
        height: rulerSize,
        child: _rulerListener(
          Axis.horizontal,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: ruler(true),
          ),
        ),
      ),
      Positioned(
        key: const ValueKey('ruler-left'),
        left: 0,
        top: rulerSize,
        bottom: 0,
        width: rulerSize,
        child: _rulerListener(
          Axis.vertical,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: ruler(false),
          ),
        ),
      ),
      // Kona: buruta kuweka origin mpya ya rulers; bonyeza mara 2 kurudisha
      Positioned(
        key: const ValueKey('ruler-corner'),
        left: 0,
        top: 0,
        width: rulerSize,
        height: rulerSize,
        child: Tooltip(
          message: 'Buruta kuweka origin ya rulers · bonyeza mara 2 kurudisha',
          child: GestureDetector(
            supportedDevices: _editDevices,
            onDoubleTap: c.resetRulerOrigin,
            onPanUpdate: (_) {},
            onPanEnd: (_) {
              if (_cursor.value case final w?) {
                final local = w - _origin;
                c.setRulerOrigin(
                  Offset(local.dx.roundToDouble(), local.dy.roundToDouble()),
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  right: BorderSide(color: scheme.outlineVariant),
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Icon(
                AppIcons.ruler,
                size: 12,
                color: page.rulerOrigin == Offset.zero
                    ? scheme.outline
                    : scheme.primary,
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _GuideChip extends StatelessWidget {
  const _GuideChip({
    required this.label,
    required this.locked,
    required this.onEdit,
    required this.onLock,
    required this.onDelete,
  });

  final String label;
  final bool locked;
  final VoidCallback onEdit;
  final VoidCallback onLock;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Guide: $label',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            IconButton(
              tooltip: 'Andika nafasi kamili',
              icon: const Icon(AppIcons.edit, size: 18),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: locked ? 'Fungua guide' : 'Funga guide',
              icon: Icon(locked ? AppIcons.lock : AppIcons.unlock, size: 18),
              onPressed: onLock,
            ),
            IconButton(
              tooltip: 'Futa guide',
              icon: const Icon(AppIcons.trash, size: 18),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomBar extends StatelessWidget {
  const _ZoomBar({
    required this.percent,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onFitAll,
    required this.onPreset,
    required this.locked,
    required this.onToggleLock,
  });

  final int percent;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final VoidCallback onFitAll;
  final ValueChanged<double> onPreset;

  /// Mwonekano umefungwa (hakuna pan/zoom kwa vidole au scroll).
  final bool locked;
  final VoidCallback onToggleLock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Punguza (Cmd + scroll)',
              icon: const Icon(AppIcons.zoomOut, size: 20),
              onPressed: onZoomOut,
            ),
            PopupMenuButton<double>(
              tooltip: 'Kiwango cha zoom',
              onSelected: onPreset,
              itemBuilder: (_) => [
                for (final z in [0.25, 0.5, 1.0, 2.0, 4.0])
                  PopupMenuItem(value: z, child: Text('${(z * 100).round()}%')),
              ],
              child: SizedBox(
                width: 52,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Kuza',
              icon: const Icon(AppIcons.zoomIn, size: 20),
              onPressed: onZoomIn,
            ),
            IconButton(
              tooltip: 'Tosha skrini hii',
              icon: const Icon(AppIcons.fit, size: 20),
              onPressed: onFit,
            ),
            IconButton(
              tooltip: 'Onyesha skrini zote',
              icon: const Icon(AppIcons.screens, size: 20),
              onPressed: onFitAll,
            ),
            IconButton(
              tooltip: locked
                  ? 'Fungua mwonekano (ruhusu kusogeza/zoom)'
                  : 'Funga mwonekano (usisogee ukihariri)',
              isSelected: locked,
              style: IconButton.styleFrom(
                foregroundColor: locked ? scheme.onPrimary : null,
                backgroundColor: locked ? scheme.primary : null,
              ),
              icon: Icon(locked ? AppIcons.lock : AppIcons.unlock, size: 20),
              onPressed: onToggleLock,
            ),
          ],
        ),
      ),
    );
  }
}
