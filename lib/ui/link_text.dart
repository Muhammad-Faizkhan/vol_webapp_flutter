import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'layout.dart';

/// "Plain text + bold purple link" lines used under the auth forms.
class LinkText extends StatefulWidget {
  const LinkText({
    super.key,
    required this.text,
    required this.link,
    required this.onTap,
    this.fontSize = 14,
    this.underline = true,
    this.textColor,
  });

  final String text;
  final String link;
  final VoidCallback onTap;
  final double fontSize;
  // The web underlines these links in light mode only.
  final bool underline;
  final Color? textColor;

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  late final _recognizer = TapGestureRecognizer()..onTap = () => widget.onTap();

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w500,
          color: widget.textColor ?? (dark ? Dak.heading : Hex.text),
        ),
        children: [
          TextSpan(text: '${widget.text} '),
          TextSpan(
            text: widget.link,
            recognizer: _recognizer,
            mouseCursor: SystemMouseCursors.click,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Dak.cta,
              decoration: widget.underline && !dark ? TextDecoration.underline : null,
              decorationColor: Dak.cta,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
