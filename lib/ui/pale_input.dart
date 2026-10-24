import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'layout.dart';

/// The pale-filled, rounded-lg inputs of the product and profile forms. 56px tall unless [height] is set.
class PaleInput extends StatelessWidget {
  const PaleInput({
    super.key,
    required this.controller,
    this.hint = '',
    this.onChanged,
    this.focusNode,
    this.lines = 1,
    this.height,
    this.suffix,
    this.number = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final int lines;
  final double? height;
  final String? suffix;
  final bool number;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    return Container(
      height: lines == 1 ? (height ?? 56) : null,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: lines == 1 ? 0 : 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: dark ? Colors.transparent : const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dark ? Dak.border : Light.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: lines,
              maxLines: lines,
              onChanged: onChanged,
              keyboardType: number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null,
              inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}'))] : null,
              style: TextStyle(fontSize: 16, color: dark ? Dak.heading : Auth.navy),
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 16, color: grey),
              ),
            ),
          ),
          if (suffix != null) ...[const SizedBox(width: 8), Text(suffix!, style: TextStyle(fontSize: 14, color: grey))],
        ],
      ),
    );
  }
}
