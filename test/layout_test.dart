import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rexa_ui_studio/canvas/alignment.dart';
import 'package:rexa_ui_studio/canvas/geometry.dart';
import 'package:rexa_ui_studio/canvas/layout.dart';
import 'package:rexa_ui_studio/canvas/snapping.dart';
import 'package:rexa_ui_studio/main.dart';
import 'package:rexa_ui_studio/models/device_frame.dart';
import 'package:rexa_ui_studio/models/reference_image.dart';
import 'package:rexa_ui_studio/models/ui_element.dart';
import 'package:rexa_ui_studio/screens/export_image_dialog.dart';
import 'package:rexa_ui_studio/screens/run_screen.dart';
import 'package:rexa_ui_studio/services/project_storage.dart';
import 'package:rexa_ui_studio/state/editor_controller.dart';
import 'package:rexa_ui_studio/widgets/canvas_painters.dart';
import 'package:rexa_ui_studio/widgets/design_canvas.dart';
import 'package:rexa_ui_studio/widgets/element_view.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const rects = {
    'a': Rect.fromLTWH(10, 10, 40, 20),
    'b': Rect.fromLTWH(100, 50, 20, 60),
    'c': Rect.fromLTWH(60, 200, 80, 10),
  };
  const box = Rect.fromLTWH(0, 0, 400, 800);

  group('alignment', () {
    test('left, center, right, top, bottom, center both ways', () {
      expect(
        alignRects(rects, AlignOp.left, box).values.map((r) => r.left),
        everyElement(0),
      );
      expect(
        alignRects(rects, AlignOp.right, box).values.map((r) => r.right),
        everyElement(400),
      );
      expect(
        alignRects(rects, AlignOp.hCenter, box).values.map((r) => r.center.dx),
        everyElement(200),
      );
      expect(
        alignRects(rects, AlignOp.top, box).values.map((r) => r.top),
        everyElement(0),
      );
      expect(
        alignRects(rects, AlignOp.bottom, box).values.map((r) => r.bottom),
        everyElement(800),
      );
      expect(
        alignRects(rects, AlignOp.vCenter, box).values.map((r) => r.center.dy),
        everyElement(400),
      );
      final both = alignRects(rects, AlignOp.centerBoth, box);
      expect(both.values.map((r) => r.center), everyElement(box.center));
      // The size doesn't change
      for (final id in rects.keys) {
        expect(both[id]!.size, rects[id]!.size);
      }
    });

    test('the key object stays put, the others align to it', () {
      final out = alignRects(rects, AlignOp.left, rects['b']!, keyId: 'b');
      expect(out['b'], rects['b']);
      expect(out['a']!.left, 100);
      expect(out['c']!.left, 100);
    });

    test('distribute and equal spacing', () {
      final d = distributeRects(rects, DistributeOp.top);
      expect(d['a']!.top, 10);
      expect(d['c']!.top, 200);
      expect(d['b']!.top, 105);

      final s = distributeSpacing(rects, Axis.vertical);
      final sorted = s.values.toList()..sort((x, y) => x.top.compareTo(y.top));
      final g1 = sorted[1].top - sorted[0].bottom;
      final g2 = sorted[2].top - sorted[1].bottom;
      expect(g1, closeTo(g2, 0.01));
    });

    test('applyGap and tidy up', () {
      final g = applyGap(rects, Axis.horizontal, 16);
      final sorted = g.values.toList()
        ..sort((x, y) => x.left.compareTo(y.left));
      for (var i = 1; i < sorted.length; i++) {
        expect(sorted[i].left - sorted[i - 1].right, closeTo(16, 0.01));
      }
      final t = tidyUp(rects, hGap: 8, vGap: 8);
      expect(t, hasLength(3));
      for (final id in rects.keys) {
        expect(t[id]!.size, rects[id]!.size);
      }
    });

    test('controller: align to selection / artboard / key object + undo', () {
      final c = EditorController();
      c.addElement(ElementType.button, at: const Offset(10, 100));
      final a = c.selectedId!;
      c.addElement(ElementType.button, at: const Offset(60, 300));
      final b = c.selectedId!;
      c.select(a);
      c.toggleSelect(b);
      expect(c.selectedIds, {a, b});

      c.align(AlignOp.left);
      expect(c.page.elements.map((e) => e.rect.left), everyElement(10));
      c.undo();
      expect(c.page.elements.firstWhere((e) => e.id == b).rect.left, 60);

      // undo clears the selection — select again
      c.select(a);
      c.toggleSelect(b);
      c.setView(c.view.copyWith(alignTo: AlignTo.artboard));
      c.align(AlignOp.right);
      expect(
        c.page.elements.map((e) => e.rect.right),
        everyElement(c.page.size.width),
      );

      c.setView(c.view.copyWith(alignTo: AlignTo.keyObject));
      c.setKeyObject(b);
      final keyRect = c.page.elements.firstWhere((e) => e.id == b).rect;
      c.align(AlignOp.top);
      expect(c.page.elements.firstWhere((e) => e.id == b).rect, keyRect);
      expect(
        c.page.elements.firstWhere((e) => e.id == a).rect.top,
        keyRect.top,
      );
    });
  });

  group('rulers and zoom', () {
    test('ruler steps at 25/50/100/200/400% zoom', () {
      final steps = {
        for (final z in [0.25, 0.5, 1.0, 2.0, 4.0]) z: rulerStep(z),
      };
      expect(steps, {0.25: 250, 0.5: 200, 1.0: 100, 2.0: 50, 4.0: 20});
      for (final MapEntry(key: z, value: s) in steps.entries) {
        expect(s * z, greaterThanOrEqualTo(56));
      }
    });

    test('world ↔ screen round-trips at every zoom', () {
      for (final z in [0.25, 0.5, 1.0, 2.0, 4.0]) {
        final t = const CanvasTransform(
          1,
          Offset(30, 40),
        ).zoomAt(z, const Offset(500, 300));
        const p = Offset(123.5, 456.25);
        final back = t.toWorld(t.toScreen(p));
        expect(back.dx, closeTo(p.dx, 1e-9));
        expect(back.dy, closeTo(p.dy, 1e-9));
        // The focal point doesn't move while zooming
        final focalWorld = const CanvasTransform(
          1,
          Offset(30, 40),
        ).toWorld(const Offset(500, 300));
        expect(t.toScreen(focalWorld).dx, closeTo(500, 1e-9));
      }
      final fit = CanvasTransform.fit(
        const Rect.fromLTWH(0, 0, 400, 800),
        const Size(1000, 1000),
      );
      expect(
        fit.rectToScreen(const Rect.fromLTWH(0, 0, 400, 800)).center,
        const Offset(500, 500),
      );
    });
  });

  group('guides, grid and snapping', () {
    test('guide: add, move, lock, delete, undo, save', () {
      final c = EditorController();
      final id = c.addGuide(Axis.vertical, 24);
      c.moveGuide(id, 40);
      expect(c.page.guides.single.position, 40);
      c.toggleGuideLock(id);
      c.moveGuide(id, 80);
      expect(c.page.guides.single.position, 40, reason: 'locked');
      c.toggleGuideLock(id);
      c.addGuide(Axis.horizontal, 100);
      c.setGrid(const GridSettings(show: true, size: 10));
      c.setView(c.view.copyWith(showRulers: false, guideColor: Colors.red));

      final restored = EditorController()
        ..loadJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(restored.page.guides, hasLength(2));
      expect(restored.page.guides.first.position, 40);
      expect(restored.page.grid.show, isTrue);
      expect(restored.page.grid.size, 10);
      expect(restored.view.showRulers, isFalse);
      // New ids don't clash with the saved ones
      final next = restored.addGuide(Axis.vertical, 1);
      expect(restored.page.guides.where((g) => g.id == next), hasLength(1));

      c.deleteGuide(id);
      expect(c.page.guides, hasLength(1));
      c.undo();
      expect(c.page.guides, hasLength(2));
      c.clearGuides();
      expect(c.page.guides, isEmpty);
    });

    test('snap only within tolerance (6 screen px at any zoom)', () {
      final t = SnapTargets(
        artboard: const Size(400, 800),
        others: const [Rect.fromLTWH(200, 300, 50, 50)],
        guideX: const [120],
      );
      for (final z in [0.25, 0.5, 1.0, 2.0, 4.0]) {
        final tol = 6 / z;
        // Near a guide (within tolerance) → snaps
        final near = snapRect(
          Rect.fromLTWH(120 + tol * 0.8, 500, 10, 10),
          t,
          tol,
        );
        expect(near.rect.left, 120, reason: 'zoom $z');
        expect(near.lines, isNotEmpty);
        // Outside the tolerance → doesn't move
        final far = Rect.fromLTWH(120 + tol * 1.5, 500, 10, 10);
        expect(snapRect(far, t, tol).rect.left, far.left, reason: 'zoom $z');
      }
      // The top edge snaps to another element
      final obj = snapRect(const Rect.fromLTWH(10, 302, 20, 20), t, 6);
      expect(obj.rect.top, 300);
    });

    test('grid: stretch columns and snap to grid', () {
      const cols = TrackGrid(enabled: true, count: 4, gutter: 16, margin: 16);
      final tracks = cols.tracks(400);
      expect(tracks, hasLength(4));
      expect(tracks.first.$1, 16);
      expect(tracks.last.$2, closeTo(384, 1e-9));

      final t = SnapTargets(
        artboard: const Size(400, 800),
        grid: 8,
        objects: false,
        artboardEdges: false,
      );
      final r = snapRect(const Rect.fromLTWH(13, 21, 30, 30), t, 6);
      expect(r.rect.left % 8, 0);
      expect(r.rect.top % 8, 0);
    });
  });

  group('transform', () {
    const start = Rect.fromLTWH(100, 100, 200, 100);

    test('each handle moves only its own edges', () {
      expect(
        resizeRect(start, Alignment.centerLeft, const Offset(-30, 50)),
        const Rect.fromLTRB(70, 100, 300, 200),
      );
      expect(
        resizeRect(start, Alignment.topCenter, const Offset(40, -20)),
        const Rect.fromLTRB(100, 80, 300, 200),
      );
      expect(
        resizeRect(start, Alignment.centerRight, const Offset(25, 0)),
        const Rect.fromLTRB(100, 100, 325, 200),
      );
      expect(
        resizeRect(start, Alignment.bottomCenter, const Offset(0, 30)),
        const Rect.fromLTRB(100, 100, 300, 230),
      );
      expect(
        resizeRect(start, Alignment.topLeft, const Offset(10, 10)),
        const Rect.fromLTRB(110, 110, 300, 200),
      );
    });

    test('minimum size and Shift (aspect ratio)', () {
      final tiny = resizeRect(
        start,
        Alignment.centerLeft,
        const Offset(500, 0),
      );
      expect(tiny.width, minElementSize.width);
      expect(tiny.right, start.right, reason: 'the right edge stays put');

      final kept = resizeRect(
        start,
        Alignment.bottomRight,
        const Offset(100, 0),
        keepAspect: true,
      );
      expect(kept.width / kept.height, closeTo(2, 0.01));
      expect(kept.topLeft, start.topLeft);
    });

    test('left/top edge snapping while resizing', () {
      final t = SnapTargets(
        artboard: const Size(400, 800),
        guideX: const [60],
        guideY: const [40],
        objects: false,
        artboardEdges: false,
      );
      final r = snapRect(
        const Rect.fromLTRB(63, 43, 300, 200),
        t,
        6,
        handle: Alignment.topLeft,
      ).rect;
      expect(r, const Rect.fromLTRB(60, 40, 300, 200));
      // Edge midpoint: the other axis doesn't snap
      final edge = snapRect(
        const Rect.fromLTRB(63, 43, 300, 200),
        t,
        6,
        handle: Alignment.centerLeft,
      ).rect;
      expect(edge, const Rect.fromLTRB(60, 43, 300, 200));
    });
  });

  group('shapes', () {
    test('every shape has a border and code; JSON keeps the shape', () {
      for (final shape in ElementShape.values) {
        expect(shape.border(12, const Size(100, 80)), isA<ShapeBorder>());
        expect(shape.code(12, const Size(100, 80)), isNotEmpty);
      }
      expect(
        ElementShape.ellipse.border(0, const Size(10, 10)),
        isA<OvalBorder>(),
      );
      expect(
        ElementShape.star.border(0, const Size(10, 10)),
        isA<StarBorder>(),
      );

      final c = EditorController()
        ..addElement(ElementType.container, shape: ElementShape.star);
      final e = c.selected!;
      expect(e.shape, ElementShape.star);
      expect(e.rect.width, e.rect.height, reason: 'a new shape is square');
      final back = UiElement.fromJson(
        jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>,
      );
      expect(back.shape, ElementShape.star);
      // Rectangle is the default and isn't written to JSON
      c.addElement(ElementType.container);
      expect(c.selected!.toJson().containsKey('shape'), isFalse);
    });
  });

  group('artboards', () {
    test('adding a device adds an artboard instead of changing one', () {
      final c = EditorController();
      final first = c.page.id;
      c.addPage(deviceById('pixel-10'));
      c.addPage(deviceById('galaxy-s25'));
      expect(c.pages, hasLength(3));
      expect(c.pages.first.id, first);
      final xs = c.pages.map((p) => p.position!.dx).toList();
      expect(xs, orderedEquals([...xs]..sort()));
      for (var i = 1; i < c.pages.length; i++) {
        expect(
          c.pages[i].position!.dx,
          greaterThanOrEqualTo(
            c.pages[i - 1].position!.dx + c.pages[i - 1].size.width,
          ),
          reason: 'artboards don\'t overlap',
        );
      }
      c.moveArtboard(1, const Offset(-500, 900));
      final restored = EditorController()
        ..loadJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(restored.pages[1].position, const Offset(-500, 900));
    });
  });

  testWidgets('Backspace in the width field does not delete the element', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = EditorController()..addElement(ElementType.button);
    final info = await ProjectStorage().create('Backspace', c.toJson());
    await tester.pumpWidget(const RexaStudioApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text(info.name));
    await tester.pumpAndSettle();

    // Select the button with the pen (pen mode: fingers don't edit)
    await tester.tap(
      find.text('Continue').first,
      kind: PointerDeviceKind.stylus,
    );
    await tester.pumpAndSettle();
    final width = find.widgetWithText(TextField, 'Width');
    expect(width, findsOneWidget);
    await tester.tap(width);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, 'Width'),
      findsOneWidget,
      reason: 'the element still exists',
    );

    // Backspace changed 160 → 16; restore the width so the button is tappable
    await tester.enterText(find.widgetWithText(TextField, 'Width'), '160');
    await tester.pumpAndSettle();

    // Back on the canvas, Delete removes the element
    await tester.tap(
      find.descendant(
        of: find.byType(DesignCanvas),
        matching: find.text('Continue'),
      ),
      kind: PointerDeviceKind.stylus,
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Width'), findsNothing);
  });

  testWidgets('dragging from the top and left rulers creates guides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = EditorController();
    final info = await ProjectStorage().create('Guides', c.toJson());
    await tester.pumpWidget(const RexaStudioApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text(info.name));
    await tester.pumpAndSettle();

    Finder savedGuides() => find.byWidgetPredicate(
      (w) =>
          w is Positioned &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('guide-g'),
    );
    final top = tester.getCenter(find.byKey(const ValueKey('ruler-top')));
    final left = tester.getCenter(find.byKey(const ValueKey('ruler-left')));

    // Top ruler → drag down → horizontal guide (Y)
    var g = await tester.startGesture(top, kind: PointerDeviceKind.stylus);
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guide-new')), findsNothing);
    expect(savedGuides(), findsNWidgets(1));

    // Left ruler → drag right → vertical guide (X)
    g = await tester.startGesture(left, kind: PointerDeviceKind.stylus);
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(20, 0));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guide-new')), findsNothing);
    expect(savedGuides(), findsNWidgets(2));
  });

  testWidgets('pen mode: a finger doesn\'t edit, 2 fingers zoom, lock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = EditorController()..addElement(ElementType.button);
    expect(c.view.penMode, isTrue, reason: 'Android → pen mode by default');
    final info = await ProjectStorage().create('Pen', c.toJson());
    await tester.pumpWidget(const RexaStudioApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text(info.name));
    await tester.pumpAndSettle();

    final button = find.text('Continue').first;
    final before = tester.getTopLeft(button);

    // A palm/single finger neither selects nor moves the button
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Width'), findsNothing);
    await tester.drag(button, const Offset(80, 60));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(button), before);

    // The pen selects
    await tester.tap(button, kind: PointerDeviceKind.stylus);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Width'), findsOneWidget);

    String zoom() => tester
        .widgetList<Text>(find.textContaining(RegExp(r'^\d+%$')))
        .first
        .data!;
    Future<void> pinch(double spread) async {
      final center = tester.getCenter(find.byType(DesignCanvas));
      final a = await tester.startGesture(center - const Offset(40, 0));
      final b = await tester.startGesture(center + const Offset(40, 0));
      for (var i = 0; i < 5; i++) {
        await a.moveBy(Offset(-spread / 5, 0));
        await b.moveBy(Offset(spread / 5, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
    }

    final z0 = zoom();
    await pinch(80);
    final z1 = zoom();
    expect(
      int.parse(z1.replaceAll('%', '')),
      greaterThan(int.parse(z0.replaceAll('%', ''))),
    );
    expect(tester.getTopLeft(button), isNot(before), reason: 'the view zoomed');

    // Lock view: pinch doesn't change the zoom
    await tester.tap(find.byTooltip('Lock view (keep still while editing)'));
    await tester.pumpAndSettle();
    await pinch(80);
    expect(zoom(), z1);
  });

  testWidgets('a reference image is drawn on its artboard', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = EditorController()..addElement(ElementType.button);
    c.setReference(
      ReferenceImage(
        // 1×1 transparent PNG
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
        ),
        pixelSize: const Size(1, 2),
      ),
    );
    final info = await ProjectStorage().create('Reference', c.toJson());
    await tester.pumpWidget(const RexaStudioApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text(info.name));
    await tester.pumpAndSettle();

    final image = find.byKey(const ValueKey('reference-image'));
    expect(image, findsOneWidget);
    // Beneath the elements by default
    final order = tester.allWidgets.toList();
    expect(
      order.indexOf(tester.widget(image)),
      lessThan(order.indexWhere((w) => w is ElementView)),
    );
  });

  testWidgets('the grid is painted beneath the elements', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = EditorController()..addElement(ElementType.container);
    c.setGrid(c.page.grid.copyWith(show: true));
    final info = await ProjectStorage().create('Grid', c.toJson());
    await tester.pumpWidget(const RexaStudioApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text(info.name));
    await tester.pumpAndSettle();

    final order = tester.allWidgets.toList();
    final grid = order.indexWhere(
      (w) => w is CustomPaint && w.painter is GridPainter,
    );
    final element = order.indexWhere((w) => w is ElementView);
    expect(grid, isNonNegative);
    expect(grid, lessThan(element), reason: 'painted first = underneath');
  });

  testWidgets('pen hover shows handles; an edge grip resizes untapped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = EditorController()..addElement(ElementType.container);
    final info = await ProjectStorage().create('Hover', c.toJson());
    await tester.pumpWidget(const RexaStudioApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text(info.name));
    await tester.pumpAndSettle();

    final box = find.byType(ElementView).first;
    final grips = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_Grip',
    );
    expect(grips, findsNothing);

    // The pen hovers just outside the right edge: handles appear
    final rect = tester.getRect(box);
    final pen = await tester.createGesture(kind: PointerDeviceKind.stylus);
    await pen.addPointer(location: Offset.zero);
    await pen.moveTo(rect.centerRight + const Offset(8, 0));
    await tester.pumpAndSettle();
    expect(grips, findsNWidgets(8));

    // Drag the right-edge grip: only the width changes
    await pen.down(rect.centerRight);
    for (var i = 0; i < 4; i++) {
      await pen.moveBy(const Offset(15, 0));
      await tester.pump();
    }
    await pen.up();
    await tester.pumpAndSettle();
    final after = tester.getRect(box);
    expect(after.width, greaterThan(rect.width + 30));
    expect(after.height, closeTo(rect.height, 0.5));
    expect(after.left, closeTo(rect.left, 0.5));
    await pen.removePointer();
  });

  testWidgets('panels collapse and expand; full canvas', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final info = await ProjectStorage().create(
      'Paneli',
      EditorController().toJson(),
    );
    await tester.pumpWidget(const RexaStudioApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text(info.name));
    await tester.pumpAndSettle();

    final canvas = find.byType(DesignCanvas);
    final full = tester.getSize(canvas).width;
    expect(find.text('Text'), findsOneWidget); // components panel

    await tester.tap(find.byTooltip('Collapse panel (Cmd/Ctrl + \\)'));
    await tester.pumpAndSettle();
    expect(find.text('Text'), findsNothing);
    expect(tester.getSize(canvas).width, greaterThan(full));

    // Tapping a rail tab expands the panel again
    await tester.tap(find.text('Components'));
    await tester.pumpAndSettle();
    expect(find.text('Text'), findsOneWidget);

    // Full canvas: both panels collapse, then come back
    await tester.tap(
      find.byTooltip('Full canvas — collapse panels (Cmd/Ctrl + \\)'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Properties'), findsNothing);
    final wide = tester.getSize(canvas).width;
    expect(wide, greaterThan(full + 450));
    await tester.tap(find.byTooltip('Show panels (Cmd/Ctrl + \\)'));
    await tester.pumpAndSettle();
    expect(tester.getSize(canvas).width, full);
  });

  testWidgets('Export image: the PNG size follows the scale', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final device = deviceById('iphone-17-pro');
    final page = DesignPage(id: 'p1', name: 'Login', device: device);
    expect(imageFileName(page, 2), 'LoginScreen@2x.png');

    await tester.pumpWidget(
      MaterialApp(home: ExportImageDialog(pages: [page])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ArtboardPicture), findsOneWidget);
    expect(find.textContaining('804 × 1748 px'), findsOneWidget);

    await tester.tap(find.text('3x'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1206 × 2622 px'), findsOneWidget);
    expect(find.textContaining('LoginScreen@3x.png'), findsOneWidget);
  });

  testWidgets('Run: scroll down and follow a link', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final device = deviceById('iphone-17-pro');
    final second = DesignPage(id: 'p2', name: 'Pili', device: device);
    final tall = DesignPage(
      id: 'p1',
      name: 'Kwanza',
      device: device,
      customSize: Size(device.size.width, device.size.height * 2),
      elements: [
        UiElement.create(
          ElementType.button,
          'b1',
          const Rect.fromLTWH(20, 100, 200, 48),
        ).copyWith(text: 'Nenda', link: 'p2'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: RunScreen(pages: [tall, second])),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('scroll down'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.text('Nenda'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
  });
}
