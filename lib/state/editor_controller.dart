import 'dart:math';

import 'package:flutter/material.dart';

import '../canvas/alignment.dart';
import '../canvas/geometry.dart';
import '../canvas/layout.dart';
import '../icons/icon_style.dart';
import '../models/device_frame.dart';
import '../models/ui_element.dart';

typedef _Snapshot = (List<DesignPage>, int);

/// Hali yote ya editor: skrini, kipengele kilichochaguliwa na undo/redo.
class EditorController extends ChangeNotifier {
  EditorController({DeviceFrame? device}) {
    pages = [
      DesignPage(
        id: _newId(),
        name: 'Skrini 1',
        device: device ?? defaultDevice,
        position: Offset.zero,
      ),
    ];
  }

  late List<DesignPage> pages;
  int pageIndex = 0;

  /// Kipengele kikuu cha uteuzi (key object): cha mwisho kubonyezwa.
  String? selectedId;

  /// Vipengele vyote vilivyochaguliwa (Shift + bonyeza kuongeza).
  Set<String> selectedIds = {};

  /// Mapendeleo ya mwonekano (rulers, guides, snapping…). Si sehemu ya
  /// undo, lakini yanahifadhiwa na mradi.
  ViewSettings view = const ViewSettings();

  /// Nafasi kati ya artboards zinapopangwa zenyewe.
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

  // ---------- Historia ----------

  /// Hifadhi hali ya sasa kabla ya mabadiliko ili yaweze kurudishwa.
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

  // ---------- Vipengele ----------

  void select(String? id) {
    if (selectedId == id && selectedIds.length == (id == null ? 0 : 1)) {
      return;
    }
    selectedId = id;
    selectedIds = {?id};
    notifyListeners();
  }

  /// Shift + bonyeza: ongeza au toa kwenye uteuzi. Kipengele kilichoongezwa
  /// mwisho kinakuwa kipengele kikuu (key object).
  void toggleSelect(String id) {
    if (selectedIds.contains(id)) {
      selectedIds = {...selectedIds}..remove(id);
      if (selectedId == id) selectedId = selectedIds.lastOrNull;
    } else {
      selectedIds = {...selectedIds, id};
      selectedId = id;
    }
    notifyListeners();
  }

  /// Weka kipengele kikuu bila kubadilisha uteuzi.
  void setKeyObject(String id) {
    if (!selectedIds.contains(id)) return;
    selectedId = id;
    notifyListeners();
  }

  void selectAll() {
    selectedIds = {for (final e in page.elements) e.id};
    selectedId = page.elements.lastOrNull?.id;
    notifyListeners();
  }

  /// Chagua vipengele vyote vinavyogusa [area] (nafasi ya artboard).
  void selectInRect(Rect area, {bool add = false}) {
    final hits = [
      for (final e in page.elements)
        if (e.rect.overlaps(area)) e.id,
    ];
    selectedIds = {if (add) ...selectedIds, ...hits};
    selectedId = hits.lastOrNull ?? (add ? selectedId : null);
    notifyListeners();
  }

