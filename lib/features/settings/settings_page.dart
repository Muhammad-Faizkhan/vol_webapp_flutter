import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/auth/me.dart';
import '../../core/query.dart';
import '../../models/user.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/card_box.dart';
import '../../ui/layout.dart';
import '../../ui/modal.dart';
import '../../ui/toast.dart';
import '../../ui/toggle.dart';

enum _Dialog { password, delete, notifications, about }

typedef _Item = ({String icon, String label, bool danger, _Dialog? open, String? href});

const List<(String, List<_Item>)> _sections = [
  (
    'Account',
    [
      (icon: 'settings-lock', label: 'Change password', danger: false, open: _Dialog.password, href: null),
      (icon: 'settings-delete', label: 'Delete account', danger: true, open: _Dialog.delete, href: null),
    ],
  ),
  ('Preferences', [(icon: 'settings-bell', label: 'Notifications', danger: false, open: _Dialog.notifications, href: null)]),
  (
    'Privacy & Legal',
    [
      (icon: 'settings-privacy', label: 'Privacy policy', danger: false, open: null, href: '/privacy'),
      (icon: 'settings-terms', label: 'Terms & Conditions', danger: false, open: null, href: '/terms'),
      (icon: 'settings-about', label: 'About Volt', danger: false, open: _Dialog.about, href: null),
    ],
  ),
  ('Support', [(icon: 'settings-help', label: 'Help & Feedback', danger: false, open: null, href: 'mailto:')]),
];

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    final platform = ref.watch(query('/platform')).value as Map<String, dynamic>?;
    final name = platform?['name'] as String? ?? 'VÔL';

    void open(_Dialog d) => showModal<void>(
      context,
      maxWidth: 480,
      builder: (_) => switch (d) {
        _Dialog.password => const _ChangePassword(),
        _Dialog.delete => const _DeleteAccount(),
        _Dialog.notifications => const _Preferences(),
        _Dialog.about => _DialogShell(
          title: 'About $name',
          children: [
            Text(
              '$name connects instructors, engineers and trade businesses through shared digital canvases, classrooms and product catalogs.',
              style: TextStyle(fontSize: 16, color: context.body),
            ),
            Text(
              '${platform?['domain'] ?? ''} · Support: ${platform?['supportEmail'] ?? ''}',
              style: TextStyle(fontSize: 14, color: dark ? Dak.muted : const Color(0xFF929292)),
            ),
          ],
        ),
      },
    );

    Widget row(_Item item) {
      return Material(
        color: dark ? Dak.surface : const Color(0xFF251437),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Hex.text.withValues(alpha: .4)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (item.href == 'mailto:') {
              launchUrl(Uri.parse('mailto:${platform?['supportEmail'] ?? ''}?subject=Feedback'));
            } else if (item.href != null) {
              context.go(item.href!);
            } else {
              open(item.open!);
            }
          },
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.danger ? const Color(0x1AC32323) : Colors.white.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AssetIcon('icons/${item.icon}.svg', width: 16, height: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.label, style: const TextStyle(fontSize: 16, color: Colors.white)),
                ),
                const AssetIcon('icons/settings-chevron.svg', width: 16, height: 16),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Settings',
          style: TextStyle(fontSize: context.isSm ? 32 : 24, fontWeight: FontWeight.w700, letterSpacing: -.32, color: context.ink),
        ),
        const SizedBox(height: 4),
        Text('Manage your account, preferences, privacy, and workspace experience.', style: TextStyle(fontSize: 14, color: context.body)),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.topLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 570),
            padding: EdgeInsets.all(dark ? 40 : 25),
            decoration: dark
                ? BoxDecoration(
                    color: const Color(0xFF0F090C),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Dak.line, width: .5),
                    boxShadow: [
                      BoxShadow(color: Dak.cta.withValues(alpha: .5), offset: const Offset(0, 32), blurRadius: 32, spreadRadius: -16),
                    ],
                  )
                : cardDecoration(context, blur: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (title, items)) in _sections.indexed) ...[
                  if (i > 0) const SizedBox(height: 24),
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.ink),
                  ),
                  for (final item in items)
                    if (item.open != _Dialog.delete || platform?['selfServiceDeletion'] != false) ...[
                      const SizedBox(height: 12),
                      row(item),
                    ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogShell extends StatelessWidget {
  const _DialogShell({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: context.ink),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: Text('✕', style: TextStyle(fontSize: 20, color: context.ink)),
              ),
            ],
          ),
          for (final c in children) ...[const SizedBox(height: 16), c],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, this.obscure = false, this.onChanged, this.autofill});

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofill;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: dark ? Dak.bg : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dark ? Dak.border : Light.border),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        onChanged: onChanged,
        autofillHints: autofill,
        style: TextStyle(fontSize: 16, color: dark ? Dak.heading : Hex.black),
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 16, color: dark ? Dak.muted : const Color(0xFF757575)),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.label, required this.onTap, this.color = Dak.cta, this.disabledOpacity = .6});

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double disabledOpacity;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? disabledOpacity : 1,
    child: Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ChangePassword extends ConsumerStatefulWidget {
  const _ChangePassword();

  @override
  ConsumerState<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<_ChangePassword> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty || _next.text.isEmpty || _confirm.text.isEmpty) return setState(() => _error = 'Fill in every field.');
    if (_next.text.length < 8) return setState(() => _error = 'New password must be at least 8 characters.');
    if (_next.text != _confirm.text) return setState(() => _error = "New passwords don't match.");
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).post<dynamic>('/auth/change-password', {'currentPassword': _current.text, 'newPassword': _next.text});
      ref.read(toastProvider.notifier).show('Password changed. Other devices were signed out.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: _DialogShell(
        title: 'Change password',
        children: [
          _Field(controller: _current, hint: 'Current password', obscure: true, autofill: const [AutofillHints.password]),
          _Field(controller: _next, hint: 'New password', obscure: true, autofill: const [AutofillHints.newPassword]),
          _Field(controller: _confirm, hint: 'Confirm new password', obscure: true, autofill: const [AutofillHints.newPassword]),
          if (_error != null) Text(_error!, style: const TextStyle(fontSize: 14, color: Hex.error)),
          _SubmitButton(label: _busy ? 'Saving…' : 'Update password', onTap: _busy ? null : _submit),
        ],
      ),
    );
  }
}

