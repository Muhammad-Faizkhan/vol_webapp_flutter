import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'layout.dart';

enum ButtonVariant { primary, outline, dark, darkOutline, google, apple, cta }

/// Port of components/ui/Button.tsx. Every variant is 56px tall and full width.
/// `cta` is the purple, 16px-radius button the creation forms build from it with class overrides.
class VolButton extends StatelessWidget {
  const VolButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.trailing,
    this.radius,
    this.fontSize,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final Widget? icon;
  final Widget? trailing;
  final double? radius;
  final double? fontSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final purpleGlow = [BoxShadow(color: Dak.cta.withValues(alpha: .4), offset: const Offset(0, 8), blurRadius: 16)];

    final (Color bg, Color fg, Border? border, double r, List<BoxShadow> shadow, double size) = switch (variant) {
      ButtonVariant.outline => (
        Colors.white,
        Auth.slate,
        Border.all(color: Auth.navy.withValues(alpha: .5)),
        12.0,
        const <BoxShadow>[],
        20.0,
      ),
      ButtonVariant.google => (
        dark ? Colors.transparent : Colors.white,
        dark ? Dak.heading : Hex.google,
        Border.all(color: dark ? Dak.border : Hex.google.withValues(alpha: .5)),
        12.0,
        const <BoxShadow>[],
        16.0,
      ),
      ButtonVariant.apple => (
        dark ? Colors.transparent : Hex.black,
        dark ? Dak.heading : Colors.white,
        Border.all(color: dark ? Dak.border : Hex.black),
        12.0,
        const <BoxShadow>[],
        16.0,
      ),
      ButtonVariant.darkOutline => (Colors.transparent, Dak.heading, Border.all(color: Dak.border), 12.0, const <BoxShadow>[], 16.0),
      ButtonVariant.dark => (Dak.cta, Colors.white, null, 999.0, purpleGlow, 16.0),
      ButtonVariant.cta => (Dak.cta, Colors.white, null, 16.0, purpleGlow, 16.0),
      ButtonVariant.primary => (
        Auth.slate,
        Colors.white,
        null,
        16.0,
        [BoxShadow(color: Auth.slate.withValues(alpha: .4), offset: const Offset(0, 8), blurRadius: 16)],
        16.0,
      ),
    };

    final shape = BorderRadius.circular(radius ?? r);
    final disabled = onPressed == null;
    final dims = variant == ButtonVariant.dark || variant == ButtonVariant.cta;

    return Opacity(
      opacity: disabled && dims ? .6 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg, border: border, borderRadius: shape, boxShadow: shadow),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: shape,
            mouseCursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: fontSize ?? size,
                        fontWeight: FontWeight.w500,
                        letterSpacing: (fontSize ?? size) == 14 ? .28 : null,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
