import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../canvas/geometry.dart';
import '../canvas/layout.dart';
import '../canvas/snapping.dart';
import '../icons/app_icons.dart';
import '../models/reference_image.dart';
import '../models/ui_element.dart';
import '../state/editor_controller.dart';
import 'canvas_painters.dart';
import 'device_preview.dart' show SafeAreaGuides;
import 'element_view.dart';

/// Snapping tolerance in SCREEN pixels (the same at any zoom).
const snapTolerancePx = 6.0;

/// How close (screen px) a hovering pen must be to show an element's handles.
const penReachPx = 24.0;

/// The workspace: all of the project's artboards are shown together, can
/// be moved, and each has its own elements. Rulers, guides, grid and
/// snapping all use a single [CanvasTransform].
class DesignCanvas extends StatefulWidget {
  const DesignCanvas({super.key, required this.controller});

  final EditorController controller;

  @override
  State<DesignCanvas> createState() => _DesignCanvasState();
}

/// What is being dragged right now.
sealed class _Drag {}

class _MoveDrag extends _Drag {
  _MoveDrag(this.start, this.pointer, this.targets);
  final Map<String, Rect> start;
  final Offset pointer; // artboard coordinates
  final SnapTargets targets;
  bool recorded = false;
}

class _ResizeDrag extends _Drag {
  _ResizeDrag(this.starts, this.start, this.pointer, this.targets, this.handle);

  /// Rectangles of the elements being resized; more than one when a
  /// multi-selection or group is scaled together.
  final Map<String, Rect> starts;

  /// The handle being dragged: a corner or the middle of an edge.
  final Alignment handle;

  /// Bounds of [starts] when the drag began.
  final Rect start;
  final Offset pointer;
  final SnapTargets targets;
  bool recorded = false;
}

/// Moving ([handle] == null) or resizing the reference image.
class _ReferenceDrag extends _Drag {
  _ReferenceDrag(this.start, this.pointer, this.handle);
  final Rect start;
  final Offset pointer;
  final Alignment? handle;
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

  /// A guide dragged out of a ruler (not added yet).
  ({Axis axis, double position, bool overCanvas})? _newGuide;
  String? _selectedGuide;
  Offset? _lastGuidePointer;
  bool _guideDragRecorded = false;

  final _cursor = ValueNotifier<Offset?>(null);
  String? _hoverId;
  bool _alt = false;

  /// Element the pen is hovering on or near: its resize handles show
  /// before the pen touches the screen.
  String? _nearId;

  /// Where the pen hovers over the artboard while drawing (artboard units).
  Offset? _penCursor;

  /// Fingers on the canvas (pointer → position, for pinch).
  final _touches = <int, Offset>{};
  bool _pinching = false;

  /// The pointer pulling a new guide out of a ruler.
  int? _rulerPointer;

  /// Devices that may edit the canvas. In pen mode a finger doesn't edit
  /// (so a palm can't move things by accident); two fingers = zoom/pan.
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

  /// Alt (Option) shows distances without moving anything.
  bool _onKey(KeyEvent event) {
    final alt = HardwareKeyboard.instance.isAltPressed;
    if (alt != _alt && mounted) setState(() => _alt = alt);
    return false;
  }

  // ---------- Coordinates ----------

  Offset _canvasLocal(Offset global) {
    final box = _stackKey.currentContext!.findRenderObject()! as RenderBox;
    return box.globalToLocal(global);
  }

  Offset _world(Offset global) => _view!.toWorld(_canvasLocal(global));

  Offset get _origin => c.page.position ?? Offset.zero;

  /// Position inside the current artboard.
  Offset _local(Offset global) => _world(global) - _origin;

  /// Show resize handles on the element under or near a hovering pen.
  void _penHover(PointerHoverEvent event, CanvasTransform view) {
    String? near;
    if (_drag == null &&
        (event.kind == PointerDeviceKind.stylus ||
            event.kind == PointerDeviceKind.invertedStylus)) {
      final p = view.toWorld(event.localPosition) - _origin;
      final reach = penReachPx / view.scale;
      near = c.page.visibleElements
          .toList()
          .reversed
          .where((e) => !e.locked && e.rect.inflate(reach).contains(p))
          .firstOrNull
          ?.id;
    }
    if (near != _nearId) setState(() => _nearId = near);
  }

