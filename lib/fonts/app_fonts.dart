import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font families a text element can use (Google Fonts). `null` on an
/// element means the platform's system font.
const fontFamilies = [
  'Inter',
  'Roboto',
  'Poppins',
  'Montserrat',
  'Open Sans',
  'Lato',
  'Nunito',
  'DM Sans',
  'Raleway',
  'Rubik',
  'Work Sans',
  'Oswald',
  'Bebas Neue',
  'Playfair Display',
  'Merriweather',
  'Lora',
  'Source Code Pro',
  'Fira Code',
  'Pacifico',
  'Lobster',
  'Caveat',
];

/// The nine standard font weights.
enum FontWeightName {
  thin(100, 'Thin'),
  extraLight(200, 'Extra light'),
  light(300, 'Light'),
  regular(400, 'Regular'),
  medium(500, 'Medium'),
  semiBold(600, 'Semi bold'),
  bold(700, 'Bold'),
  extraBold(800, 'Extra bold'),
  black(900, 'Black');

  const FontWeightName(this.value, this.label);
  final int value;
  final String label;

  static FontWeightName of(int value) =>
      values.firstWhere((w) => w.value >= value, orElse: () => black);
}

/// Flutter's [FontWeight] for a 100–900 weight.
FontWeight fontWeightOf(int value) =>
    FontWeight.values[(value ~/ 100 - 1).clamp(0, 8)];

/// Whether fonts are downloaded from Google Fonts. Tests turn it off so
/// they never touch the network.
bool fetchGoogleFonts = true;

/// [base] drawn in [family] (system font when null).
TextStyle styleWithFont(String? family, TextStyle base) {
  if (family == null) return base;
  if (!fetchGoogleFonts) return base.copyWith(fontFamily: family);
  try {
    return GoogleFonts.getFont(family, textStyle: base);
  } catch (_) {
    return base;
  }
}
