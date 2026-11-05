import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rexa_ui_studio/fonts/app_fonts.dart';
import 'package:rexa_ui_studio/models/device_frame.dart';
import 'package:rexa_ui_studio/models/ui_element.dart';
import 'package:rexa_ui_studio/services/compose_export.dart';
import 'package:rexa_ui_studio/services/flutter_export.dart';
import 'package:rexa_ui_studio/services/swiftui_export.dart';
import 'package:rexa_ui_studio/services/web_export.dart';
import 'package:rexa_ui_studio/state/editor_controller.dart';
import 'package:rexa_ui_studio/widgets/element_view.dart';

import 'layers_test.dart' show openEditor;

UiElement styledText() => UiElement.create(
  ElementType.text,
  't1',
  const Rect.fromLTWH(10, 10, 200, 40),
).copyWith(fontFamily: 'Poppins', fontWeight: 800);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('fonts', () {
    test('family and weight survive JSON; old "bold" files migrate', () {
      final e = styledText();
      final back = UiElement.fromJson(e.toJson());
      expect(back.fontFamily, 'Poppins');
      expect(back.fontWeight, 800);

      final old = e.toJson()
        ..remove('weight')
        ..remove('font')
        ..['bold'] = true;
      final migrated = UiElement.fromJson(old);
      expect(migrated.fontWeight, 600);
      expect(migrated.fontFamily, isNull);
      expect(UiElement.fromJson(old..['bold'] = false).fontWeight, 400);
    });

    test('weights map to names and Flutter weights', () {
      expect(FontWeightName.of(100), FontWeightName.thin);
      expect(FontWeightName.of(900), FontWeightName.black);
      expect(FontWeightName.of(650), FontWeightName.bold);
      expect(fontWeightOf(100), FontWeight.w100);
      expect(fontWeightOf(900), FontWeight.w900);
    });

    test('every exporter writes the font and weight', () {
      final page = DesignPage(
        id: 'p1',
        name: 'Fonts',
        device: deviceById('iphone-17-pro'),
        elements: [styledText()],
      );
      final flutter = exportFlutter(page);
      expect(
        flutter,
        contains("import 'package:google_fonts/google_fonts.dart';"),
      );
      expect(flutter, contains("GoogleFonts.getFont('Poppins'"));
      expect(flutter, contains('FontWeight.w800'));
      expect(exportSwiftUI(page), contains('.custom("Poppins"'));
      expect(exportSwiftUI(page), contains('.weight(.heavy)'));
      expect(exportCompose(page), contains('FontWeight.W800'));
      final html = exportHtml(page);
      expect(html, contains("font-family: 'Poppins', sans-serif"));
      expect(html, contains('font-weight: 800'));
      expect(html, contains('family=Poppins:wght@100..900'));
    });

    testWidgets('pick a font and a weight in the properties panel', (
      tester,
    ) async {
      final c = EditorController()
        ..addElement(ElementType.text, at: const Offset(40, 100));
      await openEditor(tester, c);
      UiElement shown() =>
          tester.widget<ElementView>(find.byType(ElementView)).element;
      await tester.tap(find.byType(ElementView), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      final family = find.byKey(const ValueKey('font-family'));
      await tester.dragUntilVisible(
        family,
        find.text('Layout'),
        const Offset(0, -200),
      );
      await tester.tap(family);
      await tester.pumpAndSettle();

      // Every family is listed, each drawn in its own font
      final lato = find.byKey(const ValueKey('font-Lato'));
      expect(lato, findsOneWidget);
      final label = tester.widget<Text>(
        find.descendant(of: lato, matching: find.text('Lato')),
      );
      expect(label.style?.fontFamily, 'Lato');

      await tester.enterText(find.byType(TextField).last, 'mont');
      await tester.pumpAndSettle();
      expect(lato, findsNothing);
      await tester.tap(find.byKey(const ValueKey('font-Montserrat')));
      await tester.pumpAndSettle();
      expect(shown().fontFamily, 'Montserrat');

      final weight = find.byKey(const ValueKey('font-weight'));
      await tester.ensureVisible(weight);
      await tester.pumpAndSettle();
      await tester.tap(weight);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Black · 900').last);
      await tester.pumpAndSettle();
      expect(shown().fontWeight, 900);

      // Back to the system font
      await tester.tap(family);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('font-system')));
      await tester.pumpAndSettle();
      expect(shown().fontFamily, isNull);
    });
  });
}
