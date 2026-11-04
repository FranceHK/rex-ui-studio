# Rexa UI Studio

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/francehk235)

Design app screens for phones, tablets, computers and watches, then export
ready-to-use Flutter code. Built with Flutter (web, Android, macOS).

## Features

- **Device catalog** — 108 phone presets (Apple, Samsung, Google) with
  verified logical sizes where official sources exist, foldable inner/outer
  displays, tablets, Macs, watches and custom sizes.
- **Infinite canvas** — many artboards side by side; drag a title to move an
  artboard, drag its bottom edge to make a long scrolling screen.
- **Alignment** — 7 align operations plus *align to* selection / artboard /
  key object / parent, distribute, equal spacing, custom gaps, tidy up.
- **Rulers, guides, grids & smart snapping** — zoom-aware rulers, draggable
  guides, square/column/row grids, distance indicators.
- **Pen-first tablet mode** — the stylus edits, a resting palm or single
  finger is ignored, two fingers pan and pinch-zoom, and the view can be
  locked while you edit.
- **Run** — preview screens inside a device frame, scroll long screens and
  follow prototype links between screens.
- **Shapes** — boxes and images can be rectangles, ellipses, triangles,
  diamonds, pentagons, hexagons or stars.
- **Resize from any side** — eight handles (corners and edge midpoints) with
  snapping; Shift keeps the aspect ratio on corners.
- **Export image** — save any screen as a PNG at 1x–4x, with or without its
  background.
- **Code export** — pick Flutter, SwiftUI, Jetpack Compose, HTML or React
  and copy the generated code.
- 4,900+ icons from [amazing_icons](https://pub.dev/packages/amazing_icons).

## Getting started

```bash
flutter pub get
flutter run -d chrome      # or: -d macos, or an Android device
flutter test
```

> If the project path contains a `:` character, the Android build in this
> repo moves Gradle's build output to `~/.gradle/rexa-ui-studio-build`,
> because `:` is Java's classpath separator.

## Support the project ☕

If Rexa UI Studio is useful to you, you can support its development:

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/francehk235)

**Buy Me a Coffee:** https://buymeacoffee.com/francehk235

## License

[MIT](LICENSE) © FranceHK
