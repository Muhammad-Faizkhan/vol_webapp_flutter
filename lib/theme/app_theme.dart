import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

ThemeData lightTheme() => _theme(
  const ColorScheme.light(
    primary: Dak.cta,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF171717),
    outline: Light.border,
  ),
  scaffold: Light.appBg,
);

ThemeData darkTheme() => _theme(
  const ColorScheme.dark(primary: Dak.cta, onPrimary: Colors.white, surface: Dak.surface, onSurface: Dak.heading, outline: Dak.border),
  scaffold: Dak.bg,
);

// Widgets style themselves to match the web classes, so the theme only sets fonts and base colours.
// Inter is the body font, as in apps/web; Geist is applied where the web uses font-heading.
ThemeData _theme(ColorScheme colors, {required Color scaffold}) {
  final base = ThemeData(colorScheme: colors, scaffoldBackgroundColor: scaffold, splashFactory: NoSplash.splashFactory);
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: colors.onSurface, displayColor: colors.onSurface),
    textSelectionTheme: TextSelectionThemeData(selectionColor: Dak.cta.withValues(alpha: .3), cursorColor: colors.onSurface),
  );
}
