import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rexa_ui_studio/devices/artboard_factory.dart';
import 'package:rexa_ui_studio/devices/device_preset.dart';
import 'package:rexa_ui_studio/devices/device_preset_repository.dart';
import 'package:rexa_ui_studio/devices/phone_catalog.dart';
import 'package:rexa_ui_studio/models/device_frame.dart';
import 'package:rexa_ui_studio/models/ui_element.dart';
import 'package:rexa_ui_studio/screens/new_design_screen.dart';
import 'package:rexa_ui_studio/state/editor_controller.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final repo = DevicePresetRepository();

  group('katalogi', () {
    test('idadi, id za kipekee na vyanzo', () {
      expect(repo.byManufacturer(Manufacturer.apple), hasLength(34));
      expect(repo.byManufacturer(Manufacturer.samsung), hasLength(50));
      expect(repo.byManufacturer(Manufacturer.google), hasLength(24));
      expect(repo.foldableDisplayCount, 30);

      final ids = phoneCatalog.map((p) => p.id).toSet();
      expect(ids, hasLength(phoneCatalog.length));
      final frameIds = devices.map((d) => d.id).toSet();
      expect(frameIds, hasLength(devices.length));

      for (final p in phoneCatalog) {
        expect(p.sourceUrl, startsWith('https://'), reason: p.model);
        expect(p.model, isNotEmpty);
        if (p.foldable) expect(p.displays, hasLength(2), reason: p.model);
        for (final d in p.displays) {
          expect(d.artboard.width, greaterThan(0), reason: p.model);
          expect(d.physical.width, greaterThan(0), reason: p.model);
        }
      }
    });

    test('resolution na frame za kimantiki zilizothibitishwa', () {
      DeviceDisplay main(String id) => repo.byId(id)!.primary;

      // iPhone: scale tofauti na mini zinazoshushwa (downsampled)
      expect(main('iphone-11').physical, const Size(828, 1792));
      expect(main('iphone-11').logical, const Size(414, 896));
      expect(main('iphone-11').scale, 2);
      expect(main('iphone-13-mini').physical, const Size(1080, 2340));
      expect(main('iphone-13-mini').logical, const Size(375, 812));
      expect(main('iphone-17-pro').logical, const Size(402, 874));
      expect(main('iphone-se-3').logical, const Size(375, 667));
      for (final p in repo.byManufacturer(Manufacturer.apple)) {
        for (final d in p.displays) {
          expect(d.logicalVerified, isTrue, reason: p.model);
          // Frame × scale ≥ px halisi (sawa, au kubwa kwa zinazoshushwa)
          expect(
            d.logical!.width * d.scale!,
            greaterThanOrEqualTo(d.physical.width),
            reason: p.model,
          );
        }
      }

      // Pixel: dp kutoka density rasmi ya SDK, si kutoka PPI
      expect(main('pixel-9').logical, const Size(411, 923));
      expect(main('pixel-9').densityDpi, 420);
      expect(main('pixel-8-pro').logical, const Size(448, 997));
      expect(main('pixel-7-pro').logical, const Size(411, 891));
      expect(main('pixel-10a').logicalVerified, isFalse);

      // Samsung: hakuna dp rasmi -> makisio yanayoonyeshwa wazi
      for (final p in repo.byManufacturer(Manufacturer.samsung)) {
        for (final d in p.displays) {
          expect(d.logical, isNull, reason: p.model);
          expect(d.isVerified('logical'), isFalse, reason: p.model);
        }
      }
      // Marekebisho: S21 FE ni 1080×2340
      expect(main('galaxy-s21-fe').physical, const Size(1080, 2340));
      final flip7 = repo.byId('galaxy-z-flip7')!;
      expect(flip7.display(DisplayRole.cover).physical, const Size(948, 1048));
      expect(flip7.display(DisplayRole.cover).cutouts, isNotEmpty);
      final duo = repo.byId('iphone-duo')!;
      expect(duo.display(DisplayRole.inner).physical, const Size(1878, 2670));
      expect(duo.display(DisplayRole.outer).logical, const Size(466, 678));
    });
  });

  group('utafutaji', () {
    late CustomPresetManager manager;
    late DeviceSearchController search;
    setUp(() {
      manager = CustomPresetManager();
      search = DeviceSearchController(repo, manager);
    });

    test('kwa maneno', () {
      search.setQuery('s25 ultra');
      expect(search.results.map((p) => p.id), ['galaxy-s25-ultra']);
      search.setQuery('fold 7');
      expect(search.results.map((p) => p.id), contains('galaxy-z-fold7'));
      search.setQuery('hakuna-kitu-hiki');
      expect(search.results, isEmpty);
    });

    test('mtengenezaji, familia na fold', () {
      search.setManufacturer(Manufacturer.google);
      expect(
        search.results.every((p) => p.manufacturer == Manufacturer.google),
        isTrue,
      );
      expect(search.families, contains('Pixel 9'));
      search.setManufacturer(Manufacturer.apple);
      search.setFamily('iPhone 16');
      expect(search.results.map((p) => p.model), [
        'iPhone 16',
        'iPhone 16 Plus',
        'iPhone 16 Pro',
        'iPhone 16 Pro Max',
        'iPhone 16e',
      ]);
      search.setManufacturer(null);
      search.setFoldableOnly(true);
      expect(search.results, hasLength(15));
      expect(search.results.every((p) => p.foldable), isTrue);
    });

    test('vipendwa na zilizotumika karibuni', () async {
      await manager.toggleFavorite('pixel-9');
      await manager.markUsed('iphone-16');
      await manager.markUsed('galaxy-s24');
      search.setSource(PresetSource.favorites);
      expect(search.results.map((p) => p.id), ['pixel-9']);
      search.setSource(PresetSource.recents);
      expect(search.results.map((p) => p.id), ['galaxy-s24', 'iphone-16']);
    });
  });

  test('mwelekeo na hali za kukunjika', () {
    final o = OrientationController();
    expect(o.apply(const Size(402, 874)), const Size(402, 874));
    o.toggle();
    expect(o.apply(const Size(402, 874)), const Size(874, 402));

    final f = FoldableDisplayController()
      ..setPreset(repo.byId('galaxy-z-flip7')!);
    expect(f.folded, isFalse);
    expect(f.role, DisplayRole.inner);
    f.setFolded(true);
    expect(f.role, DisplayRole.cover);
    expect(f.display!.physical, const Size(948, 1048));

    f.setPreset(repo.byId('pixel-9')!);
    f.setFolded(true); // haikunjiki: haibadiliki
    expect(f.role, DisplayRole.main);
  });

  group('artboard', () {
    test('kutoka preset: jina, ukubwa, mwelekeo, metadata', () {
      final page = ArtboardFactory.fromPreset(
        'e1',
        repo.byId('pixel-9-pro-fold')!,
        role: DisplayRole.inner,
        landscape: true,
        safeArea: true,
      );
      expect(page.name, 'Pixel 9 Pro Fold (ndani)');
      expect(page.device.id, 'pixel-9-pro-fold-inner');
      expect(page.size, const Size(882, 851));
      expect(page.showSafeArea, isTrue);
      expect(page.device.physical, const Size(2076, 2152));
      final json = page.toJson();
      expect(json['meta']['physical'], [2076, 2152]);
      expect(json['meta']['logicalVerified'], isTrue);
    });

    test('ukubwa maalum na preset ya mtumiaji', () {
      final resized = ArtboardFactory.fromPreset(
        'e1',
        repo.byId('iphone-16')!,
        size: const Size(400, 900),
      );
      expect(resized.size, const Size(400, 900));
      expect(resized.resized, isTrue);
      expect(resized.device.id, 'iphone-16');

      final custom = ArtboardFactory.fromCustom(
        'e2',
        const CustomPreset(id: 'c', name: 'Kiosk', size: Size(600, 1024)),
      );
      expect(custom.name, 'Kiosk');
      expect(custom.size, const Size(600, 1024));
    });

    test('artboard nyingi, kubadili kifaa na kukunja kwenye editor', () {
      final c = EditorController();
      c.addArtboard(
        (id) => ArtboardFactory.fromPreset(id, repo.byId('galaxy-z-fold7')!),
      );
      expect(c.pages, hasLength(2));
      expect(c.page.device.id, 'galaxy-z-fold7-inner');
      c.toggleFold();
      expect(c.page.device.id, 'galaxy-z-fold7-outer');
      c.setCustomSize(const Size(300, 700));
      expect(c.page.size, const Size(300, 700));
      c.setDevice(deviceById('iphone-17-pro'));
      expect(c.page.customSize, isNull);
      expect(c.page.size, const Size(402, 874));
      c.setShowSafeArea(true);
      expect(c.page.safeArea, const EdgeInsets.only(top: 62, bottom: 34));
      c.setLandscape(true);
      expect(c.page.safeArea!.left, 62);
    });
  });

  test('preset za mtumiaji na vipendwa vinahifadhiwa', () async {
    final a = CustomPresetManager();
    await a.load();
    await a.addCustom('Kiosk', const Size(600, 1024), basedOn: 'iphone-16');
    await a.toggleFavorite('galaxy-s26');
    await a.markUsed('pixel-10');

    final b = CustomPresetManager();
    await b.load();
    expect(b.custom.single.name, 'Kiosk');
    expect(b.custom.single.size, const Size(600, 1024));
    expect(b.favorites, ['galaxy-s26']);
    expect(b.recents, ['pixel-10']);
  });

  test('artboard inahifadhiwa na kupakiwa tena', () {
    final c = EditorController()
      ..addArtboard(
        (id) => ArtboardFactory.fromPreset(
          id,
          repo.byId('galaxy-z-flip7')!,
          role: DisplayRole.cover,
          safeArea: true,
        ),
      )
      ..setCustomSize(const Size(360, 400));
    final restored = EditorController()
      ..loadJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(restored.pages, hasLength(2));
    expect(restored.page.device.id, 'galaxy-z-flip7-cover');
    expect(restored.page.size, const Size(360, 400));
    expect(restored.page.showSafeArea, isTrue);
  });

  test('miradi ya zamani inafunguka bila vipengele kusogea', () {
    Map<String, dynamic> legacy(String device) => {
      'id': 'e0',
      'name': 'Skrini 1',
      'device': device,
      'landscape': false,
      'background': 0xFFFFFFFF,
      'elements': <Object>[],
    };
    final s25 = DesignPage.fromJson(legacy('galaxy-s25'));
    expect(s25.device.id, 'galaxy-s25');
    expect(s25.size, const Size(360, 780));

    final fold = DesignPage.fromJson(legacy('pixel-fold-main'));
    expect(fold.device.id, 'pixel-9-pro-fold-inner');
    expect(fold.size, const Size(851, 882));
    expect(fold.customSize, isNull);

    final named = DesignPage.fromJson(legacy('iPhone 15 / 15 Plus'));
    expect(named.device.id, 'iphone-15');

    final iphone = DesignPage.fromJson(legacy('iphone-17-pro'));
    expect(iphone.customSize, isNull);
    expect(iphone.size, const Size(402, 874));

    // Toleo jipya halitumii ukubwa wa zamani
    final v2 = DesignPage.fromJson({...legacy('galaxy-s25'), 'v': 2});
    expect(v2.size, const Size(411, 891));
  });

  testWidgets('New Design: tafuta, kunja na tengeneza artboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    ArtboardBuilder? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showNewDesign(context),
            child: const Text('fungua'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('fungua'));
    await tester.pumpAndSettle();
    expect(find.text('Design mpya'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'pixel 9 pro fold');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pixel 9 Pro Fold').first);
    await tester.pumpAndSettle();
    expect(find.text('Imefunguliwa'), findsOneWidget);
    expect(find.textContaining('851 × 882 dp'), findsWidgets);

    await tester.tap(find.text('Imekunjwa'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(makisio)'), findsWidgets);
    expect(find.textContaining('1080 × 2424 px'), findsWidgets);

    await tester.tap(find.text('Mlalo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tengeneza design'));
    await tester.pumpAndSettle();

    final page = result!('e9');
    expect(page.device.id, 'pixel-9-pro-fold-outer');
    expect(page.landscape, isTrue);
    expect(page.name, 'Pixel 9 Pro Fold (nje)');
  });
}
