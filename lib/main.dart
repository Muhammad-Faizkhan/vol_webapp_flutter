import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api/api_client.dart';
import 'core/auth/auth.dart';
import 'core/env.dart';
import 'core/query.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode.dart';
import 'ui/toast.dart';

Future<void> main() async {
  usePathUrlStrategy();

  // Restore the session before the first frame so the router never flashes the login screen.
  final api = ApiClient(apiUrl);
  final (prefs, _) = await (SharedPreferences.getInstance(), api.refresh()).wait;

  runApp(ProviderScope(overrides: [apiProvider.overrideWithValue(api), prefsProvider.overrideWithValue(prefs)], child: const VolApp()));
}

class VolApp extends ConsumerWidget {
  const VolApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Drop cached responses on sign-out so the next account never sees the last one's data.
    ref.listen(authProvider, (before, now) {
      if (before != null && now == null) invalidateQueries(ref);
    });

    return MaterialApp.router(
      title: 'VÔL Network',
      debugShowCheckedModeBanner: false,
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (_, child) => ToastHost(child: child!),
    );
  }
}
