import 'dart:math';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../canvas/alignment.dart';
import '../canvas/geometry.dart';
import '../canvas/layout.dart';
import '../icons/icon_style.dart';
import '../models/device_frame.dart';
import '../models/reference_image.dart';
import '../models/ui_element.dart';

typedef _Snapshot = (List<DesignPage>, int);

/// All editor state: screens, the selected element and undo/redo.
class EditorController extends ChangeNotifier {
  EditorController({DeviceFrame? device}) {
    pages = [
      DesignPage(
        id: _newId(),
        name: 'Screen 1',
        device: device ?? defaultDevice,
        position: Offset.zero,
      ),
    ];
  }

  late List<DesignPage> pages;
  int pageIndex = 0;

  /// The selection's key object: the last one tapped.
  String? selectedId;

  /// All selected elements (Shift + tap to add).
  Set<String> selectedIds = {};

  /// View preferences (rulers, guides, snapping…). Not part of
  /// undo, but saved with the project.
  ViewSettings view = const ViewSettings();

  /// Space between artboards when they are laid out automatically.
  static const artboardGap = 96.0;

  int _seq = 0;
  final _undo = <_Snapshot>[];
  final _redo = <_Snapshot>[];

  String _newId() => 'e${_seq++}';

  DesignPage get page => pages[pageIndex];

  UiElement? get selected =>
      page.elements.where((e) => e.id == selectedId).firstOrNull;

  List<UiElement> get selectedElements =>
      page.elements.where((e) => selectedIds.contains(e.id)).toList();

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  // ---------- History ----------

