import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../ui/asset_icon.dart';
import '../../ui/button.dart';
import '../../ui/layout.dart';
import '../../ui/text_field.dart';
import 'auth_flow.dart';
import 'widgets/auth_shell.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text;
    if (password.isEmpty || _confirm.text.isEmpty) return setState(() => _error = 'Fill in both fields to continue.');
    if (password != _confirm.text) return setState(() => _error = "Passwords don't match.");

    final flow = ref.read(authFlowProvider);
    final resetToken = flow.resetToken;
    if (resetToken == null) {
      return setState(() => _error = 'Your reset session expired. Request a new code from Forgot Password.');
    }

    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref.read(apiProvider).post<dynamic>('/auth/reset-password', {'resetToken': resetToken, 'password': password});
      flow.resetToken = null;
      if (mounted) context.go('/login?reset=1');
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
    final gap = context.dvh(12, 2, 24);
    final lock = AssetIcon('icons/lock-keyhole.svg', width: 22, height: 22, color: context.pick(Colors.black, null));

    return AuthShell(
      child: AutofillGroup(
        child: Column(
          children: [
            AuthHeading(
              title: 'Reset Password',
              subtitle: 'Set your new password and confirm your new password',
              logoSize: context.dvh(48, 9, 100),
            ),
            SizedBox(height: gap),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Password'),
                const SizedBox(height: 8),
                VolTextField(
                  controller: _password,
                  icon: lock,
                  hint: 'Enter your password',
                  obscure: true,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: gap),
                const FieldLabel('Confirm Password'),
                const SizedBox(height: 8),
                VolTextField(
                  controller: _confirm,
                  icon: lock,
                  hint: 'Enter your password',
                  obscure: true,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submitting ? null : _submit(),
                ),
              ],
            ),
            SizedBox(height: gap),
            if (_error != null) ...[ErrorText(_error!), SizedBox(height: gap)],
            VolButton(
              label: _submitting ? 'Resetting…' : 'Reset Password',
              variant: ButtonVariant.dark,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
