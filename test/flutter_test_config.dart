import 'dart:async';

import 'package:rexa_ui_studio/fonts/app_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Tests never download fonts
  fetchGoogleFonts = false;
  await testMain();
}