  bool get _snapOn {
    final keys = HardwareKeyboard.instance;
    // Ctrl/Cmd while dragging = turn snapping off for now
    return v.snap && !keys.isControlPressed && !keys.isMetaPressed;
  }

  SnapTargets _targets(Set<String> exclude) {
    final p = c.page;
    final grid = p.grid;
    return SnapTargets(
      artboard: p.size,
      others: [
        for (final e in p.visibleElements)
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

  // ---------- Moving elements ----------

  void _focusPage(int index) {
    if (index != c.pageIndex) c.selectPage(index);
  }

  void _tapElement(int pageIndex, UiElement e) {
    _focusPage(pageIndex);
    setState(() => _selectedGuide = null);
    if (HardwareKeyboard.instance.isShiftPressed) {
      c.toggleSelect(e.id);
    } else if (c.selectedIds.contains(e.id) && c.selectedIds.length > 1) {
      // Tapping a selected element again makes it the key object
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

  void _beginResize(UiElement e, Alignment handle, Offset global) {
    // A hover handle can belong to an element that isn't selected yet
    if (!c.selectedIds.contains(e.id)) c.select(e.id);
    _drag = _ResizeDrag(
      {e.id: e.rect},
      e.rect,
      _local(global),
      _targets({e.id}),
      handle,
    );
  }

  /// Resize the whole selection (or group) by its bounding box.
  void _beginSelectionResize(Alignment handle, Offset global) {
    final starts = {
      for (final e in c.selectedElements)
        if (!e.locked && !e.hidden) e.id: e.rect,
    };
    if (starts.isEmpty) return;
    _drag = _ResizeDrag(
      starts,
      boundsOf(starts.values),
      _local(global),
      _targets(starts.keys.toSet()),
      handle,
    );
  }

  void _updateResize(Offset global) {
    if (_pinching) return;
    final d = _drag;
    if (d is! _ResizeDrag) return;
    if (!d.recorded) {
      c.checkpoint();
      d.recorded = true;
    }
    final raw = resizeRect(
      d.start,
      d.handle,
      _local(global) - d.pointer,
      keepAspect: HardwareKeyboard.instance.isShiftPressed,
    );
    final snapped = _snapOn
        ? snapRect(
            raw,
            d.targets,
            snapTolerancePx / _view!.scale,
            handle: d.handle,
          )
        : SnapResult(raw, const []);
    c.setRects(
      d.starts.length == 1
          ? {d.starts.keys.single: snapped.rect}
          : c.scaledSelection(d.starts, d.start, snapped.rect),
      record: false,
    );
    setState(() => _lines = v.smartGuides ? snapped.lines : const []);
  }

  // ---------- Reference image ----------

  void _beginReferenceDrag(Alignment? handle, Offset global) {
    final r = c.page.reference;
    if (r == null) return;
    _drag = _ReferenceDrag(r.rectIn(c.page.size), _local(global), handle);
  }

  void _updateReferenceDrag(Offset global) {
    final d = _drag;
    final r = c.page.reference;
    if (d is! _ReferenceDrag || r == null || _pinching) return;
    if (!d.recorded) {
      c.checkpoint();
      d.recorded = true;
    }
    final delta = _local(global) - d.pointer;
    final h = d.handle;
    final rect = h == null
        ? d.start.shift(delta)
        : resizeRect(
            d.start,
            h,
            delta,
            // Corners keep the picture's proportions
            keepAspect: h.x != 0 && h.y != 0,
            minSize: const Size(20, 20),
          );
    c.setReference(
      r.copyWith(fit: ReferenceFit.custom, rect: tidyRect(rect)),
      record: false,
    );
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

  // ---------- Marquee (multi-select by dragging) ----------

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

  // ---------- Zoom and pan ----------

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

  /// Bring the current artboard to the center if it is out of view.
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
    // Dropping a guide back on the ruler deletes it
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
        title: Text(g.vertical ? 'Vertical guide (X)' : 'Horizontal guide (Y)'),
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text)),
            child: const Text('Apply'),
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

  /// Resize the artboard (e.g. make it taller for a long screen
  /// that scrolls in "Run").
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

  // ---------- Two fingers: zoom and pan ----------

  void _touchDown(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch) return;
    _touches[e.pointer] = e.localPosition;
    if (_touches.length == 2) {
      // A two-finger gesture cancels any edit in progress
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
        // When a new artboard is added, show it
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

        // Alt: inspect distances without moving
        var measures = _measures;
        if (_alt && _drag == null && selBounds != null && v.showDistances) {
          final hovered = page.elements
              .where((e) => e.id == _hoverId && !c.selectedIds.contains(e.id))
              .firstOrNull;
          measures = hovered != null
              ? measureBetween(selBounds, hovered.rect)
              : measureDistances(selBounds, [
                  for (final e in page.visibleElements)
                    if (!c.selectedIds.contains(e.id)) e.rect,
                ], page.size);
        }

        return Listener(
          onPointerHover: (e) {
            _cursor.value = view.toWorld(e.localPosition);
            _penHover(e, view);
          },
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
            // Pen/mouse on empty space = pan the view. A single finger
            // only pans outside pen mode.
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
                  if (c.penTool)
                    Positioned(
                      top: v.showRulers ? 36 : 12,
                      left: 0,
                      right: 0,
                      child: Center(child: _PenBar(controller: c)),
                    ),
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

  /// "X = 120" relative to the ruler origin.
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
          shape: d.data.shape,
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
                  // Background: tap = clear selection; drag = marquee
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
                  _referenceLayer(p, onTop: false),
                  // The grid sits on the background, beneath the elements
                  // (always present so toggling it doesn't shift them)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: p.grid.anyVisible
                            ? GridPainter(p.grid, scale)
                            : null,
                      ),
                    ),
                  ),
                  for (final e in p.visibleElements)
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
                  _referenceLayer(p, onTop: true),
                  if (p.safeArea case final insets? when p.showSafeArea)
                    Positioned.fill(child: SafeAreaGuides(insets: insets)),
                  if (active && c.penTool) _penLayer(p, scale),
                  if (active &&
                      c.adjustingReference &&
                      (p.reference?.visible ?? false))
                    _referenceEditor(p, scale),
                  if (active && c.selectedIds.length > 1)
                    if (c.selectedElements.where((e) => !e.locked && !e.hidden)
                        case final movable when movable.isNotEmpty)
                      _selectionBox(
                        boundsOf(movable.map((e) => e.rect)),
                        scale,
                        group: c.selectionIsGroup,
                      ),
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
          // Make it taller / wider
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

  /// The screen's reference image, beneath or above the elements. Always
  /// present (possibly empty) so the element widgets never shift.
  Widget _referenceLayer(DesignPage p, {required bool onTop}) {
    final r = p.reference;
    final show = r != null && r.visible && r.onTop == onTop;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (show)
              Positioned.fromRect(
                rect: r.rectIn(p.size),
                child: Opacity(
                  opacity: r.opacity,
                  child: Image.memory(
                    r.bytes,
                    key: const ValueKey('reference-image'),
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
              ),
          ],
        ),
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
    // Bigger grips for a pen than for a mouse
    final handle = (v.penMode ? 20 : 12) / scale;
    // Extra room around the element so the handles outside its bounds
    // can be tapped (hit testing doesn't reach outside the parent).
    final pad = handle;
    final hovered =
        _nearId == e.id &&
        pageIndex == c.pageIndex &&
        !selected &&
        !e.locked &&
        c.selectedIds.length <= 1;
    final resizable = (selected && single && !e.locked) || hovered;

    return Positioned.fromRect(
      rect: e.rect.inflate(pad),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: pad,
            top: pad,
            right: pad,
            bottom: pad,
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
                      onPanStart: (d) =>
                          _beginMove(pageIndex, e, d.globalPosition),
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
                    ),
                ],
                if (hovered)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: primary.withValues(alpha: 0.6),
                            width: 1 / scale,
                          ),
                        ),
                      ),
                    ),
                  ),
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
          ),
          if (resizable)
            for (final h in _handles)
              _gripAt(
                h,
                e.rect.size,
                pad: pad,
                handle: handle,
                scale: scale,
                color: primary,
                onStart: (g) => _beginResize(e, h, g),
              ),
        ],
      ),
    );
  }

  /// A resize grip at [h] on a box of [size] that sits [pad] inside its
  /// parent.
  Widget _gripAt(
    Alignment h,
    Size size, {
    required double pad,
    required double handle,
    required double scale,
    required Color color,
    required void Function(Offset global) onStart,
    void Function(Offset global)? onUpdate,
  }) {
    return Positioned(
      left: pad + (h.x + 1) / 2 * size.width - handle / 2,
      top: pad + (h.y + 1) / 2 * size.height - handle / 2,
      width: handle,
      height: handle,
      // Grips react after a few px (the default pen slop is 36 px)
      // and measure from where the pen touched down.
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(gestureSettings: const DeviceGestureSettings(touchSlop: 2)),
        child: GestureDetector(
          supportedDevices: _editDevices,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (d) => onStart(d.globalPosition),
          onPanUpdate: (d) => (onUpdate ?? _updateResize)(d.globalPosition),
          onPanEnd: (_) => _endDrag(),
          child: MouseRegion(
            cursor: _resizeCursor(h),
            child: _Grip(handle: h, color: color, scale: scale),
          ),
        ),
      ),
    );
  }

  /// The pen tool's drawing surface: taps add points; tapping the first
  /// point closes the shape.
  Widget _penLayer(DesignPage p, double scale) {
    final draft = c.penDraft;
    final closeReach = 12 / scale;
    bool nearFirst(Offset at) =>
        draft.length >= 3 && (at - draft.first).distance <= closeReach;
    return Positioned.fill(
      key: const ValueKey('pen-layer'),
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        onHover: (e) => setState(() => _penCursor = e.localPosition),
        onExit: (_) => setState(() => _penCursor = null),
        child: GestureDetector(
          supportedDevices: _editDevices,
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final at = d.localPosition;
            nearFirst(at) ? c.finishPen(closed: true) : c.addPenPoint(at);
          },
          child: CustomPaint(
            painter: PenDraftPainter(
              draft,
              cursor: _penCursor,
              scale: scale,
              color: Theme.of(context).colorScheme.primary,
              closing: _penCursor != null && nearFirst(_penCursor!),
            ),
          ),
        ),
      ),
    );
  }

  /// Move/resize frame over the reference image while adjusting it.
  Widget _referenceEditor(DesignPage p, double scale) {
    const color = Color(0xFFF79009);
    final rect = p.reference!.rectIn(p.size);
    final handle = (v.penMode ? 20 : 12) / scale;
    final pad = handle;
    return Positioned.fromRect(
      key: const ValueKey('reference-editor'),
      rect: rect.inflate(pad),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: pad,
            top: pad,
            right: pad,
            bottom: pad,
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  gestureSettings: const DeviceGestureSettings(touchSlop: 2),
                ),
                child: GestureDetector(
                  supportedDevices: _editDevices,
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onPanStart: (d) =>
                      _beginReferenceDrag(null, d.globalPosition),
                  onPanUpdate: (d) => _updateReferenceDrag(d.globalPosition),
                  onPanEnd: (_) => _endDrag(),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: color, width: 1.5 / scale),
                    ),
                  ),
                ),
              ),
            ),
          ),
          for (final h in _handles)
            _gripAt(
              h,
              rect.size,
              pad: pad,
              handle: handle,
              scale: scale,
              color: color,
              onStart: (g) => _beginReferenceDrag(h, g),
              onUpdate: _updateReferenceDrag,
            ),
        ],
      ),
    );
  }

  /// The box around a multi-selection or group, with grips that scale
  /// everything inside it together.
  Widget _selectionBox(Rect bounds, double scale, {required bool group}) {
    final primary = Theme.of(context).colorScheme.primary;
    final handle = (v.penMode ? 20 : 12) / scale;
    final pad = handle;
    return Positioned.fromRect(
      key: const ValueKey('selection-box'),
      rect: bounds.inflate(pad),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: pad,
            top: pad,
            right: pad,
            bottom: pad,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: primary.withValues(alpha: group ? 1 : 0.7),
                    width: (group ? 1.5 : 1) / scale,
                  ),
                ),
              ),
            ),
          ),
          for (final h in _handles)
            _gripAt(
              h,
              bounds.size,
              pad: pad,
              handle: handle,
              scale: scale,
              color: primary,
              onStart: (g) => _beginSelectionResize(h, g),
            ),
        ],
      ),
    );
  }

  /// 8 handles: 4 corners and the middle of each edge.
  /// (Edge handles change only the width or the height.)
  static const _handles = [
    Alignment.topLeft,
    Alignment.topCenter,
    Alignment.topRight,
    Alignment.centerRight,
    Alignment.bottomRight,
    Alignment.bottomCenter,
    Alignment.bottomLeft,
    Alignment.centerLeft,
  ];

  static MouseCursor _resizeCursor(Alignment h) => switch ((h.x, h.y)) {
    (0, _) => SystemMouseCursors.resizeUpDown,
    (_, 0) => SystemMouseCursors.resizeLeftRight,
    (-1, -1) || (1, 1) => SystemMouseCursors.resizeUpLeftDownRight,
    _ => SystemMouseCursors.resizeUpRightDownLeft,
  };

  /// Guides of the current artboard: the line plus a grab area.
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

  /// A guide line across the whole view (like Figma/Illustrator).
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

  /// Pulling a guide out of a ruler. Uses raw pointer events (not the
  /// gesture arena) so the drag is never cancelled, and the guide is placed
  /// where the pen/finger is lifted.
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
      // Corner: drag to set a new ruler origin; double-tap to reset
      Positioned(
        key: const ValueKey('ruler-corner'),
        left: 0,
        top: 0,
        width: rulerSize,
        height: rulerSize,
        child: Tooltip(
          message: 'Drag to set the ruler origin · double-tap to reset',
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
              tooltip: 'Enter an exact position',
              icon: const Icon(AppIcons.edit, size: 18),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: locked ? 'Unlock guide' : 'Lock guide',
              icon: Icon(locked ? AppIcons.lock : AppIcons.unlock, size: 18),
              onPressed: onLock,
            ),
            IconButton(
              tooltip: 'Delete guide',
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

  /// The view is locked (no pan/zoom with fingers or scroll).
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
              tooltip: 'Zoom out (Cmd + scroll)',
              icon: const Icon(AppIcons.zoomOut, size: 20),
              onPressed: onZoomOut,
            ),
            PopupMenuButton<double>(
              tooltip: 'Zoom level',
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
              tooltip: 'Zoom in',
              icon: const Icon(AppIcons.zoomIn, size: 20),
              onPressed: onZoomIn,
            ),
            IconButton(
              tooltip: 'Fit this screen',
              icon: const Icon(AppIcons.fit, size: 20),
              onPressed: onFit,
            ),
            IconButton(
              tooltip: 'Show all screens',
              icon: const Icon(AppIcons.screens, size: 20),
              onPressed: onFitAll,
            ),
            IconButton(
              tooltip: locked
                  ? 'Unlock view (allow pan/zoom)'
                  : 'Lock view (keep still while editing)',
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

/// The visible part of a resize handle: a square on corners, and a bar
/// along the edge on edge midpoints (they change only width or height).
class _Grip extends StatelessWidget {
  const _Grip({required this.handle, required this.color, required this.scale});

  final Alignment handle;
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final corner = handle.x != 0 && handle.y != 0;
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular((corner ? 2 : 4) / scale),
        border: Border.all(color: color, width: 1.5 / scale),
      ),
    );
    if (corner) return Padding(padding: EdgeInsets.all(2 / scale), child: box);
    // Left/right edges: tall bar; top/bottom edges: wide bar
    return FractionallySizedBox(
      widthFactor: handle.x == 0 ? 1 : 0.45,
      heightFactor: handle.x == 0 ? 0.45 : 1,
      child: box,
    );
  }
}

/// Hints and buttons while the pen tool is on (for tablets without a
/// keyboard as well).
class _PenBar extends StatelessWidget {
  const _PenBar({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final n = c.penDraft.length;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Icon(AppIcons.bezier, size: 18, color: scheme.primary),
            Text(
              n == 0
                  ? 'Pen: tap to place points'
                  : n < 3
                  ? '$n points · keep tapping'
                  : '$n points · tap the first point to close',
            ),
            TextButton(
              onPressed: n > 0 ? c.undoPenPoint : null,
              child: const Text('Undo point'),
            ),
            TextButton(
              onPressed: n >= 2 ? () => c.finishPen(closed: false) : null,
              child: const Text('Finish line'),
            ),
            TextButton(
              onPressed: n >= 3 ? () => c.finishPen(closed: true) : null,
              child: const Text('Close shape'),
            ),
            IconButton(
              tooltip: 'Exit pen tool (Esc)',
              visualDensity: VisualDensity.compact,
              icon: const Icon(AppIcons.close, size: 18),
              onPressed: () => c.setPenTool(false),
            ),
          ],
        ),
      ),
    );
  }
}
