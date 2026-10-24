import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/auth/me.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/button.dart';
import '../../ui/layout.dart';
import '../../ui/otp_input.dart';
import '../../ui/text_field.dart';
import 'auth_flow.dart';
import 'widgets/auth_shell.dart';

enum OtpMode { verify, login, reset }

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key, required this.email, required this.mode, this.next, this.persona});

  final String email;
  final OtpMode mode;
  final String? next;
  final String? persona;

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  String _code = '';
  String? _error;
  bool _resent = false;
  bool _submitting = false;
  // Temporary, until emails are delivered: the code the API sent back, shown on screen.
  String? _devCode;

  @override
  void initState() {
    super.initState();
    if (widget.mode == OtpMode.verify) _devCode = ref.read(authFlowProvider).devCodes[widget.email];
  }

  Future<void> _submit() async {
    if (_code.length < 6) return setState(() => _error = 'Enter the full 6-digit code.');

    setState(() {
      _error = null;
      _submitting = true;
    });
    final api = ref.read(apiProvider);
    final flow = ref.read(authFlowProvider);
    final body = {'email': widget.email, 'code': _code};

    try {
      if (widget.mode == OtpMode.reset) {
        final res = await api.post<Map<String, dynamic>>('/auth/forgot-password/verify', body);
        flow.resetToken = res['resetToken'] as String;
        if (mounted) context.go('/reset-password');
        return;
      }
      final session = await api.post<Map<String, dynamic>>(
        widget.mode == OtpMode.login ? '/auth/login/verify' : '/auth/verify-email',
        body,
      );
      flow.devCodes.remove(widget.email);
      final user = api.setSession(session);
      if (mounted) context.go(widget.next ?? homeFor(user));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _submitting = false;
      });
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    // A login code can only be re-sent by logging in again, which needs the password.
    if (widget.mode == OtpMode.login) return context.go('/login');
    try {
      final res = await ref.read(apiProvider).post<Map<String, dynamic>>(
        widget.mode == OtpMode.reset ? '/auth/forgot-password' : '/auth/resend-verification',
        {'email': widget.email},
      );
      final devCode = res['devCode'] as String?;
      if (devCode != null) ref.read(authFlowProvider).devCodes[widget.email] = devCode;
      setState(() {
        if (devCode != null) _devCode = devCode;
        _resent = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final persona = widget.persona;
    final signupHref = persona == 'individual' || persona == 'business' ? '/signup?persona=$persona' : '/signup';
    final backHref = switch (widget.mode) {
      OtpMode.reset => '/forgot-password',
      OtpMode.login => '/login',
      OtpMode.verify => signupHref,
    };
    final submitLabel = switch (widget.mode) {
      OtpMode.verify => 'Verify Email',
      OtpMode.login => 'Verify & Log In',
      OtpMode.reset => 'Continue',
    };
    final gap = context.dvh(12, 2.5, 32);
    final body = dark ? Dak.body : Hex.text;

    return AuthShell(
      backHref: backHref,
      child: Column(
        children: [
          AuthHeading(
            title: 'OTP Verification',
            subtitle: 'Enter your email below to login your account',
            logoSize: context.dvh(40, 8, 100),
          ),
          SizedBox(height: context.dvh(12, 2.5, 40)),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: context.isSm ? 41 : 24, vertical: context.dvh(16, 3.5, 41)),
                decoration: BoxDecoration(
                  color: dark ? Dak.surface.withValues(alpha: .6) : Colors.white.withValues(alpha: .7),
                  border: Border.all(color: Dak.cta),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      width: context.dvh(40, 6, 64),
                      height: context.dvh(40, 6, 64),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Dak.cta, borderRadius: BorderRadius.circular(12)),
                      child: const AssetIcon('icons/envelope.svg', width: 26, height: 23),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Check your inbox',
                      style: GoogleFonts.geist(
                        fontSize: context.isSm ? context.dvh(18, 3, 28) : 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.32,
                        color: dark ? Dak.heading : Hex.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.isSm ? 48 : 8),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 16, height: 1.5, color: body),
                          children: [
                            const TextSpan(text: 'We’ve sent a 6-digit verification code to '),
                            TextSpan(
                              text: widget.email,
                              style: TextStyle(fontWeight: FontWeight.w500, color: dark ? Dak.heading : Hex.text),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_devCode != null) ...[SizedBox(height: gap), _DevCode(code: _devCode!)],
                    SizedBox(height: gap),
                    OtpInput(onChanged: (code) => _code = code),
                    if (_error != null) ...[const SizedBox(height: 12), ErrorText(_error!, center: true)],
                    const SizedBox(height: 20),
                    VolButton(
                      label: _submitting ? 'Verifying…' : submitLabel,
                      variant: ButtonVariant.dark,
                      onPressed: _submitting ? null : _submit,
                    ),
                    SizedBox(height: gap),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(top: context.dvh(12, 2, 25)),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: dark ? Dak.border : Dak.line)),
                      ),
                      child: Column(
                        children: [
                          Text('Didn’t receive the email?', style: TextStyle(fontSize: 14, color: body)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _resend,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AssetIcon('icons/refresh-small.svg', width: 9, height: 9, color: dark ? null : Colors.black),
                                const SizedBox(width: 4),
                                Text(
                                  _resent ? 'Email sent again' : 'Resend Email',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: .28,
                                    color: dark ? Dak.cta : Hex.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevCode extends StatelessWidget {
  const _DevCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Dak.cta),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 14, color: dark ? Dak.body : Hex.text),
          children: [
            const TextSpan(text: 'Email delivery isn’t set up yet. Your code is '),
            TextSpan(
              text: code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 3.2,
                color: dark ? Dak.heading : Hex.black,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
