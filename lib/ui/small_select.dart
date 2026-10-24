import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'layout.dart';

/// Compact bordered select used for roles and folder pickers.
class SmallSelect<T> extends StatelessWidget {
  const SmallSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.height = 40,
    this.fill,
    this.width,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final double height;
  final Color? fill;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      height: height,
      width: width,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: fill ?? (dark ? Dak.surface : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dark ? Dak.border : Light.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: width != null,
          dropdownColor: dark ? Dak.surface : Colors.white,
          style: TextStyle(fontSize: 14, color: dark ? Dak.heading : Auth.navy),
          items: [for (final (v, label) in options) DropdownMenuItem(value: v, child: Text(label))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
