import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rexa_ui_studio/main.dart';
import 'package:rexa_ui_studio/models/ui_element.dart';
import 'package:rexa_ui_studio/services/code_export.dart';
import 'package:rexa_ui_studio/services/project_storage.dart';
import 'package:rexa_ui_studio/state/editor_controller.dart';
import 'package:rexa_ui_studio/widgets/element_view.dart';

/// Opens the editor on a project made from [c].
Future<void> openEditor(WidgetTester tester, EditorController c) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final info = await ProjectStorage().create('Layer test', c.toJson());
  await tester.pumpWidget(const RexaStudioApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text(info.name));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('hidden elements', () {
    test('are kept in JSON and left out of every export', () {
      final c = EditorController()
        ..addElement(ElementType.button, text: 'Shown')
        ..addElement(ElementType.button, text: 'Secret');
      c.toggleHidden(c.selectedId!);
      expect(c.selectedIds, isEmpty, reason: 'hiding deselects');

      final page = DesignPage.fromJson(c.page.toJson());
      expect(page.elements.last.hidden, isTrue);
      expect(page.visibleElements.map((e) => e.text), ['Shown']);
      for (final l in CodeLanguage.values) {
        final code = l.generate(page);
        expect(code, contains('Shown'), reason: l.label);
        expect(code, isNot(contains('Secret')), reason: l.label);
      }
    });

    test('marquee selection skips them', () {
      final c = EditorController()..addElement(ElementType.button);
      final id = c.selectedId!;
      c.toggleHidden(id);
      c.selectInRect(Offset.zero & c.page.size);
      expect(c.selectedIds, isEmpty);
      c.toggleHidden(id);
      c.selectInRect(Offset.zero & c.page.size);
      expect(c.selectedIds, {id});
    });
  });

  testWidgets('layers panel hides, shows, locks and unlocks', (tester) async {
    final c = EditorController()..addElement(ElementType.button);
    await openEditor(tester, c);
    await tester.tap(find.text('Layers'));
    await tester.pumpAndSettle();
    expect(find.byType(ElementView), findsOneWidget);

    await tester.tap(find.byTooltip('Hide'));
    await tester.pumpAndSettle();
    expect(find.byType(ElementView), findsNothing);
    await tester.tap(find.byTooltip('Show'));
    await tester.pumpAndSettle();
    expect(find.byType(ElementView), findsOneWidget);

    await tester.tap(find.byTooltip('Lock').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unlock'), findsWidgets);
    await tester.tap(find.byTooltip('Unlock').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unlock'), findsNothing);
  });
}
