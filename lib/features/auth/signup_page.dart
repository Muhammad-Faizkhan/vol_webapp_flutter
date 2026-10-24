import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/auth/me.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/button.dart';
import '../../ui/checkbox.dart';
import '../../ui/layout.dart';
import '../../ui/link_text.dart';
import '../../ui/text_field.dart';
import 'auth_flow.dart';
import 'widgets/auth_shell.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key, this.persona});

  final String? persona;

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _agree = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty || _confirm.text.isEmpty) {
      return setState(() => _error = 'Fill in every field to continue.');
    }
    if (password != _confirm.text) return setState(() => _error = "Passwords don't match.");
    if (!_agree) return setState(() => _error = 'Please agree to the Terms & Conditions and Privacy Policy.');

    setState(() {
      _error = null;
      _submitting = true;
    });

    final persona = widget.persona;
    final accountType = switch (persona) {
      'business' => 'BUSINESS',
      'individual' => 'INDIVIDUAL',
      _ => null,
    };
    // Without a persona the account type is picked on the join-network screen after verification.
    final next = accountType == null ? '/join-network' : null;
    final api = ref.read(apiProvider);

    try {
      final result = await api.post<Map<String, dynamic>>('/auth/signup', {
        'email': email,
        'password': password,
        if (accountType != null) 'accountType': accountType,
      });
      if (!mounted) return;
      if (result.containsKey('accessToken')) {
        // Email verification is switched off by the admins: the account is ready straight away.
        final user = api.setSession(result);
        return context.go(next ?? homeFor(user));
      }
      final devCode = result['devCode'] as String?;
      if (devCode != null) ref.read(authFlowProvider).devCodes[email] = devCode;
      context.go(
        Uri(
          path: '/otp-verification',
          queryParameters: {
            'email': email,
            'mode': 'verify',
            if (next != null) 'next': next,
            // Lets the OTP screen's "Back" return to this persona's signup instead of asking for the role again.
            if (accountType != null) 'persona': persona,
          },
        ).toString(),
      );
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
    final persona = widget.persona;
    final loginHref = persona != null ? '/login?persona=$persona' : '/login';
    final lock = AssetIcon('icons/lock-keyhole.svg', width: 22, height: 22, color: context.pick(Colors.black, null));

    Widget field(String label, Widget input) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [FieldLabel(label), const SizedBox(height: 6), input]),
    );

    return AuthShell(
      backHref: loginHref,
      child: AutofillGroup(
        child: Column(
          children: [
            AuthHeading(
              title: 'Let’s Sign Up',
              subtitle: 'Enter your details below to sign up your account',
              logoSize: context.dvh(36, 7, 100),
            ),
            SizedBox(height: context.dvh(8, 1.5, 24)),
            field(
              'Email',
              VolTextField(
                controller: _email,
                icon: const AssetIcon('icons/gmail.svg', width: 22, height: 22),
                hint: 'User@domain.com',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
              ),
            ),
            field(
              'Create Password',
              VolTextField(
                controller: _password,
                icon: lock,
                hint: 'Enter your password',
                obscure: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
              ),
            ),
            field(
              'Confirm Password',
              VolTextField(
                controller: _confirm,
                icon: lock,
                hint: 'Confirm your password',
                obscure: true,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submitting ? null : _submit(),
              ),
            ),
            const SizedBox(height: 4),
            _AgreeRow(value: _agree, onChanged: (v) => setState(() => _agree = v)),
            SizedBox(height: context.dvh(12, 2, 32)),
            if (_error != null) ...[ErrorText(_error!), SizedBox(height: context.dvh(12, 2, 32))],
            VolButton(
              label: _submitting ? 'Creating account…' : 'Sign Up',
              variant: ButtonVariant.dark,
              onPressed: _submitting ? null : _submit,
            ),
            SizedBox(height: context.dvh(8, 2, 40)),
            LinkText(text: 'Already have an account?', link: 'Sign In', onTap: () => context.go(loginHref)),
          ],
        ),
      ),
    );
  }
}

class _AgreeRow extends StatelessWidget {
  const _AgreeRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    TextSpan link(String text, String href) => TextSpan(
      text: text,
      mouseCursor: SystemMouseCursors.click,
      recognizer: TapGestureRecognizer()..onTap = () => context.go(href),
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: Dak.cta,
        decoration: dark ? null : TextDecoration.underline,
        decorationColor: Dak.cta,
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: VolCheckbox(value: value, onChanged: onChanged),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 14, height: 20 / 14, color: dark ? Dak.body : Hex.text),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    link('Terms & Conditions', '/terms'),
                    const TextSpan(text: ' | '),
                    link('Privacy Policy', '/privacy'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
