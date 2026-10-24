import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'layout.dart';

/// The small 32px buttons (`darkPill` / `outlinePill`) used in notifications and lists.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outline = false,
    this.width,
    this.minWidth = 0,
    this.height = 32,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outline;
  final double? width;
  final double minWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final radius = BorderRadius.circular(8);
    final fg = outline ? (dark ? Dak.heading : Hex.black) : Colors.white;

    return Opacity(
      opacity: onPressed == null ? .6 : 1,
      child: Material(
        color: outline ? Colors.transparent : (dark ? Dak.cta : Hex.text),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: outline ? BorderSide(color: dark ? Dak.border : Hex.black) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Container(
            width: width,
            height: height,
            constraints: BoxConstraints(minWidth: minWidth),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
