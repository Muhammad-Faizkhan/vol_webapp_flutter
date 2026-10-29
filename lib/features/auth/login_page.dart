import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/auth/me.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/button.dart';
import '../../ui/layout.dart';
import '../../ui/link_text.dart';
import '../../ui/text_field.dart';
import 'widgets/auth_shell.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.next, this.persona, this.reset = false});

  final String? next;
  final String? persona;
  final bool reset;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _otpUrl(String email, String mode) => Uri(
    path: '/otp-verification',
    queryParameters: {'email': email, 'mode': mode, if (widget.next != null) 'next': widget.next},
  ).toString();

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password to continue.');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });
    final api = ref.read(apiProvider);
    try {
      final result = await api.post<Map<String, dynamic>>('/auth/login', {'email': email, 'password': password});
      if (!mounted) return;
      if (result['twoFactorRequired'] == true) return context.go(_otpUrl(email, 'login'));
      final user = api.setSession(result);
      if (mounted) context.go(widget.next ?? homeFor(user));
    } catch (e) {
      if (!mounted) return;
      // The API just emailed a fresh code; finish verification, then continue onboarding.
      if (e is ApiError && e.code == 'EMAIL_NOT_VERIFIED') return context.go(_otpUrl(email, 'verify'));
      setState(() {
        _error = errorMessage(e);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final persona = widget.persona;
    final notice = widget.reset ? 'Password updated. Log in with your new password.' : null;

    return AuthShell(
      backHref: '/',
      child: AutofillGroup(
        child: Column(
          children: [
            AuthHeading(
              title: 'Welcome Back',
              subtitle: 'Enter your email below to login your account',
              logoSize: context.dvh(72, 11, 120),
            ),
            SizedBox(height: context.dvh(12, 2.5, 50)),
            VolButton(
              label: 'Login with google',
              variant: ButtonVariant.google,
              icon: const AssetIcon('icons/google.svg', width: 24, height: 24),
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            VolButton(
              label: 'Login with Apple',
              variant: ButtonVariant.apple,
              icon: const AssetIcon('icons/apple.svg', width: 20, height: 24),
              onPressed: () {},
            ),
            SizedBox(height: context.dvh(8, 1.5, 24)),
            Row(
              children: [
                Expanded(child: Divider(height: 1, color: dark ? Dak.border : Hex.text.withValues(alpha: .2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Or continue with', style: TextStyle(fontSize: 14, color: context.pick(Hex.black, Dak.body))),
                ),
                Expanded(child: Divider(height: 1, color: dark ? Dak.border : Hex.text.withValues(alpha: .2))),
              ],
            ),
            SizedBox(height: context.dvh(8, 1.5, 24)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Email'),
                const SizedBox(height: 8),
                VolTextField(
                  controller: _email,
                  icon: const AssetIcon('icons/gmail.svg', width: 22, height: 22),
                  hint: 'User@domain.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                const FieldLabel('Password'),
                const SizedBox(height: 8),
                VolTextField(
                  controller: _password,
                  icon: AssetIcon('icons/lock-keyhole.svg', width: 22, height: 22, color: context.pick(Colors.black, null)),
                  hint: 'Enter your password',
                  obscure: true,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submitting ? null : _submit(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: LinkText(text: "Can't login?", link: 'Reset Password', onTap: () => context.go('/forgot-password')),
                ),
              ],
            ),
            SizedBox(height: context.dvh(12, 2, 32)),
            if (notice != null && _error == null) ...[
              SizedBox(
                width: double.infinity,
                child: Text(
                  notice,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Hex.google),
                ),
              ),
              SizedBox(height: context.dvh(12, 2, 32)),
            ],
            if (_error != null) ...[ErrorText(_error!), SizedBox(height: context.dvh(12, 2, 32))],
            VolButton(label: _submitting ? 'Logging in…' : 'Login', variant: ButtonVariant.dark, onPressed: _submitting ? null : _submit),
            SizedBox(height: context.dvh(8, 2, 40)),
            LinkText(
              text: "Don't have an account?",
              link: 'Sign Up',
              onTap: () => context.go(persona != null ? '/signup?persona=$persona' : '/signup'),
            ),
          ],
        ),
      ),
    );
  }
}
