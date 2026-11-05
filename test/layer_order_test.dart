import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rexa_ui_studio/models/ui_element.dart';
import 'package:rexa_ui_studio/state/editor_controller.dart';

import 'layers_test.dart' show openEditor;

/// Boxes a, b, c, d from back to front.
(EditorController, List<String>) fourBoxes() {
  final c = EditorController();
  for (final t in ['a', 'b', 'c', 'd']) {
    c.addElement(ElementType.button, text: t);
  }
  return (c, [for (final e in c.page.elements) e.id]);
}

List<String> order(EditorController c) => [
  for (final e in c.page.elements) e.text,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('layer order', () {
    test('one step up and down, then to front and back', () {
      final (c, ids) = fourBoxes();
      c.select(ids[1]);
      c.moveForward();
      expect(order(c), ['a', 'c', 'b', 'd']);
      c.moveForward();
      expect(order(c), ['a', 'c', 'd', 'b']);
      expect(c.canMoveForward, isFalse);
      c.moveForward();
      expect(order(c), ['a', 'c', 'd', 'b'], reason: 'already on top');

      c.moveBackward();
      expect(order(c), ['a', 'c', 'b', 'd']);
      c.sendToBack();
      expect(order(c), ['b', 'a', 'c', 'd']);
      expect(c.canMoveBackward, isFalse);
      c.bringToFront();
      expect(order(c), ['a', 'c', 'd', 'b']);

      c.undo();
      expect(order(c), ['b', 'a', 'c', 'd']);
    });

    test('a multi selection moves as one block', () {
      final (c, ids) = fourBoxes();
      c
        ..select(ids[0])
        ..toggleSelect(ids[1]);
      c.moveForward();
      expect(order(c), ['c', 'a', 'b', 'd']);
      c.bringToFront();
      expect(order(c), ['c', 'd', 'a', 'b']);
      c.sendToBack();
      expect(order(c), ['a', 'b', 'c', 'd']);
    });

    test('drag reorder in the list (top layer first)', () {
      final (c, _) = fourBoxes();
      // List shows d, c, b, a; drag "d" (0) below "b" (to 2)
      c.reorderLayer(0, 2);
      expect(order(c), ['a', 'd', 'b', 'c']);
      // And "a" (last) to the top
      c.reorderLayer(3, 0);
      expect(order(c), ['d', 'b', 'c', 'a']);
      c.undo();
      expect(order(c), ['a', 'd', 'b', 'c']);
    });

    testWidgets('drag a layer by its handle in the Layers tab', (tester) async {
      final (c, _) = fourBoxes();
      await openEditor(tester, c);
      await tester.tap(find.text('Layers'));
      await tester.pumpAndSettle();

      // Top layer first
      String names() => ([
        for (final t in ['a', 'b', 'c', 'd'])
          (
            t,
            tester
                .getTopLeft(
                  find.descendant(
                    of: find.byType(ReorderableListView),
                    matching: find.text(t),
                  ),
                )
                .dy,
          ),
      ]..sort((x, y) => x.$2.compareTo(y.$2))).map((x) => x.$1).join();
      expect(names(), 'dcba');

      final handle = find.byTooltip('Drag to move up or down');
      Finder row(String t) => find.descendant(
        of: find.byType(ReorderableListView),
        matching: find.text(t),
      );
      final rowHeight =
          tester.getTopLeft(row('c')).dy - tester.getTopLeft(row('d')).dy;
      expect(rowHeight, greaterThan(20));
      final drag = await tester.startGesture(tester.getCenter(handle.first));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await drag.moveBy(Offset(0, rowHeight * 1.8 / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await drag.up();
      await tester.pumpAndSettle();
      expect(names(), 'cbda');
    });
  });
}
