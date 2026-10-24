import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/auth/me.dart';
import '../../models/user.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/button.dart';
import '../../ui/form_fields.dart';
import '../../ui/layout.dart';
import '../../ui/text_field.dart';
import '../../ui/toggle.dart';
import '../auth/widgets/auth_shell.dart';

class NetworkVisibilityPage extends ConsumerStatefulWidget {
  const NetworkVisibilityPage({super.key});

  @override
  ConsumerState<NetworkVisibilityPage> createState() => _NetworkVisibilityPageState();
}

class _NetworkVisibilityPageState extends ConsumerState<NetworkVisibilityPage> {
  late Access _access = ref.read(authProvider)?.profile?.visibility ?? Access.public;
  late bool _searchIndexing = ref.read(authProvider)?.profile?.searchIndexing ?? true;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _submitting = true;
    });
    final api = ref.read(apiProvider);
    try {
      await api.patch<dynamic>('/users/me/preferences', {'visibility': accessJson(_access), 'searchIndexing': _searchIndexing});
      final updated = Me.fromJson(await api.post<Map<String, dynamic>>('/users/me/complete-onboarding'));
      api.updateUser(updated);
      if (mounted) context.go(homeFor(updated));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final line = dark ? Dak.border : Dak.line;
    final gap = context.dvh(8, 1.5, 24);

    return AuthShell(
      contentWidth: 652,
      backHref: '/create-profile',
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 396),
            child: Column(
              children: [
                SizedBox(
                  height: context.dvh(40, 6, 108),
                  child: const AssetIcon('illustrations/vol-logo.png', fit: BoxFit.cover),
                ),
                SizedBox(height: context.dvh(6, 1, 24)),
                Text(
                  'Profile Setup Complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: context.isSm ? context.dvh(20, 4, 32) : 24,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -.32,
                    color: dark ? Dak.heading : Hex.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Configure your network presence and launch your workspace.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: dark ? Dak.body : Hex.text),
                ),
              ],
            ),
          ),
          SizedBox(height: context.dvh(6, 1.5, 40)),
          GlowCard(
            borderColor: Dak.cta,
            padding: EdgeInsets.symmetric(horizontal: context.isSm ? 41 : 24, vertical: context.dvh(12, 2.5, 49)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(bottom: context.dvh(8, 1.5, 17)),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: line)),
                  ),
                  child: Text(
                    'Network Visibility',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: dark ? Dak.heading : Hex.black),
                  ),
                ),
                SizedBox(height: context.dvh(6, 1.2, 16)),
                _Choice(
                  selected: _access == Access.public,
                  onTap: () => setState(() => _access = Access.public),
                  icon: 'icons/globe.svg',
                  iconSize: const Size(17, 17),
                  title: 'Public Portfolio',
                  recommended: true,
                  shadow: true,
                  body:
                      'Your profile, projects, and credentials will be visible to all platform users and indexed '
                      'in the global directory.',
                ),
                SizedBox(height: gap),
                _Choice(
                  selected: _access == Access.private,
                  onTap: () => setState(() => _access = Access.private),
                  icon: 'icons/lock-small.svg',
                  iconSize: const Size(14, 18),
                  title: 'Private Network',
                  body:
                      'Your profile remains hidden. You can only collaborate via direct invites from existing '
                      'workspaces or verified connections.',
                ),
                SizedBox(height: gap),
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text(
                    'DATA PREFERENCES',
                    style: GoogleFonts.geist(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .7,
                      color: dark ? Dak.heading : Hex.black,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allow Search Indexing',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                letterSpacing: .28,
                                color: dark ? Dak.heading : Hex.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Include profile in internal talent searches.',
                              style: TextStyle(fontSize: 16, color: dark ? Dak.body : Hex.text),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      VolToggle(
                        value: _searchIndexing,
                        trackColor: dark ? Dak.cta : Hex.black,
                        onChanged: (v) => setState(() => _searchIndexing = v),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[SizedBox(height: gap), ErrorText(_error!)],
                SizedBox(height: context.dvh(6, 1.2, 16) + 8),
                VolButton(
                  label: _submitting ? 'Launching…' : 'Complete Setup',
                  variant: ButtonVariant.cta,
                  radius: dark ? 999 : 16,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.iconSize,
    required this.title,
    required this.body,
    this.recommended = false,
    this.shadow = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final String icon;
  final Size iconSize;
  final String title;
  final String body;
  final bool recommended;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final fill = selected ? (dark ? Dak.cta : Hex.black) : (dark ? Colors.transparent : Colors.white);
    final titleColor = selected ? Colors.white : (dark ? Dak.heading : Hex.black);
    final bodyColor = selected ? Colors.white.withValues(alpha: dark ? .9 : 1) : (dark ? Dak.body : Hex.text);
    // The icons are drawn black; the web inverts them on the dark fill and in dark mode.
    final iconColor = selected || dark ? Colors.white : null;
    final radioColor = selected && dark ? Colors.white : Dak.cta;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(context.dvh(10, 2, 17)),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? (dark ? Dak.cta : Hex.black) : (dark ? Dak.border : Light.border)),
            boxShadow: shadow ? [BoxShadow(color: Hex.black.withValues(alpha: .5), offset: const Offset(0, 8), blurRadius: 12)] : null,
          ),
          child: Row(
            children: [
              _Radio(selected: selected, color: radioColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AssetIcon(icon, width: iconSize.width, height: iconSize.height, color: iconColor),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: .28, color: titleColor),
                          ),
                        ),
                        if (recommended) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: selected
                                  ? (dark ? Colors.white.withValues(alpha: .2) : const Color(0xFF6F23C2))
                                  : (dark ? Dak.cta.withValues(alpha: .1) : Auth.navy.withValues(alpha: .1)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'RECOMMENDED',
                              style: GoogleFonts.geist(
                                fontSize: 10,
                                letterSpacing: .5,
                                color: selected ? Colors.white : (dark ? Dak.heading : const Color(0xFF45464D)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(body, style: TextStyle(fontSize: 16, color: bodyColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.white,
        border: Border.all(color: selected ? color : const Color(0xFF767676)),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color == Colors.white ? Dak.cta : Colors.white),
              ),
            )
          : null,
    );
  }
}
