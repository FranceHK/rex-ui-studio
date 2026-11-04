import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Project summary shown on the start page.
class ProjectInfo {
  const ProjectInfo({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.screens = 1,
    this.deviceId,
  });

  final String id;
  final String name;
  final DateTime updatedAt;
  final int screens;
  final String? deviceId;

  ProjectInfo copyWith({
    String? name,
    DateTime? updatedAt,
    int? screens,
    String? deviceId,
  }) {
    return ProjectInfo(
      id: id,
      name: name ?? this.name,
      updatedAt: updatedAt ?? this.updatedAt,
      screens: screens ?? this.screens,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'updatedAt': updatedAt.toIso8601String(),
    'screens': screens,
    'deviceId': deviceId,
  };

  factory ProjectInfo.fromJson(Map<String, dynamic> json) => ProjectInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    screens: json['screens'] as int? ?? 1,
    deviceId: json['deviceId'] as String?,
  );
}

/// Stores projects on the device (browser: localStorage, macOS/Windows:
/// the app's preferences file). Each project has its own key, plus an
/// index of all projects.
class ProjectStorage {
  static const _indexKey = 'rexa_ui_studio.projects.v2';
  static const _projectPrefix = 'rexa_ui_studio.project.';
  static const _legacyKey = 'rexa_ui_studio.project.v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// All projects, most recent first.
  Future<List<ProjectInfo>> list() async {
    final prefs = await _prefs;
    await _migrateLegacy(prefs);
    final list = _readIndex(prefs)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<ProjectInfo> create(String name, Map<String, dynamic> project) async {
    final prefs = await _prefs;
    final info = ProjectInfo(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: name,
      updatedAt: DateTime.now(),
    );
    await _write(prefs, info, project);
    return info;
  }

  Future<Map<String, dynamic>?> load(String id) async {
    final raw = (await _prefs).getString('$_projectPrefix$id');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(String id, Map<String, dynamic> project) async {
    final prefs = await _prefs;
    final info = _readIndex(prefs).where((p) => p.id == id).firstOrNull;
    if (info == null) return;
    await _write(prefs, info.copyWith(updatedAt: DateTime.now()), project);
  }

  Future<void> rename(String id, String name) async {
    final prefs = await _prefs;
    await _writeIndex(prefs, [
      for (final p in _readIndex(prefs))
        p.id == id ? p.copyWith(name: name) : p,
    ]);
  }

  Future<void> delete(String id) async {
    final prefs = await _prefs;
    await prefs.remove('$_projectPrefix$id');
    await _writeIndex(
      prefs,
      _readIndex(prefs).where((p) => p.id != id).toList(),
    );
  }

  Future<void> _write(
    SharedPreferences prefs,
    ProjectInfo info,
    Map<String, dynamic> project,
  ) async {
    final pages = project['pages'] as List? ?? const [];
    final first = pages.isEmpty ? null : pages.first as Map<String, dynamic>;
    final updated = info.copyWith(
      screens: pages.length,
      deviceId: first?['device'] as String?,
    );
    await prefs.setString('$_projectPrefix${info.id}', jsonEncode(project));
    await _writeIndex(prefs, [
      for (final p in _readIndex(prefs))
        if (p.id != info.id) p,
      updated,
    ]);
  }

  List<ProjectInfo> _readIndex(SharedPreferences prefs) {
    final raw = prefs.getString(_indexKey);
    if (raw == null) return [];
    try {
      return [
        for (final p in jsonDecode(raw) as List)
          ProjectInfo.fromJson(p as Map<String, dynamic>),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeIndex(SharedPreferences prefs, List<ProjectInfo> list) =>
      prefs.setString(
        _indexKey,
        jsonEncode([for (final p in list) p.toJson()]),
      );

  /// The first version stored a single project; migrate it to
  /// "My project" so it isn't lost.
  Future<void> _migrateLegacy(SharedPreferences prefs) async {
    final raw = prefs.getString(_legacyKey);
    if (raw == null) return;
    try {
      final project = jsonDecode(raw) as Map<String, dynamic>;
      final info = ProjectInfo(
        id: 'legacy',
        name: 'My project',
        updatedAt: DateTime.now(),
      );
      await _write(prefs, info, project);
    } catch (_) {
      // Corrupt JSON: nothing to migrate
    }
    await prefs.remove(_legacyKey);
  }
}
