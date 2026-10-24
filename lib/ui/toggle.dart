import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 48x24 switch from components/ui/Toggle.tsx. The track colour is fixed, only the knob moves.
class VolToggle extends StatelessWidget {
  const VolToggle({super.key, required this.value, required this.onChanged, this.trackColor = Auth.navy});

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 48,
            height: 24,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: trackColor, borderRadius: BorderRadius.circular(12)),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 1), blurRadius: 2)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
