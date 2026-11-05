import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rexa_ui_studio/models/ui_element.dart';
import 'package:rexa_ui_studio/services/code_export.dart';
import 'package:rexa_ui_studio/state/editor_controller.dart';
import 'package:rexa_ui_studio/widgets/element_view.dart';

import 'layers_test.dart' show openEditor;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('pen tool', () {
    test('a closed shape gets bounds and 0–1 points', () {
      final c = EditorController()..setPenTool(true);
      c
        ..addPenPoint(const Offset(100, 100))
        ..addPenPoint(const Offset(200, 100))
        ..finishPen(closed: true);
      expect(c.page.elements, isEmpty, reason: 'a closed shape needs 3');
      c
        ..addPenPoint(const Offset(150, 200))
        ..finishPen(closed: true);

      final e = c.page.elements.single;
      expect(e.type, ElementType.path);
      expect(e.closed, isTrue);
      expect(e.rect, const Rect.fromLTWH(100, 100, 100, 100));
      expect(e.points, const [Offset(0, 0), Offset(1, 0), Offset(0.5, 1)]);
      expect(c.selectedId, e.id);
      expect(c.penDraft, isEmpty);
      expect(c.penTool, isTrue, reason: 'ready for the next shape');

      c.undo();
      expect(c.page.elements, isEmpty);
    });

    test('an open line, undoing points, JSON', () {
      final c = EditorController()..setPenTool(true);
      c
        ..addPenPoint(const Offset(10, 50))
        ..addPenPoint(const Offset(90, 50))
        ..addPenPoint(const Offset(99, 99))
        ..undoPenPoint()
        ..finishPen(closed: false);
      final e = c.page.elements.single;
      expect(e.closed, isFalse);
      expect(e.rect.height, 1, reason: 'a flat line still has a size');

      final back = UiElement.fromJson(e.copyWith(strokeWidth: 5).toJson());
      expect(back.points, e.points);
      expect(back.closed, isFalse);
      expect(back.strokeWidth, 5);
    });

    test('every language exports pen shapes', () {
      final c = EditorController()..setPenTool(true);
      for (final p in const [Offset(0, 0), Offset(40, 0), Offset(20, 40)]) {
        c.addPenPoint(p);
      }
      c.finishPen(closed: true);
      for (final p in const [Offset(0, 100), Offset(80, 120)]) {
        c.addPenPoint(p);
      }
      c.finishPen(closed: false);
      final page = c.page;

      final flutter = CodeLanguage.flutter.generate(page);
      expect(flutter, contains('class PenShapePainter'));
      expect(flutter, contains('closed: false, strokeWidth: 2'));
      final swift = CodeLanguage.swiftUI.generate(page);
      expect(swift, contains('var closed = true'));
      expect(swift, contains('closed: false).stroke('));
      final compose = CodeLanguage.compose.generate(page);
      expect(compose, contains('drawPath(Path().apply'));
      expect(compose, contains('style = Stroke('));
      final html = CodeLanguage.html.generate(page);
      expect(html, contains('<polygon points="0,0 100,0 50,100"'));
      expect(html, contains('<polyline'));
      expect(html, contains('vector-effect="non-scaling-stroke" />'));
      final react = CodeLanguage.react.generate(page);
      expect(react, contains('vectorEffect="non-scaling-stroke"'));
      expect(react, contains('strokeWidth="2"'));
    });
  });

  testWidgets('drawing a triangle with the pen tool', (tester) async {
    await openEditor(tester, EditorController());
    await tester.tap(find.byTooltip('Pen tool: draw a shape (P)'));
    await tester.pumpAndSettle();
    expect(find.text('Pen: tap to place points'), findsOneWidget);

    final layer = find.byKey(const ValueKey('pen-layer'));
    final r = tester.getRect(layer);
    final a = r.topLeft + const Offset(60, 120);
    for (final p in [a, a + const Offset(120, 0), a + const Offset(60, 100)]) {
      await tester.tapAt(p, kind: PointerDeviceKind.stylus);
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(
      find.text('3 points · tap the first point to close'),
      findsOneWidget,
    );

    // Tapping the first point closes the shape
    await tester.tapAt(a, kind: PointerDeviceKind.stylus);
    await tester.pumpAndSettle();
    final shape = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is PenShapePainter,
    );
    expect(shape, findsOneWidget);
    expect(find.text('Pen shape'), findsOneWidget, reason: 'it is selected');

    await tester.tap(find.byTooltip('Exit pen tool (Esc)'));
    await tester.pumpAndSettle();
    expect(layer, findsNothing);
  });
}
