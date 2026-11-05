import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rexa_ui_studio/models/reference_image.dart';
import 'package:rexa_ui_studio/models/ui_element.dart';
import 'package:rexa_ui_studio/screens/export_image_dialog.dart';
import 'package:rexa_ui_studio/services/reference_import.dart';
import 'package:rexa_ui_studio/state/editor_controller.dart';
import 'package:rexa_ui_studio/widgets/reference_section.dart';

import 'layers_test.dart' show openEditor;

/// A solid PNG of [width] × [height] px.
Future<Uint8List> pngOf(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3366FF),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  test('reference image survives a JSON round trip with its page', () {
    final c = EditorController();
    c.setReference(
      ReferenceImage(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        pixelSize: const Size(1080, 2400),
        opacity: 0.3,
        onTop: true,
        fit: ReferenceFit.fill,
      ),
    );
    final page = DesignPage.fromJson(c.page.toJson());
    final r = page.reference!;
    expect(r.bytes, [1, 2, 3, 4]);
    expect(r.pixelSize, const Size(1080, 2400));
    expect(r.opacity, 0.3);
    expect(r.onTop, isTrue);
    expect(r.fit, ReferenceFit.fill);

    c.setReference(null);
    expect(c.page.reference, isNull);
    expect(c.page.toJson().containsKey('reference'), isFalse);
    c.undo();
    expect(c.page.reference, isNotNull, reason: 'removing can be undone');
  });

  test('fit width keeps the aspect ratio; fill covers the screen', () {
    final r = ReferenceImage(
      bytes: Uint8List(0),
      pixelSize: const Size(1080, 2400),
    );
    expect(
      r.rectIn(const Size(400, 800)),
      const Rect.fromLTWH(0, 0, 400, 2400 * 400 / 1080),
    );
    expect(
      r.copyWith(fit: ReferenceFit.fill).rectIn(const Size(400, 800)),
      const Rect.fromLTWH(0, 0, 400, 800),
    );
  });

  testWidgets('wide images are scaled down when loaded', (tester) async {
    await tester.runAsync(() async {
      final small = await referenceFromBytes(await pngOf(300, 600));
      expect(small.pixelSize, const Size(300, 600));

      final big = await referenceFromBytes(await pngOf(2000, 1000));
      expect(big.pixelSize, const Size(1600, 800));
    });
  });

  testWidgets('the panel adds, hides and removes a reference', (tester) async {
    final c = EditorController();
    final bytes = (await tester.runAsync(() => pngOf(40, 80)))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: c,
            builder: (_, _) => SingleChildScrollView(
              child: ReferenceSection(
                controller: c,
                pick: () async =>
                    ReferenceImage(bytes: bytes, pixelSize: const Size(40, 80)),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add reference image'));
    await tester.pumpAndSettle();
    expect(c.page.reference, isNotNull);
    expect(find.text('40 × 80 px'), findsOneWidget);

    await tester.tap(find.text('Show above elements'));
    await tester.pumpAndSettle();
    expect(c.page.reference!.onTop, isTrue);

    await tester.tap(find.byTooltip('Hide reference'));
    await tester.pumpAndSettle();
    expect(c.page.reference!.visible, isFalse);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(c.page.reference, isNull);
    expect(find.text('Add reference image'), findsOneWidget);
  });

  testWidgets('exported PNG pictures leave the reference out', (tester) async {
    final c = EditorController()..addElement(ElementType.button);
    c.setReference(
      ReferenceImage(
        bytes: (await tester.runAsync(() => pngOf(40, 80)))!,
        pixelSize: const Size(40, 80),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: ArtboardPicture(page: c.page)));
    expect(find.byType(Image), findsNothing);
  });

  test('a custom rect is kept in JSON and used for drawing', () {
    final r = ReferenceImage(
      bytes: Uint8List(0),
      pixelSize: const Size(100, 200),
      fit: ReferenceFit.custom,
      rect: const Rect.fromLTWH(10, 20, 50, 100),
    );
    final back = ReferenceImage.fromJson(r.toJson());
    expect(back.fit, ReferenceFit.custom);
    expect(
      back.rectIn(const Size(400, 800)),
      const Rect.fromLTWH(10, 20, 50, 100),
    );
    // Custom without a rect falls back to fit width
    expect(
      ReferenceImage(
        bytes: Uint8List(0),
        pixelSize: const Size(100, 200),
        fit: ReferenceFit.custom,
      ).rectIn(const Size(400, 800)),
      const Rect.fromLTWH(0, 0, 400, 800),
    );
  });

  testWidgets('the reference can be moved and resized on screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = EditorController();
    c.setReference(
      ReferenceImage(
        bytes: base64Decode(_pixel),
        pixelSize: const Size(100, 200),
        fit: ReferenceFit.custom,
        rect: const Rect.fromLTWH(50, 50, 100, 200),
      ),
    );
    await openEditor(tester, c);

    final adjust = find.text('Move & resize on screen');
    await tester.ensureVisible(adjust);
    await tester.pumpAndSettle();
    await tester.tap(adjust);
    await tester.pumpAndSettle();
    final editor = find.byKey(const ValueKey('reference-editor'));
    expect(editor, findsOneWidget);
    final image = find.byKey(const ValueKey('reference-image'));
    final r0 = tester.getRect(image);

    // Drag the middle: the picture moves
    final move = await tester.startGesture(
      tester.getCenter(editor),
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 0; i < 4; i++) {
      await move.moveBy(const Offset(10, 8));
      await tester.pump();
    }
    await move.up();
    await tester.pumpAndSettle();
    final r1 = tester.getRect(image);
    expect(r1.size, r0.size);
    expect(r1.left, greaterThan(r0.left + 20));

    // Drag the bottom-right corner: it grows and keeps its proportions
    final pen = await tester.startGesture(
      r1.bottomRight,
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 0; i < 5; i++) {
      await pen.moveBy(const Offset(12, 4));
      await tester.pump();
    }
    await pen.up();
    await tester.pumpAndSettle();
    final r2 = tester.getRect(image);
    expect(r2.width, greaterThan(r1.width + 20));
    expect(r2.width / r2.height, closeTo(0.5, 0.02));
    expect(r2.topLeft, offsetMoreOrLessEquals(r1.topLeft, epsilon: 0.5));

    await tester.tap(find.text('Done adjusting'));
    await tester.pumpAndSettle();
    expect(editor, findsNothing);
  });
}

/// 1×1 transparent PNG.
const _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
