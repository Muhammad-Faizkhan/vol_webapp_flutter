import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Overridden in main() once SharedPreferences has loaded.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// Light unless the visitor picked dark, like the web app (it ignores the OS setting).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'vol-theme';

  @override
  ThemeMode build() => ref.read(prefsProvider).getString(_key) == 'dark' ? ThemeMode.dark : ThemeMode.light;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    ref.read(prefsProvider).setString(_key, state == ThemeMode.dark ? 'dark' : 'light');
  }
}
