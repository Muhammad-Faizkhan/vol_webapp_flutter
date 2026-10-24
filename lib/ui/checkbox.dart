import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'layout.dart';

class VolCheckbox extends StatelessWidget {
  const VolCheckbox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: value ? Dak.cta : (dark ? Colors.transparent : Colors.white),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: value ? Dak.cta : (dark ? Dak.border : Light.border)),
          ),
          child: value ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
        ),
      ),
    );
  }
}
