import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rexa_ui_studio/icons/icon_style.dart';
import 'package:rexa_ui_studio/main.dart';
import 'package:rexa_ui_studio/models/device_frame.dart';
import 'package:rexa_ui_studio/models/ui_element.dart';
import 'package:rexa_ui_studio/services/flutter_export.dart';
import 'package:rexa_ui_studio/services/project_storage.dart';
import 'package:rexa_ui_studio/state/editor_controller.dart';

void useDesktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('kuanzisha mradi kunafungua editor, kisha kuongeza kitufe', (
    tester,
  ) async {
    useDesktopView(tester);
    await tester.pumpWidget(const RexaStudioApp());
    await tester.pumpAndSettle();
    expect(find.text('No projects yet'), findsOneWidget);

    // Bila jina, mradi haufunguliwi
    await tester.ensureVisible(find.text('Start designing'));
    await tester.tap(find.text('Start designing'));
    await tester.pump();
    expect(find.text('Enter a project name first'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'App ya Benki');
    await tester.tap(find.text('Galaxy S25'));
    await tester.tap(find.text('Start designing'));
    await tester.pumpAndSettle();

    expect(find.text('App ya Benki'), findsOneWidget);
    expect(find.textContaining('Galaxy S25 · 411×891'), findsWidgets);

    await tester.tap(find.text('Kitufe'));
    await tester.pumpAndSettle();
    expect(find.text('Endelea'), findsWidgets);
    expect(find.text('Mpangilio'), findsOneWidget);

    // Kurudi kwenye ukurasa wa mwanzo kunaonyesha mradi uliohifadhiwa
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('All projects'));
    await tester.pumpAndSettle();
    expect(find.text('App ya Benki'), findsOneWidget);
    expect(find.textContaining('1 screen · Galaxy S25'), findsOneWidget);
  });

  testWidgets('kutafuta icon na kuiweka kwenye skrini', (tester) async {
    useDesktopView(tester);
    final storage = ProjectStorage();
    final info = await storage.create('Icons', EditorController().toJson());

    await tester.pumpWidget(const RexaStudioApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text(info.name));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Icons').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tafuta icon… (k.m. home, arrow, wallet)'),
      'wallet add',
    );
    await tester.tap(find.text('Bulk'));
    await tester.pumpAndSettle();
    expect(find.textContaining('· Bulk'), findsOneWidget);

    await tester.tap(find.byTooltip('walletAdd'));
    await tester.pumpAndSettle();
    expect(find.text('walletAdd'), findsWidgets);
    expect(find.text('Bulk'), findsWidgets);
  });

  test('kila icon kwenye katalogi ipo, na utafutaji unafanya kazi', () {
    for (final s in IconStyle.values) {
      expect(s.names, isNotEmpty, reason: s.label);
    }
    expect(IconStyle.broken.has('home'), isTrue);
    expect(IconStyle.payment.has('visa'), isTrue);
    expect(iconMatches('arrowLeft', 'arrow left'), isTrue);
    expect(iconMatches('arrowLeft', 'wallet'), isFalse);
  });

  test('vifaa vina id za kipekee na ukubwa halali', () {
    final ids = devices.map((d) => d.id).toSet();
    expect(ids, hasLength(devices.length));
    for (final b in [
      DeviceBrand.apple,
      DeviceBrand.samsung,
      DeviceBrand.google,
    ]) {
      final kinds = devices.where((d) => d.brand == b).map((d) => d.kind);
      expect(kinds, contains(DeviceKind.phone), reason: b.label);
      expect(kinds, contains(DeviceKind.watch), reason: b.label);
      expect(kinds, contains(DeviceKind.tablet), reason: b.label);
    }
    expect(deviceById('iphone-17-pro').size, const Size(402, 874));
    expect(deviceById('watch-ultra-3').kind, DeviceKind.watch);
  });

  test('lock inazuia kusogeza; mlalo unageuza ukubwa', () {
    final c = EditorController();
    c.addElement(ElementType.button);
    final id = c.selectedId!;
    final before = c.selected!.rect;

    c.toggleLock(id);
    c.nudgeSelected(const Offset(10, 0));
    expect(c.selected!.rect, before);

    c.toggleLock(id);
    c.nudgeSelected(const Offset(10, 0));
    expect(c.selected!.rect.left, before.left + 10);

    c.addElement(ElementType.navBar);
    final portrait = c.page.size;
    c.setLandscape(true);
    expect(c.page.size, portrait.flipped);
    final nav = c.page.elements.last.rect;
    expect(nav.width, portrait.height);
    expect(nav.bottom, portrait.width);
  });

  test('ukubwa maalum', () {
    final c = EditorController(device: deviceById(customDeviceId));
    c.setCustomSize(const Size(500, 700));
    expect(c.page.size, const Size(500, 700));
    final restored = EditorController()
      ..loadJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(restored.page.size, const Size(500, 700));
  });

  test('export inaimport mitindo ya icons inayotumika tu', () {
    final c = EditorController();
    c.addElement(ElementType.button);
    c.addElement(
      ElementType.iconItem,
      text: 'wallet',
      iconStyle: IconStyle.bulk,
    );
    c.addElement(
      ElementType.iconItem,
      text: 'visa',
      iconStyle: IconStyle.payment,
    );
    c.updatePage(c.page.copyWith(name: 'login ya mteja'));
    final code = exportFlutter(c.page);
    expect(code, contains('class LoginYaMtejaScreen extends StatelessWidget'));
    expect(code, contains("import 'package:amazing_icons/bulk.dart';"));
    expect(code, contains("import 'package:amazing_icons/payment.dart';"));
    expect(code, isNot(contains("amazing_icons/outlined.dart")));
    expect(code, contains('AmazingIconBulk.wallet(size: 40'));
    expect(code, contains('AmazingIconPayment.visa(size: 40)'));
  });

  test('miradi mingi: kuhifadhi, kubadili jina, kufuta', () async {
    final storage = ProjectStorage();
    final a = EditorController()..addElement(ElementType.button);
    a.updateElement(a.selected!.copyWith(text: 'Ingia', locked: true));
    final p1 = await storage.create('Kwanza', a.toJson());
    final p2 = await storage.create('Pili', EditorController().toJson());

    await storage.rename(p1.id, 'Mradi wa kwanza');
    final b = EditorController()..loadJson((await storage.load(p1.id))!);
    expect(b.page.elements.single.text, 'Ingia');
    expect(b.page.elements.single.locked, isTrue);

    await storage.delete(p2.id);
    final list = await storage.list();
    expect(list.map((p) => p.name), ['Mradi wa kwanza']);
  });

  test('mradi wa toleo la zamani unahamishwa', () async {
    final old = EditorController()..addElement(ElementType.text);
    SharedPreferences.setMockInitialValues({
      'rexa_ui_studio.project.v1': jsonEncode(old.toJson()),
    });
    final list = await ProjectStorage().list();
    expect(list.single.name, 'Mradi wangu');
  });

  test('JSON mbovu haiharibu mradi wa sasa', () {
    final c = EditorController()..addElement(ElementType.button);
    expect(() => c.loadJson({'pages': 'si orodha'}), throwsFormatException);
    expect(() => c.loadJson({'pages': []}), throwsFormatException);
    expect(c.page.elements, hasLength(1));
  });
}
