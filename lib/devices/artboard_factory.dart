import 'package:flutter/material.dart';

import '../models/device_frame.dart';
import '../models/ui_element.dart';
import 'device_preset.dart';
import 'device_preset_repository.dart';

/// Portrait / landscape of the preview and the artboard.
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

/// Foldable state: which screen is shown.
class FoldableDisplayController extends ChangeNotifier {
  DevicePreset? _preset;
  DisplayRole role = DisplayRole.main;

  DevicePreset? get preset => _preset;

  /// Set a new device; foldables start unfolded.
  void setPreset(DevicePreset preset) {
    _preset = preset;
    role = preset.displays.first.role;
    notifyListeners();
  }

  bool get foldable => _preset?.foldable ?? false;

  /// The device is folded (the outer screen / cover is shown).
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

/// Builds an artboard (DesignPage) from a device preset.
abstract final class ArtboardFactory {
  /// An artboard for one screen of [preset].
  ///
  /// When [size] is given (in portrait) and differs from the device frame,
  /// it's stored as a custom size; the device metadata stays.
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

  /// An artboard for a user preset.
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