  /// Save the current state before a change so it can be undone.
  void checkpoint() {
    _undo.add((List.of(pages), pageIndex));
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  void undo() => _restore(_undo, _redo);
  void redo() => _restore(_redo, _undo);

  void _restore(List<_Snapshot> from, List<_Snapshot> to) {
    if (from.isEmpty) return;
    to.add((List.of(pages), pageIndex));
    final (p, i) = from.removeLast();
    pages = p;
    pageIndex = i;
    _clearSelection();
    notifyListeners();
  }

  void _clearSelection() {
    selectedId = null;
    selectedIds = {};
  }

  void _setPage(DesignPage p) {
    pages = [...pages]..[pageIndex] = p;
    notifyListeners();
  }

  // ---------- Elements ----------

  void select(String? id) {
    // Picking an element ends reference adjusting
    if (id != null) adjustingReference = false;
    final ids = id == null ? <String>{} : _withGroups({id});
    if (selectedId == id && setEquals(selectedIds, ids)) return;
    selectedId = id;
    selectedIds = ids;
    notifyListeners();
  }

  /// [ids] plus every element grouped with one of them.
  Set<String> _withGroups(Iterable<String> ids) {
    final groups = {
      for (final e in page.elements)
        if (ids.contains(e.id) && e.groupId != null) e.groupId,
    };
    return {
      ...ids,
      for (final e in page.elements)
        if (groups.contains(e.groupId)) e.id,
    };
  }

  /// Shift + tap: add to or remove from the selection. The last element
  /// added becomes the key object.
  void toggleSelect(String id) {
    // A grouped element brings its whole group along
    final group = _withGroups({id});
    if (selectedIds.contains(id)) {
      selectedIds = {...selectedIds}..removeAll(group);
      if (group.contains(selectedId)) selectedId = selectedIds.lastOrNull;
    } else {
      selectedIds = {...selectedIds, ...group};
      selectedId = id;
    }
    notifyListeners();
  }

  /// Set the key object without changing the selection.
  void setKeyObject(String id) {
    if (!selectedIds.contains(id)) return;
    selectedId = id;
    notifyListeners();
  }

  void selectAll() {
    selectedIds = {for (final e in page.visibleElements) e.id};
    selectedId = page.visibleElements.lastOrNull?.id;
    notifyListeners();
  }

  /// Select every element touching [area] (artboard coordinates).
  void selectInRect(Rect area, {bool add = false}) {
    final hits = [
      for (final e in page.visibleElements)
        if (e.rect.overlaps(area)) e.id,
    ];
    selectedIds = {if (add) ...selectedIds, ..._withGroups(hits)};
    selectedId = hits.lastOrNull ?? (add ? selectedId : null);
    notifyListeners();
  }

  /// Add an element; [at] is its top-left corner inside the screen.
  void addElement(
    ElementType type, {
    Offset? at,
    String? text,
    IconStyle? iconStyle,
    ElementShape? shape,
  }) {
    checkpoint();
    final screen = page.size;
    var size = type.defaultSize;
    if (type.fullWidth) size = Size(screen.width, size.height);
    size = Size(min(size.width, screen.width), min(size.height, screen.height));

    var pos =
        at ??
        Offset(
          (screen.width - size.width) / 2,
          (screen.height - size.height) / 2,
        );
    if (type == ElementType.appBar && at == null) pos = Offset.zero;
    if (type == ElementType.navBar && at == null) {
      pos = Offset(0, screen.height - size.height);
    }
    if (type.fullWidth) pos = Offset(0, pos.dy);
    pos = Offset(
      pos.dx.clamp(0, screen.width - size.width).roundToDouble(),
      pos.dy.clamp(0, screen.height - size.height).roundToDouble(),
    );

    var el = UiElement.create(type, _newId(), pos & size);
    el = el.copyWith(text: text, iconStyle: iconStyle, shape: shape);
    // Circles and polygons start out square
    if (shape != null && shape != ElementShape.rectangle) {
      final side = min(el.rect.width, el.rect.height);
      el = el.copyWith(rect: el.rect.topLeft & Size(side, side));
    }
    selectedId = el.id;
    selectedIds = {el.id};
    _setPage(page.copyWith(elements: [...page.elements, el]));
  }

  void updateElement(UiElement el, {bool record = true}) {
    if (record) checkpoint();
    _setPage(
      page.copyWith(
        elements: [for (final e in page.elements) e.id == el.id ? el : e],
      ),
    );
  }

  void deleteSelected() {
    if (selectedIds.isEmpty) return;
    checkpoint();
    final ids = selectedIds;
    _clearSelection();
    _setPage(
      page.copyWith(
        elements: page.elements.where((e) => !ids.contains(e.id)).toList(),
      ),
    );
  }

  void duplicateSelected() {
    final els = selectedElements;
    if (els.isEmpty) return;
    checkpoint();
    // Copies of a group form a new group
    final groups = <String, String>{};
    final copies = [
      for (final el in els)
        el.copyWith(
          id: _newId(),
          rect: el.rect.shift(const Offset(16, 16)),
          groupId: el.groupId == null
              ? null
              : groups.putIfAbsent(el.groupId!, () => 'k${_seq++}'),
        ),
    ];
    selectedIds = {for (final e in copies) e.id};
    selectedId = copies.last.id;
    _setPage(page.copyWith(elements: [...page.elements, ...copies]));
  }

  /// Move the selected elements (locked ones stay put).
  void nudgeSelected(Offset delta) {
    final moves = {
      for (final e in selectedElements)
        if (!e.locked) e.id: e.rect.shift(delta),
    };
    if (moves.isEmpty) return;
    setRects(moves);
  }

  /// Change several elements' rectangles in one undo step.
  void setRects(Map<String, Rect> rects, {bool record = true}) {
    if (rects.isEmpty) return;
    if (record) checkpoint();
    _setPage(
      page.copyWith(
        elements: [
          for (final e in page.elements)
            if (rects[e.id] case final r?) e.copyWith(rect: r) else e,
        ],
      ),
    );
  }

  // ---------- Pen tool ----------

  /// The pen tool is on: taps on the screen add points to [penDraft].
  bool penTool = false;

  /// Points placed so far (artboard coordinates); not saved.
  List<Offset> penDraft = const [];

  void setPenTool(bool on) {
    if (penTool == on) return;
    penTool = on;
    penDraft = const [];
    if (on) {
      select(null);
      adjustingReference = false;
    }
    notifyListeners();
  }

  void addPenPoint(Offset p) {
    penDraft = [...penDraft, Offset(tidy(p.dx), tidy(p.dy))];
    notifyListeners();
  }

  /// Remove the last placed point (Backspace).
  void undoPenPoint() {
    if (penDraft.isEmpty) return;
    penDraft = penDraft.sublist(0, penDraft.length - 1);
    notifyListeners();
  }

  /// Turn the draft into a pen shape and select it. A closed shape needs
  /// 3+ points, an open line 2+. The tool stays on for the next shape.
  void finishPen({required bool closed}) {
    final pts = penDraft;
    if (pts.length < (closed ? 3 : 2)) return;
    checkpoint();
    var bounds = boundsOf(
      pts.map((p) => Rect.fromCenter(center: p, width: 0, height: 0)),
    );
    // A straight horizontal/vertical line still needs some size
    bounds = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      max(bounds.width, 1),
      max(bounds.height, 1),
    );
    final el = UiElement.create(ElementType.path, _newId(), bounds).copyWith(
      closed: closed,
      points: [
        for (final p in pts)
          // 4 decimals: precise to well under a pixel on any screen
          Offset(
            _frac((p.dx - bounds.left) / bounds.width),
            _frac((p.dy - bounds.top) / bounds.height),
          ),
      ],
    );
    penDraft = const [];
    selectedId = el.id;
    selectedIds = {el.id};
    _setPage(page.copyWith(elements: [...page.elements, el]));
  }

