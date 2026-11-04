import '../models/ui_element.dart';
import 'compose_export.dart';
import 'flutter_export.dart';
import 'swiftui_export.dart';
import 'web_export.dart';

/// Languages the "Get code" dialog can generate.
enum CodeLanguage {
  flutter('Flutter', 'Dart', 'dart'),
  swiftUI('SwiftUI', 'Swift', 'swift'),
  compose('Jetpack Compose', 'Kotlin', 'kt'),
  html('HTML + CSS', 'HTML', 'html'),
  react('React', 'JSX', 'jsx');

  const CodeLanguage(this.label, this.language, this.extension);

  /// Framework name shown to the user.
  final String label;

  /// Programming language, e.g. "Kotlin".
  final String language;

  /// File extension without the dot.
  final String extension;

  String generate(DesignPage page) => switch (this) {
    flutter => exportFlutter(page),
    swiftUI => exportSwiftUI(page),
    compose => exportCompose(page),
    html => exportHtml(page),
    react => exportReact(page),
  };

  /// Suggested file name, e.g. "LoginScreen.kt".
  String fileName(DesignPage page) {
    final name = className(page.name);
    return switch (this) {
      flutter => '${_snake(name)}.dart',
      swiftUI => '${name.replaceAll(RegExp(r'Screen$'), 'View')}.swift',
      html => '${_snake(name)}.html',
      _ => '$name.$extension',
    };
  }
}

String _snake(String name) => name
    .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
    .toLowerCase();
