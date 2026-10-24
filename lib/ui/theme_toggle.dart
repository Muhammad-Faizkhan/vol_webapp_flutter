import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_mode.dart';
import '../theme/tokens.dart';
import 'layout.dart';

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    return Tooltip(
      message: 'Toggle theme',
      child: Material(
        type: MaterialType.transparency,
        shape: CircleBorder(side: BorderSide(color: dark ? Dak.border : Light.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => ref.read(themeModeProvider.notifier).toggle(),
          child: SizedBox.square(
            dimension: 44,
            child: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: dark ? 20 : 18,
              color: dark ? Dak.heading : Hex.black,
            ),
          ),
        ),
      ),
    );
  }
}