  double _frac(double v) => (v * 10000).roundToDouble() / 10000;

  // ---------- Groups ----------

  /// The selection can be grouped (2+ elements, not already one group).
  bool get canGroup => selectedIds.length >= 2 && !selectionIsGroup;

  /// The selection is exactly one whole group.
  bool get selectionIsGroup {
    final groups = {for (final e in selectedElements) e.groupId};
    return groups.length == 1 &&
        groups.single != null &&
        setEquals(_withGroups(selectedIds), selectedIds);
  }

  /// Any selected element belongs to a group.
  bool get selectionHasGroup => selectedElements.any((e) => e.groupId != null);

  /// Group the selected elements (Cmd/Ctrl + G). Groups inside the
  /// selection are merged into the new one.
  void groupSelected() {
    if (selectedIds.length < 2) return;
    checkpoint();
    final id = 'k${_seq++}';
    _setPage(
      page.copyWith(
        elements: [
          for (final e in page.elements)
            selectedIds.contains(e.id) ? e.copyWith(groupId: id) : e,
        ],
      ),
    );
  }

  /// Ungroup the selected elements (Shift + Cmd/Ctrl + G); they stay selected.
  void ungroupSelected() {
    if (!selectionHasGroup) return;
    checkpoint();
    _setPage(
      page.copyWith(
        elements: [
          for (final e in page.elements)
            selectedIds.contains(e.id) ? e.copyWith(clearGroup: true) : e,
        ],
      ),
    );
  }

  /// Scale the selected (unlocked) elements from [from] to [to], keeping
  /// their positions and sizes relative to the selection bounds.
  Map<String, Rect> scaledSelection(
    Map<String, Rect> start,
    Rect from,
    Rect to,
  ) {
    final sx = from.width == 0 ? 1.0 : to.width / from.width;
    final sy = from.height == 0 ? 1.0 : to.height / from.height;
    return {
      for (final MapEntry(key: id, value: r) in start.entries)
        id: Rect.fromLTWH(
          tidy(to.left + (r.left - from.left) * sx),
          tidy(to.top + (r.top - from.top) * sy),
          tidy(r.width * sx),
          tidy(r.height * sy),
        ),
    };
  }

  void toggleLock(String id) {
    final el = page.elements.firstWhere((e) => e.id == id);
    updateElement(el.copyWith(locked: !el.locked));
  }

  /// Hide or show an element. A hidden element is also deselected.
  void toggleHidden(String id) {
    final el = page.elements.firstWhere((e) => e.id == id);
    updateElement(el.copyWith(hidden: !el.hidden));
    if (!el.hidden && selectedIds.contains(id)) {
      toggleSelect(id);
    }
  }

  // ---------- Alignment and distribution ----------

  /// Elements alignment can move (the unlocked ones).
  Map<String, Rect> get _movable => {
    for (final e in selectedElements)
      if (!e.locked) e.id: e.rect,
  };

  Rect get artboardRect => Offset.zero & page.size;

  bool get canAlign => selectedIds.isNotEmpty;
  bool get canDistribute => _movable.length >= 3;
  bool get canSpace => _movable.length >= 2;

