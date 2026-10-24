import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/tokens.dart';
import '../../../ui/asset_icon.dart';
import '../../../ui/layout.dart';
import '../../../ui/swirl_background.dart';
import '../../../ui/theme_toggle.dart';

/// Port of components/auth/AuthShell.tsx: hero illustration on the left from lg up, form on the right.
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.child, this.backHref = '/login', this.showBack = true, this.contentWidth = 570});

  final Widget child;
  final String backHref;
  final bool showBack;
  final double contentWidth;

  @override
  Widget build(BuildContext context) {
    final wide = context.isLg;
    final edge = context.isSm ? 24.0 : 16.0;
    final top = wide ? context.dvh(16, 3, 40) : edge;

    final back = InkWell(
      onTap: () => context.go(backHref),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.flip(
            flipX: true,
            child: AssetIcon(
              context.pick('icons/arrow-narrow-right.svg', 'icons/arrow-narrow-right-light.svg'),
              width: 24,
              height: 24,
              color: context.pick(Hex.black, null),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Back',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: context.pick(Hex.black, Dak.heading)),
          ),
        ],
      ),
    );

    final form = SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: wide ? context.dvw(24, 4, 60) : (context.isSm ? 40 : 16), vertical: context.dvh(12, 4, 60)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentWidth),
          child: child,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: context.pick(Light.appBg, Dak.bg),
      body: Stack(
        children: [
          const SwirlBackground(),
          if (wide)
            Row(
              children: [
                SizedBox(
                  width: context.screenWidth * .42,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SizedBox(
                        height: context.dvh(280, 62, 620),
                        child: AspectRatio(aspectRatio: 773 / 918, child: const AssetIcon('illustrations/auth-hero.png')),
                      ),
                    ),
                  ),
                ),
                Expanded(child: form),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showBack) Padding(padding: EdgeInsets.all(edge), child: back),
                Expanded(child: form),
              ],
            ),
          if (wide && showBack) Positioned(left: 40, top: top, child: back),
          Positioned(right: wide ? 40 : edge, top: wide ? top : edge, child: const ThemeToggleButton()),
        ],
      ),
    );
  }
}

/// Logo, title and subtitle at the top of every auth form.
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.title, required this.subtitle, required this.logoSize});

  final String title;
  final String subtitle;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        children: [
          AssetIcon('illustrations/vol-logo.png', width: logoSize, height: logoSize),
          SizedBox(height: context.dvh(6, 1, 24)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.isSm ? context.dvh(20, 4, 32) : 24,
              fontWeight: FontWeight.w700,
              color: context.pick(Hex.black, Dak.heading),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 23 / 16, fontWeight: FontWeight.w500, color: context.pick(Hex.text, Dak.body)),
          ),
        ],
      ),
    );
  }
}
