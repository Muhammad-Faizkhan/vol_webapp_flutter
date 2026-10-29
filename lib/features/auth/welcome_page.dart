import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/layout.dart';
import '../../ui/link_text.dart';
import '../../ui/swirl_background.dart';
import '../../ui/theme_toggle.dart';
import 'widgets/role_card.dart';

const _tagline = 'Connect With Instructors And Engineers Through Shared Digital Canvases';

/// The landing page (`/`) and `/join-network` share this layout; only the button labels and the
/// login link differ.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, this.joinNetwork = false});

  final bool joinNetwork;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final wide = context.isLg;
    final gap = joinNetwork ? context.dvh(12, 2, 24) : context.dvh(8, 1.2, 24);

    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: context.isSm ? 40 : 24, vertical: context.dvh(8, 1.5, 40)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 570),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 503),
                child: Column(
                  children: [
                    SizedBox(height: context.dvh(96, 12, 150), child: const AssetIcon('illustrations/vol-logo.png')),
                    SizedBox(height: context.dvh(8, 1.5, 24)),
                    Text(
                      'Join the VÔL Network',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.dvh(20, 4, 32),
                        fontWeight: FontWeight.w700,
                        color: dark ? Dak.heading : Auth.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select your account type to begin constructing your professional '
                      'profile within our precision engineering ecosystem.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, height: 23 / 16, fontWeight: FontWeight.w500, color: dark ? Dak.body : Auth.slate),
                    ),
                  ],
                ),
              ),
              SizedBox(height: gap),
              RoleCard(
                icon: 'icons/individual-dark.png',
                title: 'Individual User',
                description: 'Join workspaces, learn in classrooms and collaborate on shared canvases with engineers and instructors.',
                buttonLabel: joinNetwork ? 'Login in as Individual profile' : 'Continue as Individual',
                persona: 'individual',
              ),
              SizedBox(height: context.dvh(8, 1.5, 24)),
              RoleCard(
                icon: 'icons/business-dark.png',
                title: 'Business Profile',
                description: 'Publish your product catalog, run training classrooms and work with customers on shared canvases.',
                buttonLabel: joinNetwork ? 'Login in as Business profile' : 'Continue as Business',
                persona: 'business',
                primary: false,
                roundIcon: false,
              ),
              if (!joinNetwork) ...[
                SizedBox(height: gap),
                LinkText(
                  text: 'Already have an account?',
                  link: 'Log In',
                  fontSize: 16,
                  underline: false,
                  textColor: dark ? Dak.heading : Auth.slate,
                  onTap: () => context.go('/login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final tagline = Text(
      _tagline,
      textAlign: wide ? TextAlign.left : TextAlign.center,
      style: TextStyle(fontSize: wide ? 42 : (context.isSm ? 32 : 24), fontWeight: FontWeight.w700, color: dark ? Dak.heading : Dak.cta),
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
                  width: context.screenWidth / 2,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const AssetIcon('illustrations/join-network-dark-hero.png', fit: BoxFit.cover),
                      Positioned(
                        left: 40,
                        top: 64,
                        right: 40,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: tagline),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: context.screenHeight),
                      child: Center(child: content),
                    ),
                  ),
                ),
              ],
            )
          else
            SingleChildScrollView(
              child: Column(
                children: [
                  Padding(padding: EdgeInsets.fromLTRB(context.isSm ? 40 : 24, 64, context.isSm ? 40 : 24, 0), child: tagline),
                  content,
                ],
              ),
            ),
          Positioned(right: context.isSm ? 24 : 16, top: context.isSm ? 24 : 16, child: const ThemeToggleButton()),
        ],
      ),
    );
  }
}
