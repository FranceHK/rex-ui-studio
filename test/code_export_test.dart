import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rexa_ui_studio/models/device_frame.dart';
import 'package:rexa_ui_studio/models/ui_element.dart';
import 'package:rexa_ui_studio/screens/code_dialog.dart';
import 'package:rexa_ui_studio/services/code_export.dart';
import 'package:rexa_ui_studio/services/export_common.dart';

DesignPage samplePage() {
  var i = 0;
  UiElement make(ElementType t, Rect r) => UiElement.create(t, 'e${i++}', r);
  return DesignPage(
    id: 'p1',
    name: 'Login screen',
    device: deviceById('iphone-17-pro'),
    elements: [
      for (final t in ElementType.values)
        make(t, Rect.fromLTWH(10, 10.0 + t.index * 60, 200, 48)),
      make(
        ElementType.container,
        const Rect.fromLTWH(20, 700, 80, 80),
      ).copyWith(shape: ElementShape.star, text: r'Say "hi" & {x} $y'),
    ],
  );
}

void main() {
  test('every language generates code for every element type', () {
    final page = samplePage();
    for (final l in CodeLanguage.values) {
      final code = l.generate(page);
      expect(code, isNotEmpty, reason: l.label);
      expect(code, contains('Rexa UI Studio'), reason: l.label);
    }
  });

  test('language-specific output', () {
    final page = samplePage();
    expect(CodeLanguage.flutter.generate(page), contains('class LoginScreen'));
    final swift = CodeLanguage.swiftUI.generate(page);
    expect(swift, contains('struct LoginView: View'));
    expect(swift, contains('struct PolygonShape: Shape'));
    expect(swift, contains('#Preview'));
    final kt = CodeLanguage.compose.generate(page);
    expect(kt, contains('fun LoginScreen()'));
    expect(kt, contains('GenericShape'));
    final html = CodeLanguage.html.generate(page);
    expect(html, startsWith('<!doctype html>'));
    expect(html, contains('clip-path: polygon('));
    expect(html, contains('<input placeholder="Email"'));
    final jsx = CodeLanguage.react.generate(page);
    expect(jsx, contains('export default function LoginScreen()'));
    expect(jsx, contains('className="material-symbols-rounded"'));
    expect(jsx, contains('position: \'absolute\''));
  });

  test('file names per language', () {
    final page = samplePage();
    expect(CodeLanguage.flutter.fileName(page), 'login_screen.dart');
    expect(CodeLanguage.swiftUI.fileName(page), 'LoginView.swift');
    expect(CodeLanguage.compose.fileName(page), 'LoginScreen.kt');
    expect(CodeLanguage.html.fileName(page), 'login_screen.html');
    expect(CodeLanguage.react.fileName(page), 'LoginScreen.jsx');
  });

  test('shape points fill the unit square', () {
    expect(shapePoints(ElementShape.rectangle), isNull);
    expect(shapePoints(ElementShape.ellipse), isNull);
    for (final s in [
      ElementShape.triangle,
      ElementShape.diamond,
      ElementShape.pentagon,
      ElementShape.hexagon,
      ElementShape.star,
    ]) {
      final pts = shapePoints(s)!;
      expect(pts.map((p) => p.dx).reduce((a, b) => a < b ? a : b), 0);
      expect(pts.map((p) => p.dx).reduce((a, b) => a > b ? a : b), 1);
      expect(pts.map((p) => p.dy).reduce((a, b) => a < b ? a : b), 0);
      expect(pts.map((p) => p.dy).reduce((a, b) => a > b ? a : b), 1);
    }
    expect(shapePoints(ElementShape.star), hasLength(10));
    expect(hexColor(const Color(0xFF4F46E5)), '#4F46E5');
    expect(hexColor(const Color(0x804F46E5)), '#4F46E580');
    expect(snakeIcon('arrowLeft2'), 'arrow_left');
  });

  testWidgets('code dialog switches language', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    CodeLanguage? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: CodeDialog(
          page: samplePage(),
          onLanguageChanged: (l) => picked = l,
        ),
      ),
    );
    expect(find.textContaining('class LoginScreen'), findsOneWidget);
    await tester.tap(find.text('SwiftUI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('struct LoginView'), findsOneWidget);
    expect(find.text('Swift · LoginView.swift'), findsOneWidget);
    expect(picked, CodeLanguage.swiftUI);
  });
}
