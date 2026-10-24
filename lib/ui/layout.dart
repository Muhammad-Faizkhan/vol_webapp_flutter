import 'package:flutter/material.dart';

// Tailwind breakpoints used by apps/web.
const sm = 640.0;
const lg = 1024.0;

extension LayoutContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isSm => screenWidth >= sm;
  bool get isLg => screenWidth >= lg;

  /// CSS `clamp(min, <vh>dvh, max)`.
  double dvh(double min, double vh, double max) => (screenHeight * vh / 100).clamp(min, max);

  /// CSS `clamp(min, <vw>vw, max)`.
  double dvw(double min, double vw, double max) => (screenWidth * vw / 100).clamp(min, max);

  /// Picks the light or dark variant, like Tailwind's `dark:` prefix.
  T pick<T>(T light, T dark) => isDark ? dark : light;
}