  /// The alignment target for [ViewSettings.alignTo]. A single element
  /// (or a key object alone) is aligned to the artboard.
  (Rect, String?) _alignTarget() {
    final sel = selectedElements;
    switch (view.alignTo) {
      case AlignTo.selection when sel.length > 1:
        return (boundsOf(sel.map((e) => e.rect)), null);
      case AlignTo.keyObject when sel.length > 1 && selected != null:
        return (selected!.rect, selectedId);
      case _:
        // Artboard, parent frame (the parent frame is the artboard — frames
        // aren't nested), or a single element
        return (artboardRect, null);
    }
  }

  void align(AlignOp op) {
    if (!canAlign) return;
    final (target, keyId) = _alignTarget();
    setRects(alignRects(_movable, op, target, keyId: keyId));
  }

  void distribute(DistributeOp op) {
    if (!canDistribute) return;
    setRects(distributeRects(_movable, op));
  }

  void distributeSpacingOn(Axis axis) {
    if (!canDistribute) return;
    setRects(distributeSpacing(_movable, axis));
  }

  void applyGapOn(Axis axis, [double? gap]) {
    if (!canSpace) return;
    final g = gap ?? (axis == Axis.horizontal ? view.hGap : view.vGap);
    setRects(applyGap(_movable, axis, g));
  }

  void tidySelection() {
    if (!canSpace) return;
    setRects(tidyUp(_movable, hGap: view.hGap, vGap: view.vGap));
  }

  void smartArrangeSelection() {
    if (!canSpace) return;
    setRects(smartArrange(_movable));
  }

  // ---------- View, guides, grid ----------

  void setView(ViewSettings v) {
    view = v;
    notifyListeners();
  }

  /// Add a guide to the current artboard; returns its id.
  String addGuide(Axis axis, double position) {
    final g = Guide(id: 'g${_seq++}', axis: axis, position: tidy(position));
    updatePage(page.copyWith(guides: [...page.guides, g]));
    return g.id;
  }

  void moveGuide(String id, double position, {bool record = true}) {
    final g = page.guides.where((g) => g.id == id).firstOrNull;
    if (g == null || g.locked || view.guidesLocked) return;
    _setGuide(g.copyWith(position: tidy(position)), record: record);
  }

  void toggleGuideLock(String id) {
    final g = page.guides.firstWhere((g) => g.id == id);
    _setGuide(g.copyWith(locked: !g.locked));
  }

  void _setGuide(Guide g, {bool record = true}) => updatePage(
    page.copyWith(guides: [for (final o in page.guides) o.id == g.id ? g : o]),
    record: record,
  );

  void deleteGuide(String id) => updatePage(
    page.copyWith(guides: page.guides.where((g) => g.id != id).toList()),
  );

  void clearGuides() {
    if (page.guides.isEmpty) return;
    updatePage(page.copyWith(guides: const []));
  }

  void setGrid(GridSettings grid, {bool record = true}) =>
      updatePage(page.copyWith(grid: grid), record: record);

  /// Set or change the current screen's reference image (null removes it).
  void setReference(ReferenceImage? reference, {bool record = true}) {
    if (reference == null) adjustingReference = false;
    updatePage(
      page.copyWith(reference: reference, clearReference: reference == null),
      record: record,
    );
  }

  /// The reference image can be moved and resized on the canvas
  /// (not saved: it's an editing mode).
  bool adjustingReference = false;

  void setAdjustingReference(bool on) {
    if (adjustingReference == on) return;
    adjustingReference = on;
    if (on) select(null);
    notifyListeners();
  }

  void setRulerOrigin(Offset origin) =>
      updatePage(page.copyWith(rulerOrigin: origin));

  void resetRulerOrigin() {
    if (page.rulerOrigin == Offset.zero) return;
    setRulerOrigin(Offset.zero);
  }

  // ---------- Laying out artboards on the canvas ----------

