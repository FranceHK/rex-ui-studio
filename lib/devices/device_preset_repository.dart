import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_preset.dart';
import 'phone_catalog.dart';

/// A user preset: a name and a logical size (portrait).
class CustomPreset {
  const CustomPreset({
    required this.id,
    required this.name,
    required this.size,
    this.basedOn,
  });

  final String id;
  final String name;
  final Size size;

  /// Id of the catalog preset used as the base (if any).
  final String? basedOn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': [size.width, size.height],
    if (basedOn != null) 'basedOn': basedOn,
  };

  factory CustomPreset.fromJson(Map<String, dynamic> json) {
    final s = json['size'] as List;
    return CustomPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      size: Size((s[0] as num).toDouble(), (s[1] as num).toDouble()),
      basedOn: json['basedOn'] as String?,
    );
  }
}

/// Easy access to the phone catalog.
class DevicePresetRepository {
  DevicePresetRepository([List<DevicePreset>? presets])
    : presets = presets ?? phoneCatalog;

  final List<DevicePreset> presets;

  late final Map<String, DevicePreset> _byId = {
    for (final p in presets) p.id: p,
  };

  DevicePreset? byId(String id) => _byId[id];

  List<DevicePreset> byManufacturer(Manufacturer m) =>
      presets.where((p) => p.manufacturer == m).toList();

  /// A manufacturer's families in catalog order (newest first).
  List<String> families(Manufacturer? m) => {
    for (final p in presets)
      if (m == null || p.manufacturer == m) p.family,
  }.toList();

  int get foldableDisplayCount =>
      presets.where((p) => p.foldable).fold(0, (n, p) => n + p.displays.length);
}

/// Favorites, recently used and user presets. Stored with
/// shared_preferences like projects.
class CustomPresetManager extends ChangeNotifier {
  static const _key = 'rexa_ui_studio.device_presets.v1';
  static const maxRecents = 8;

  List<CustomPreset> custom = [];
  List<String> favorites = [];
  List<String> recents = [];
  bool loaded = false;

  Future<void> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        custom = [
          for (final c in json['custom'] as List? ?? const [])
            CustomPreset.fromJson(c as Map<String, dynamic>),
        ];
        favorites = [...(json['favorites'] as List? ?? const []).cast()];
        recents = [...(json['recents'] as List? ?? const []).cast()];
      } catch (_) {
        // Bad data: start over without breaking the app
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode({
        'custom': [for (final c in custom) c.toJson()],
        'favorites': favorites,
        'recents': recents,
      }),
    );
  }

  bool isFavorite(String presetId) => favorites.contains(presetId);

  Future<void> toggleFavorite(String presetId) {
    favorites = isFavorite(presetId)
        ? (favorites.where((f) => f != presetId).toList())
        : [...favorites, presetId];
    return _save();
  }

  Future<void> markUsed(String presetId) {
    recents = [
      presetId,
      ...recents.where((r) => r != presetId),
    ].take(maxRecents).toList();
    return _save();
  }

  Future<CustomPreset> addCustom(String name, Size size, {String? basedOn}) {
    final preset = CustomPreset(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: name,
      size: size,
      basedOn: basedOn,
    );
    custom = [...custom, preset];
    return _save().then((_) => preset);
  }

  Future<void> deleteCustom(String id) {
    custom = custom.where((c) => c.id != id).toList();
    return _save();
  }
}

/// What the New Design list on the left shows.
enum PresetSource { all, favorites, recents }

/// Catalog search and filters.
class DeviceSearchController extends ChangeNotifier {
  DeviceSearchController(this.repository, this.manager) {
    manager.addListener(notifyListeners);
  }

  final DevicePresetRepository repository;
  final CustomPresetManager manager;

  String query = '';
  Manufacturer? manufacturer;
  String? family;
  PresetSource source = PresetSource.all;
  bool foldableOnly = false;

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  void setManufacturer(Manufacturer? m) {
    manufacturer = m;
    family = null;
    notifyListeners();
  }

  void setFamily(String? f) {
    family = f;
    notifyListeners();
  }

  void setSource(PresetSource s) {
    source = s;
    notifyListeners();
  }

  void setFoldableOnly(bool v) {
    foldableOnly = v;
    notifyListeners();
  }

  List<String> get families => repository.families(manufacturer);

  /// Results matching all filters.
  List<DevicePreset> get results {
    Iterable<DevicePreset> list = switch (source) {
      PresetSource.all => repository.presets,
      PresetSource.favorites => [
        for (final id in manager.favorites) ?repository.byId(id),
      ],
      PresetSource.recents => [
        for (final id in manager.recents) ?repository.byId(id),
      ],
    };
    if (manufacturer case final m?) {
      list = list.where((p) => p.manufacturer == m);
    }
    if (family case final f?) list = list.where((p) => p.family == f);
    if (foldableOnly) list = list.where((p) => p.foldable);
    final q = query.trim();
    if (q.isNotEmpty) list = list.where((p) => matches(p, q));
    return list.toList();
  }

  /// Every search word must appear (e.g. "s25 ultra", "fold 7").
  static bool matches(DevicePreset p, String query) {
    final text = p.searchText.toLowerCase();
    final compact = text.replaceAll(' ', '');
    return query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .every((w) => text.contains(w) || compact.contains(w));
  }

  @override
  void dispose() {
    manager.removeListener(notifyListeners);
    super.dispose();
  }
}