  /// Ongeza kipengele; [at] ni kona ya juu-kushoto ndani ya skrini.
  void addElement(
    ElementType type, {
    Offset? at,
    String? text,
    IconStyle? iconStyle,
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
    el = el.copyWith(text: text, iconStyle: iconStyle);
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
    final copies = [
      for (final el in els)
        el.copyWith(id: _newId(), rect: el.rect.shift(const Offset(16, 16))),
    ];
    selectedIds = {for (final e in copies) e.id};
    selectedId = copies.last.id;
    _setPage(page.copyWith(elements: [...page.elements, ...copies]));
  }

  /// Sogeza vipengele vilivyochaguliwa (vilivyofungwa havisogei).
  void nudgeSelected(Offset delta) {
    final moves = {
      for (final e in selectedElements)
        if (!e.locked) e.id: e.rect.shift(delta),
    };
    if (moves.isEmpty) return;
    setRects(moves);
  }

  /// Badilisha mistatili ya vipengele vingi kwa hatua moja ya undo.
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

  void toggleLock(String id) {
    final el = page.elements.firstWhere((e) => e.id == id);
    updateElement(el.copyWith(locked: !el.locked));
  }

  // ---------- Alignment na distribution ----------

  /// Vipengele vinavyoweza kusogezwa na alignment (visivyofungwa).
  Map<String, Rect> get _movable => {
    for (final e in selectedElements)
      if (!e.locked) e.id: e.rect,
  };

  Rect get artboardRect => Offset.zero & page.size;

  bool get canAlign => selectedIds.isNotEmpty;
  bool get canDistribute => _movable.length >= 3;
  bool get canSpace => _movable.length >= 2;

  /// Lengo la alignment kulingana na [ViewSettings.alignTo]. Kipengele
  /// kimoja (au key object bila wengine) kinapangwa dhidi ya artboard.
  (Rect, String?) _alignTarget() {
    final sel = selectedElements;
    switch (view.alignTo) {
      case AlignTo.selection when sel.length > 1:
        return (boundsOf(sel.map((e) => e.rect)), null);
      case AlignTo.keyObject when sel.length > 1 && selected != null:
        return (selected!.rect, selectedId);
      case _:
        // Artboard, parent frame (fremu mzazi ni artboard — hakuna
        // fremu zilizowekwa ndani ya nyingine), au kipengele kimoja
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

  // ---------- Mwonekano, guides, gridi ----------

  void setView(ViewSettings v) {
    view = v;
    notifyListeners();
  }

  /// Ongeza guide kwenye artboard ya sasa; inarudisha id yake.
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

  void setRulerOrigin(Offset origin) =>
      updatePage(page.copyWith(rulerOrigin: origin));

  void resetRulerOrigin() {
    if (page.rulerOrigin == Offset.zero) return;
    setRulerOrigin(Offset.zero);
  }

  // ---------- Mpangilio wa artboards kwenye canvas ----------

  /// Weka mahali artboards zisizo na nafasi: mfululizo kulia kwa zilizopo.
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

  /// Sogeza artboard [index] hadi [position] (world).
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

  void bringToFront() => _reorder(toFront: true);
  void sendToBack() => _reorder(toFront: false);

  void _reorder({required bool toFront}) {
    final el = selected;
    if (el == null) return;
    checkpoint();
    final rest = page.elements.where((e) => e.id != el.id);
    _setPage(page.copyWith(elements: toFront ? [...rest, el] : [el, ...rest]));
  }

  // ---------- Mradi (kuhifadhi / kupakia) ----------

  Map<String, dynamic> toJson() => {
    'app': 'rexa_ui_studio',
    'version': 1,
    'pageIndex': pageIndex,
    'view': view.toJson(),
    'pages': [for (final p in pages) p.toJson()],
  };

  /// Pakia mradi kutoka JSON. Ikishindikana, hali ya sasa haibadiliki
  /// na [FormatException] inarushwa.
  ///
  /// [record] = true inaruhusu undo (k.m. mtumiaji anapoleta JSON);
  /// vinginevyo historia inafutwa (k.m. app inapofunguliwa).
  void loadJson(Map<String, dynamic> json, {bool record = false}) {
    final List<DesignPage> loaded;
    try {
      loaded = [
        for (final p in json['pages'] as List)
          DesignPage.fromJson(p as Map<String, dynamic>),
      ];
    } catch (e) {
      throw FormatException('Mradi si sahihi: $e');
    }
    if (loaded.isEmpty) throw const FormatException('Mradi hauna skrini');

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

    // Hakikisha id mpya hazigongani na zilizopakiwa
    final ids = [
      for (final p in loaded) ...[
        p.id,
        for (final e in p.elements) e.id,
        for (final g in p.guides) g.id,
      ],
    ];
    _seq = ids
        .map((id) => int.tryParse(id.substring(1)) ?? 0)
        .fold(0, (a, b) => max(a, b + 1));
    notifyListeners();
  }

  /// Anza mradi mpya mtupu (unaweza kurudishwa kwa undo).
  void resetProject() {
    checkpoint();
    pages = [
      DesignPage(
        id: _newId(),
        name: 'Skrini 1',
        device: page.device,
        position: Offset.zero,
      ),
    ];
    pageIndex = 0;
    _clearSelection();
    notifyListeners();
  }

  // ---------- Skrini ----------

  void addPage(DeviceFrame device) {
    checkpoint();
    pages = [
      ...pages,
      DesignPage(
        id: _newId(),
        name: 'Skrini ${pages.length + 1}',
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

  /// Ongeza artboard iliyotengenezwa na ArtboardFactory (New Design).
  void addArtboard(DesignPage Function(String id) build) {
    checkpoint();
    pages = [...pages, build(_newId()).copyWith()];
    _placeArtboards();
    pageIndex = pages.length - 1;
    _clearSelection();
    notifyListeners();
  }

  /// Badili modeli ya kifaa. Ukubwa uliobadilishwa unaondolewa ili frame
  /// iliyothibitishwa ya kifaa kipya itumike (isipokuwa "Ukubwa maalum").
  void setDevice(DeviceFrame device) {
    if (device == page.device) return;
    _resizeScreen(
      page.copyWith(
        device: device,
        clearCustomSize: device.id != customDeviceId,
      ),
    );
  }

  /// Badili kati ya skrini ya ndani na ya nje ya kifaa kinachokunjika.
  void toggleFold() {
    if (foldPartner(page.device) case final other?) setDevice(other);
  }

  /// Rudisha artboard kwenye ukubwa wa kifaa.
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

  /// [size] ni ukubwa wa artboard ukiwa wima.
  void setCustomSize(Size size, {bool record = true}) =>
      _resizeScreen(page.copyWith(customSize: size), record: record);

  /// Badilisha ukubwa wa skrini; app bar na bottom nav zinafuata upana
  /// mpya, na bottom nav inabaki chini.
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