  /// Place artboards that have no position: in a row right of the others.
  void _placeArtboards() {
    double? right;
    for (final p in pages) {
      if (p.position case final pos?) {
        right = max(right ?? double.negativeInfinity, pos.dx + p.size.width);
      }
    }
    pages = [
      for (final p in pages)
        if (p.position != null)
          p
        else
          () {
            final x = right == null ? 0.0 : right! + artboardGap;
            right = x + p.size.width;
            return p.copyWith(position: Offset(x, 0));
          }(),
    ];
  }

  /// Move artboard [index] to [position] (world).
  void moveArtboard(int index, Offset position, {bool record = true}) {
    if (record) checkpoint();
    pages = [...pages]
      ..[index] = pages[index].copyWith(
        position: Offset(
          position.dx.roundToDouble(),
          position.dy.roundToDouble(),
        ),
      );
    notifyListeners();
  }

  /// Moves the selection above every other layer.
  void bringToFront() => _reorder(toFront: true);

  /// Moves the selection beneath every other layer.
  void sendToBack() => _reorder(toFront: false);

  void _reorder({required bool toFront}) {
    if (selectedIds.isEmpty) return;
    checkpoint();
    final picked = [
      for (final e in page.elements)
        if (selectedIds.contains(e.id)) e,
    ];
    final rest = [
      for (final e in page.elements)
        if (!selectedIds.contains(e.id)) e,
    ];
    _setPage(
      page.copyWith(
        elements: toFront ? [...rest, ...picked] : [...picked, ...rest],
      ),
    );
  }

  /// Whether the selection can go one layer up / down.
  bool get canMoveForward => _canStep(forward: true);
  bool get canMoveBackward => _canStep(forward: false);

  bool _canStep({required bool forward}) {
    final list = page.elements;
    for (var i = 0; i < list.length; i++) {
      if (!selectedIds.contains(list[i].id)) continue;
      final j = forward ? i + 1 : i - 1;
      if (j >= 0 && j < list.length && !selectedIds.contains(list[j].id)) {
        return true;
      }
    }
    return false;
  }

  /// Moves the selection one layer up (towards the front).
  void moveForward() => _step(forward: true);

  /// Moves the selection one layer down (towards the back).
  void moveBackward() => _step(forward: false);

  void _step({required bool forward}) {
    if (!_canStep(forward: forward)) return;
    checkpoint();
    final list = [...page.elements];
    // Walk from the side we move towards so a block of selected layers
    // moves together, one step
    final order = forward
        ? [for (var i = list.length - 2; i >= 0; i--) i]
        : [for (var i = 1; i < list.length; i++) i];
    for (final i in order) {
      final j = forward ? i + 1 : i - 1;
      if (selectedIds.contains(list[i].id) &&
          !selectedIds.contains(list[j].id)) {
        final moved = list[i];
        list[i] = list[j];
        list[j] = moved;
      }
    }
    _setPage(page.copyWith(elements: list));
  }

  /// Drag-to-reorder in the Layers list, which shows the top layer first.
  /// [from] and [to] are list positions, [to] counted after [from] is
  /// taken out.
  void reorderLayer(int from, int to) {
    final list = page.elements.reversed.toList();
    if (from == to || from < 0 || from >= list.length) return;
    checkpoint();
    list.insert(to.clamp(0, list.length - 1), list.removeAt(from));
    _setPage(page.copyWith(elements: list.reversed.toList()));
  }

  // ---------- Project (save / load) ----------

  Map<String, dynamic> toJson() => {
    'app': 'rexa_ui_studio',
    'version': 1,
    'pageIndex': pageIndex,
    'view': view.toJson(),
    'pages': [for (final p in pages) p.toJson()],
  };

