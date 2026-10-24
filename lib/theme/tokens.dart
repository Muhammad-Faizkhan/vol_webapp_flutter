import 'package:flutter/painting.dart';

// Copied from packages/ui/src/tokens.css and apps/web/src/app/globals.css. Keep the names in sync.
abstract final class Dak {
  static const bg = Color(0xFF050505);
  static const heading = Color(0xFFF4F4F6);
  static const body = Color(0xFFC8CBD0);
  static const cta = Color(0xFF9436FB);
  static const muted = Color(0xFF777A82);
  static const line = Color(0xFFC793FF);
  static const surface = Color(0xFF121212);
  static const border = Color(0xFF2B2B31);
}

abstract final class Light {
  static const appBg = Color(0xFFFBF8FF);
  static const heading = Color(0xFF4F626E);
  static const body = Color(0xFF63758B);
  static const border = Color(0xFFC6C6CD);
  static const sidebarActive = Color(0xFF4A1B7D);
  static const badge = Color(0xFFD0A6FC);
  static const darkSurface = Color(0xFF020204);
}

abstract final class Auth {
  static const slate = Color(0xFF63758B);
  static const navy = Color(0xFF4F626E);
  static const bg2 = Color(0xFFFAFAFA);
  static const checkbox = Color(0xFF48576E);
}

// Hard-coded hex values the web screens use directly.
abstract final class Hex {
  static const black = Color(0xFF020204);
  static const text = Color(0xFF2B2B31);
  static const google = Color(0xFF34A853);
  static const error = Color(0xFFEF4444);
  static const errorDark = Color(0xFFF87171);
}
