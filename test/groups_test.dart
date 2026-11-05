import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rexa_ui_studio/models/ui_element.dart';
import 'package:rexa_ui_studio/state/editor_controller.dart';
import 'package:rexa_ui_studio/widgets/element_view.dart';

import 'layers_test.dart' show openEditor;

/// A controller with boxes "a" and "b" side by side, both selected.
EditorController twoBoxes() {
  final c = EditorController()
    ..addElement(ElementType.container, at: const Offset(40, 100))
    ..addElement(ElementType.container, at: const Offset(260, 100));
  final [a, b] = c.page.elements;
  c.setRects({
    a.id: const Rect.fromLTWH(40, 100, 100, 50),
    b.id: const Rect.fromLTWH(200, 100, 100, 100),
  });
  c.selectAll();
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('groups', () {
    test('group, select as one, ungroup', () {
      final c = twoBoxes();
      final [a, b] = c.page.elements;
      expect(c.canGroup, isTrue);
      c.groupSelected();
      expect(c.selectionIsGroup, isTrue);
      expect(c.canGroup, isFalse);

      // Selecting one member selects the whole group
      c.select(a.id);
      expect(c.selectedIds, {a.id, b.id});
      expect(c.selectedId, a.id);

      // Shift + tap removes the whole group
      c.toggleSelect(b.id);
      expect(c.selectedIds, isEmpty);

      // Marquee over one member also takes the group
      c.selectInRect(const Rect.fromLTWH(30, 90, 20, 20));
      expect(c.selectedIds, {a.id, b.id});

      c.ungroupSelected();
      expect(c.page.elements.every((e) => e.groupId == null), isTrue);
      c.select(a.id);
      expect(c.selectedIds, {a.id});

      c.undo();
      expect(c.page.elements.map((e) => e.groupId).toSet(), hasLength(1));
    });

    test('duplicates form a new group; ids survive JSON', () {
      final c = twoBoxes()..groupSelected();
      final group = c.page.elements.first.groupId!;
      c.duplicateSelected();
      final copies = c.selectedElements.toList();
      expect(copies, hasLength(2));
      expect(copies.map((e) => e.groupId).toSet(), hasLength(1));
      expect(copies.first.groupId, isNot(group));

      final loaded = EditorController()..loadJson(c.toJson());
      expect(loaded.page.elements.map((e) => e.groupId).toSet(), {
        group,
        copies.first.groupId,
      });
      // New ids don't clash with loaded group ids
      loaded
        ..selectAll()
        ..groupSelected();
      final fresh = loaded.page.elements.first.groupId;
      expect(fresh, isNot(anyOf(group, copies.first.groupId)));
    });

    test('scaledSelection keeps relative positions and sizes', () {
      final c = EditorController();
      final scaled = c.scaledSelection(
        const {
          'a': Rect.fromLTWH(0, 0, 50, 50),
          'b': Rect.fromLTWH(50, 50, 50, 50),
        },
        const Rect.fromLTWH(0, 0, 100, 100),
        const Rect.fromLTWH(10, 10, 200, 50),
      );
      expect(scaled['a'], const Rect.fromLTWH(10, 10, 100, 25));
      expect(scaled['b'], const Rect.fromLTWH(110, 35, 100, 25));
    });
  });

  testWidgets('the selection box scales every selected element', (
    tester,
  ) async {
    final c = twoBoxes()..groupSelected();
    await openEditor(tester, c);

    // Select the group with the pen
    final boxes = find.byType(ElementView);
    await tester.tap(boxes.first, kind: PointerDeviceKind.stylus);
    await tester.pumpAndSettle();
    final box = find.byKey(const ValueKey('selection-box'));
    expect(box, findsOneWidget);
    expect(find.text('Group · 2 elements'), findsOneWidget);

    final a0 = tester.getRect(boxes.at(0));
    final b0 = tester.getRect(boxes.at(1));
    final bounds = a0.expandToInclude(b0);

    // Drag the bottom-right grip: everything grows from the top-left
    final pen = await tester.startGesture(
      bounds.bottomRight,
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 0; i < 5; i++) {
      await pen.moveBy(const Offset(20, 10));
      await tester.pump();
    }
    await pen.up();
    await tester.pumpAndSettle();

    final a1 = tester.getRect(boxes.at(0));
    final b1 = tester.getRect(boxes.at(1));
    expect(a1.topLeft, offsetMoreOrLessEquals(a0.topLeft, epsilon: 0.5));
    expect(a1.width, greaterThan(a0.width));
    expect(b1.width, greaterThan(b0.width));
    expect(b1.left, greaterThan(b0.left), reason: 'b moves out with the box');
    // Relative sizes are kept
    expect(b1.width / a1.width, closeTo(b0.width / a0.width, 0.02));
  });

  testWidgets('Cmd+G groups and Shift+Cmd+G ungroups', (tester) async {
    final c = EditorController()
      ..addElement(ElementType.container, at: const Offset(40, 100))
      ..addElement(ElementType.container, at: const Offset(40, 300));
    await openEditor(tester, c);
    final boxes = find.byType(ElementView);
    await tester.tap(boxes.first, kind: PointerDeviceKind.stylus);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.tap(boxes.last, kind: PointerDeviceKind.stylus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
    expect(find.text('2 elements'), findsOneWidget);

    await tester.tap(find.text('Group (Cmd+G)'));
    await tester.pumpAndSettle();
    expect(find.text('Group · 2 elements'), findsOneWidget);

    await tester.tap(find.text('Ungroup'));
    await tester.pumpAndSettle();
    expect(find.text('2 elements'), findsOneWidget);
  });
}