class _DeleteAccount extends ConsumerStatefulWidget {
  const _DeleteAccount();

  @override
  ConsumerState<_DeleteAccount> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends ConsumerState<_DeleteAccount> {
  final _password = TextEditingController();
  final _typed = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _typed.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = ref.read(apiProvider);
    try {
      await api.post<dynamic>('/users/me/delete', {'password': _password.text});
      await api.logout();
      if (mounted) {
        Navigator.pop(context);
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_busy && _typed.text == 'DELETE' && _password.text.isNotEmpty;
    return _DialogShell(
      title: 'Delete account',
      children: [
        Text(
          "This permanently erases your profile and signs you out everywhere. Workspaces you own are deleted for all members. This can't be undone.",
          style: TextStyle(fontSize: 14, color: context.body),
        ),
        _Field(controller: _password, hint: 'Your password', obscure: true, onChanged: (_) => setState(() {})),
        _Field(controller: _typed, hint: 'Type "DELETE" to confirm', onChanged: (_) => setState(() {})),
        if (_error != null) Text(_error!, style: const TextStyle(fontSize: 14, color: Hex.error)),
        _SubmitButton(
          label: _busy ? 'Deleting…' : 'Delete my account',
          color: const Color(0xFFDC2626),
          disabledOpacity: .5,
          onTap: ready ? _submit : null,
        ),
      ],
    );
  }
}

class _Preferences extends ConsumerWidget {
  const _Preferences();

  Future<void> _update(WidgetRef ref, Map<String, dynamic> patch) async {
    final api = ref.read(apiProvider);
    try {
      api.updateUser(Me.fromJson(await api.patch<Map<String, dynamic>>('/users/me/preferences', patch)));
    } catch (e) {
      ref.read(toastProvider.notifier).error(errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    final p = ref.watch(authProvider)?.profile;
    final grey = dark ? Dak.muted : const Color(0xFF929292);

    Widget row(String label, String hint, bool value, ValueChanged<bool> onChanged) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? Dak.border : Light.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: context.ink),
                ),
                Text(hint, style: TextStyle(fontSize: 14, color: grey)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          VolToggle(value: value, trackColor: dark ? Dak.cta : Hex.black, onChanged: onChanged),
        ],
      ),
    );

    return _DialogShell(
      title: 'Notifications & privacy',
      children: p == null
          ? [const Text('Finish your profile to manage preferences.', style: TextStyle(fontSize: 14, color: Color(0xFF929292)))]
          : [
              row(
                'Email notifications',
                'Invites, warnings and security alerts by email',
                p.emailNotifications,
                (v) => _update(ref, {'emailNotifications': v}),
              ),
              row(
                'Public profile',
                'Anyone on VÔL can see your profile',
                p.visibility == Access.public,
                (v) => _update(ref, {'visibility': v ? 'PUBLIC' : 'PRIVATE'}),
              ),
              row('Search indexing', 'Show up in Explore and search', p.searchIndexing, (v) => _update(ref, {'searchIndexing': v})),
            ],
    );
  }
}
