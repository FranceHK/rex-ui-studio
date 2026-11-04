import 'package:flutter/material.dart';

import '../models/device_frame.dart';
import '../models/ui_element.dart';
import 'device_preset.dart';
import 'device_preset_repository.dart';

/// Wima / mlalo wa preview na artboard.
class OrientationController extends ChangeNotifier {
  bool landscape = false;

  void set(bool value) {
    if (value == landscape) return;
    landscape = value;
    notifyListeners();
  }

  void toggle() => set(!landscape);

  Size apply(Size portrait) => landscape ? portrait.flipped : portrait;
}

/// Hali ya kifaa kinachokunjika: skrini gani inaonyeshwa.
class FoldableDisplayController extends ChangeNotifier {
  DevicePreset? _preset;
  DisplayRole role = DisplayRole.main;

  DevicePreset? get preset => _preset;

  /// Weka kifaa kipya; vifaa vinavyokunjika vinaanza vikiwa vimefunguliwa.
  void setPreset(DevicePreset preset) {
    _preset = preset;
    role = preset.displays.first.role;
    notifyListeners();
  }

  bool get foldable => _preset?.foldable ?? false;

  /// Kifaa kimekunjwa (skrini ya nje / cover inaonyeshwa).
  bool get folded => role.folded;

  void setFolded(bool value) {
    final p = _preset;
    if (p == null || !p.foldable || value == folded) return;
    role = p.displays.firstWhere((d) => d.role.folded == value).role;
    notifyListeners();
  }

  void selectRole(DisplayRole r) {
    if (r == role) return;
    role = r;
    notifyListeners();
  }

  DeviceDisplay? get display => _preset?.display(role);
}

/// Inatengeneza artboard (DesignPage) kutoka preset ya kifaa.
abstract final class ArtboardFactory {
  /// Artboard ya skrini moja ya [preset].
  ///
  /// [size] ikitolewa (ukiwa wima) na ikitofautiana na frame ya kifaa,
  /// inahifadhiwa kama ukubwa uliobadilishwa; metadata ya kifaa inabaki.
  static DesignPage fromPreset(
    String id,
    DevicePreset preset, {
    DisplayRole? role,
    bool landscape = false,
    bool safeArea = false,
    Color background = Colors.white,
    Size? size,
  }) {
    final display = preset.display(role ?? preset.primary.role);
    final device = deviceById(preset.frameId(display.role));
    return DesignPage(
      id: id,
      name: device.name,
      device: device,
      landscape: landscape,
      customSize: size == null || size == device.size ? null : size,
      showSafeArea: safeArea && display.safeArea != null,
      background: background,
    );
  }

  /// Artboard ya preset ya mtumiaji.
  static DesignPage fromCustom(
    String id,
    CustomPreset preset, {
    bool landscape = false,
    Color background = Colors.white,
  }) {
    return DesignPage(
      id: id,
      name: preset.name,
      device: deviceById(customDeviceId),
      landscape: landscape,
      customSize: preset.size,
      background: background,
    );
  }
}
