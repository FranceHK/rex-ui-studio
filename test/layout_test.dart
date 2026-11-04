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
import 'package:rexa_ui_studio/models/ui_element.dart';
import 'package:rexa_ui_studio/screens/run_screen.dart';
import 'package:rexa_ui_studio/services/project_storage.dart';
import 'package:rexa_ui_studio/state/editor_controller.dart';
import 'package:rexa_ui_studio/widgets/design_canvas.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const rects = {
    'a': Rect.fromLTWH(10, 10, 40, 20),
    'b': Rect.fromLTWH(100, 50, 20, 60),
    'c': Rect.fromLTWH(60, 200, 80, 10),
  };
  const box = Rect.fromLTWH(0, 0, 400, 800);

  group('alignment', () {
    test('kushoto, katikati, kulia, juu, chini, katikati pande zote', () {
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
      // Ukubwa haubadiliki
      for (final id in rects.keys) {
        expect(both[id]!.size, rects[id]!.size);
      }
    });

    test('key object haisogei, wengine wanaipanga', () {
      final out = alignRects(rects, AlignOp.left, rects['b']!, keyId: 'b');
      expect(out['b'], rects['b']);
      expect(out['a']!.left, 100);
      expect(out['c']!.left, 100);
    });

    test('distribute na nafasi sawa', () {
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

    test('applyGap na tidy up', () {
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

      // undo inaondoa uteuzi — chagua tena
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

  group('rulers na zoom', () {
    test('hatua za ruler kwa zoom 25/50/100/200/400%', () {
      final steps = {
        for (final z in [0.25, 0.5, 1.0, 2.0, 4.0]) z: rulerStep(z),
      };
      expect(steps, {0.25: 250, 0.5: 200, 1.0: 100, 2.0: 50, 4.0: 20});
      for (final MapEntry(key: z, value: s) in steps.entries) {
        expect(s * z, greaterThanOrEqualTo(56));
      }
    });

    test('world ↔ screen ni sawa kwenye kila zoom', () {
      for (final z in [0.25, 0.5, 1.0, 2.0, 4.0]) {
        final t = const CanvasTransform(
          1,
          Offset(30, 40),
        ).zoomAt(z, const Offset(500, 300));
        const p = Offset(123.5, 456.25);
        final back = t.toWorld(t.toScreen(p));
        expect(back.dx, closeTo(p.dx, 1e-9));
        expect(back.dy, closeTo(p.dy, 1e-9));
        // Pointi ya focal haisogei wakati wa zoom
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

  group('guides, gridi na snapping', () {
    test('guide: ongeza, sogeza, funga, futa, undo, hifadhi', () {
      final c = EditorController();
      final id = c.addGuide(Axis.vertical, 24);
      c.moveGuide(id, 40);
      expect(c.page.guides.single.position, 40);
      c.toggleGuideLock(id);
      c.moveGuide(id, 80);
      expect(c.page.guides.single.position, 40, reason: 'imefungwa');
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
      // Id mpya hazigongani na zilizohifadhiwa
      final next = restored.addGuide(Axis.vertical, 1);
      expect(restored.page.guides.where((g) => g.id == next), hasLength(1));

      c.deleteGuide(id);
      expect(c.page.guides, hasLength(1));
      c.undo();
      expect(c.page.guides, hasLength(2));
      c.clearGuides();
      expect(c.page.guides, isEmpty);
    });

    test('snap ndani ya tolerance tu (6px skrini kwa kila zoom)', () {
      final t = SnapTargets(
        artboard: const Size(400, 800),
        others: const [Rect.fromLTWH(200, 300, 50, 50)],
        guideX: const [120],
      );
      for (final z in [0.25, 0.5, 1.0, 2.0, 4.0]) {
        final tol = 6 / z;
        // Karibu na guide (ndani ya tolerance) → inasnap
        final near = snapRect(
          Rect.fromLTWH(120 + tol * 0.8, 500, 10, 10),
          t,
          tol,
        );
        expect(near.rect.left, 120, reason: 'zoom $z');
        expect(near.lines, isNotEmpty);
        // Nje ya tolerance → haisogei
        final far = Rect.fromLTWH(120 + tol * 1.5, 500, 10, 10);
        expect(snapRect(far, t, tol).rect.left, far.left, reason: 'zoom $z');
      }
      // Ukingo wa juu unasnap kwenye kitu kingine
      final obj = snapRect(const Rect.fromLTWH(10, 302, 20, 20), t, 6);
      expect(obj.rect.top, 300);
    });

    test('gridi: safu za stretch na snap kwenye gridi', () {
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

  group('artboards', () {
    test('kuongeza kifaa kunaongeza artboard, hakubadilishi', () {
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
          reason: 'artboard hazipishani',
        );
      }
      c.moveArtboard(1, const Offset(-500, 900));
      final restored = EditorController()
        ..loadJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(restored.pages[1].position, const Offset(-500, 900));
    });
  });

  testWidgets('Backspace kwenye kisanduku cha upana haifuti kipengele', (
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

    // Chagua kitufe kwa kalamu (hali ya kalamu: kidole hakihariri)
    await tester.tap(
      find.text('Endelea').first,
      kind: PointerDeviceKind.stylus,
    );
    await tester.pumpAndSettle();
    final width = find.widgetWithText(TextField, 'Upana');
    expect(width, findsOneWidget);
    await tester.tap(width);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, 'Upana'),
      findsOneWidget,
      reason: 'kipengele bado kipo',
    );

    // Backspace ilibadilisha 160 → 16; rudisha upana ili kitufe kibonyezeke
    await tester.enterText(find.widgetWithText(TextField, 'Upana'), '160');
    await tester.pumpAndSettle();

    // Ukirudi kwenye canvas, Delete inafuta kipengele
    await tester.tap(
      find.descendant(
        of: find.byType(DesignCanvas),
        matching: find.text('Endelea'),
      ),
      kind: PointerDeviceKind.stylus,
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Upana'), findsNothing);
  });

  testWidgets('kuburuta kutoka ruler ya juu na ya kushoto kunaunda guides', (
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

    // Ruler ya juu → buruta chini → guide ya mlalo (Y)
    var g = await tester.startGesture(top, kind: PointerDeviceKind.stylus);
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guide-new')), findsNothing);
    expect(savedGuides(), findsNWidgets(1));

    // Ruler ya kushoto → buruta kulia → guide wima (X)
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

  testWidgets('hali ya kalamu: kidole hakihariri, vidole 2 vinazoom, lock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = EditorController()..addElement(ElementType.button);
    expect(
      c.view.penMode,
      isTrue,
      reason: 'Android → kalamu kwa chaguo-msingi',
    );
    final info = await ProjectStorage().create('Kalamu', c.toJson());
    await tester.pumpWidget(const RexaStudioApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text(info.name));
    await tester.pumpAndSettle();

    final button = find.text('Endelea').first;
    final before = tester.getTopLeft(button);

    // Kiganja/kidole kimoja: hakichagui wala kusogeza kitufe
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Upana'), findsNothing);
    await tester.drag(button, const Offset(80, 60));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(button), before);

    // Kalamu inachagua
    await tester.tap(button, kind: PointerDeviceKind.stylus);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Upana'), findsOneWidget);

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
    expect(
      tester.getTopLeft(button),
      isNot(before),
      reason: 'mwonekano umezoom',
    );

    // Funga mwonekano: pinch haibadilishi zoom
    await tester.tap(find.byTooltip('Funga mwonekano (usisogee ukihariri)'));
    await tester.pumpAndSettle();
    await pinch(80);
    expect(zoom(), z1);
  });

  testWidgets('Run: kushuka chini na kufuata link', (tester) async {
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
    expect(find.textContaining('shuka chini'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.text('Nenda'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Rudi'), findsOneWidget);
    await tester.tap(find.text('Rudi'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
  });
}
