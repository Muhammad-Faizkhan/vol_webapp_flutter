import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../ui/layout.dart';

/// The 56px "Create Canvas" / "Create Workspace" buttons at the top of the home pages.
/// Full width on phones, [width] (or as wide as the label) from sm up.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.color,
    required this.label,
    required this.onTap,
    this.width,
    this.icon,
    this.border = false,
  });

  final double? width;
  final Color color;
  final Widget? icon;
  final String label;
  final VoidCallback? onTap;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.isSm ? width : double.infinity,
      height: 56,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: border ? BorderSide(color: context.pick(Light.border, Dak.border)) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 16)],
                Flexible(
                  child: Text(
                    label,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
