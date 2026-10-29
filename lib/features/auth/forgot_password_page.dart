import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../ui/asset_icon.dart';
import '../../ui/button.dart';
import '../../ui/layout.dart';
import '../../ui/text_field.dart';
import 'widgets/auth_shell.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty) return setState(() => _error = 'Enter your email address to continue.');

    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref.read(apiProvider).post<dynamic>('/auth/forgot-password', {'email': email});
      if (mounted) {
        context.go(Uri(path: '/otp-verification', queryParameters: {'email': email, 'mode': 'reset'}).toString());
      }
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
    final gap = context.dvh(16, 3, 32);

    return AuthShell(
      child: Column(
        children: [
          AuthHeading(
            title: 'Forgot Password?',
            subtitle: 'Enter email to get One-Time Password to verify your account.',
            logoSize: context.dvh(96, 13, 140),
          ),
          SizedBox(height: context.dvh(12, 2, 24)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Email'),
              const SizedBox(height: 8),
              VolTextField(
                controller: _email,
                icon: const AssetIcon('icons/gmail.svg', width: 22, height: 22),
                hint: 'Enter email address',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => _submitting ? null : _submit(),
              ),
            ],
          ),
          SizedBox(height: gap),
          if (_error != null) ...[ErrorText(_error!), SizedBox(height: gap)],
          VolButton(label: _submitting ? 'Sending…' : 'Get OTP', variant: ButtonVariant.dark, onPressed: _submitting ? null : _submit),
        ],
      ),
    );
  }
}