  /// Load a project from JSON. On failure the current state is unchanged
  /// and a [FormatException] is thrown.
  ///
  /// [record] = true allows undo (e.g. when the user imports JSON);
  /// otherwise the history is cleared (e.g. when the app opens).
  void loadJson(Map<String, dynamic> json, {bool record = false}) {
    final List<DesignPage> loaded;
    try {
      loaded = [
        for (final p in json['pages'] as List)
          DesignPage.fromJson(p as Map<String, dynamic>),
      ];
    } catch (e) {
      throw FormatException('Invalid project: $e');
    }
    if (loaded.isEmpty) {
      throw const FormatException('The project has no screens');
    }

    if (record) {
      checkpoint();
    } else {
      _undo.clear();
      _redo.clear();
    }
    pages = loaded;
    pageIndex = ((json['pageIndex'] as int?) ?? 0).clamp(0, loaded.length - 1);
    _clearSelection();
    if (json['view'] case final Map<String, dynamic> v) {
      view = ViewSettings.fromJson(v);
    }
    _placeArtboards();

    // Make sure new ids don't clash with the loaded ones
    final ids = [
      for (final p in loaded) ...[
        p.id,
        for (final e in p.elements) ...[e.id, ?e.groupId],
        for (final g in p.guides) g.id,
      ],
    ];
    _seq = ids
        .map((id) => int.tryParse(id.substring(1)) ?? 0)
        .fold(0, (a, b) => max(a, b + 1));
    notifyListeners();
  }

  /// Start a new empty project (can be undone).
  void resetProject() {
    checkpoint();
    pages = [
      DesignPage(
        id: _newId(),
        name: 'Screen 1',
        device: page.device,
        position: Offset.zero,
      ),
    ];
    pageIndex = 0;
    _clearSelection();
    notifyListeners();
  }

  // ---------- Screens ----------

  void addPage(DeviceFrame device) {
    checkpoint();
    pages = [
      ...pages,
      DesignPage(
        id: _newId(),
        name: 'Screen ${pages.length + 1}',
        device: device,
      ),
    ];
    _placeArtboards();
    pageIndex = pages.length - 1;
    _clearSelection();
    notifyListeners();
  }

  void selectPage(int index) {
    if (index == pageIndex) return;
    pageIndex = index;
    _clearSelection();
    notifyListeners();
  }

  void deletePage(int index) {
    if (pages.length == 1) return;
    checkpoint();
    pages = [...pages]..removeAt(index);
    pageIndex = min(pageIndex, pages.length - 1);
    _clearSelection();
    notifyListeners();
  }

  void updatePage(DesignPage p, {bool record = true}) {
    if (record) checkpoint();
    _setPage(p);
  }

  /// Add an artboard made by ArtboardFactory (New Design).
  void addArtboard(DesignPage Function(String id) build) {
    checkpoint();
    pages = [...pages, build(_newId()).copyWith()];
    _placeArtboards();
    pageIndex = pages.length - 1;
    _clearSelection();
    notifyListeners();
  }

  /// Change the device model. A custom size is dropped so the new device's
  /// verified frame is used (except for "Custom size").
  void setDevice(DeviceFrame device) {
    if (device == page.device) return;
    _resizeScreen(
      page.copyWith(
        device: device,
        clearCustomSize: device.id != customDeviceId,
      ),
    );
  }

  /// Switch between the inner and outer screen of a foldable.
  void toggleFold() {
    if (foldPartner(page.device) case final other?) setDevice(other);
  }

  /// Reset the artboard to the device size.
  void resetSize() {
    if (page.customSize == null) return;
    _resizeScreen(page.copyWith(clearCustomSize: true));
  }

  void setShowSafeArea(bool show) {
    if (show == page.showSafeArea) return;
    updatePage(page.copyWith(showSafeArea: show));
  }

  void setLandscape(bool landscape) {
    if (landscape == page.landscape) return;
    _resizeScreen(page.copyWith(landscape: landscape));
  }

  /// [size] is the artboard size in portrait.
  void setCustomSize(Size size, {bool record = true}) =>
      _resizeScreen(page.copyWith(customSize: size), record: record);

  /// Resize the screen; the app bar and bottom nav follow the new width,
  /// and the bottom nav stays at the bottom.
  void _resizeScreen(DesignPage next, {bool record = true}) {
    final old = page.size;
    final size = next.size;
    updatePage(
      next.copyWith(
        elements: [
          for (final e in next.elements)
            if (e.type == ElementType.appBar)
              e.copyWith(
                rect: Rect.fromLTWH(0, e.rect.top, size.width, e.rect.height),
              )
            else if (e.type == ElementType.navBar)
              e.copyWith(
                rect: Rect.fromLTWH(
                  0,
                  size.height - (old.height - e.rect.top),
                  size.width,
                  e.rect.height,
                ),
              )
            else
              e,
        ],
      ),
      record: record,
    );
  }
}
