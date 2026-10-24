import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'layout.dart';

/// Port of components/ui/TextField.tsx: a 56px input with a leading icon.
class VolTextField extends StatelessWidget {
  const VolTextField({
    super.key,
    required this.icon,
    this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  final Widget icon;
  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: dark ? Dak.border : Hex.text.withValues(alpha: .5)),
    );

    return SizedBox(
      height: 56,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: TextStyle(fontSize: 16, color: dark ? Dak.heading : Hex.text),
        cursorColor: dark ? Dak.heading : Hex.text,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 16, color: dark ? Dak.muted : Hex.text.withValues(alpha: .6)),
          filled: true,
          fillColor: dark ? Colors.transparent : Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 24, right: 8), child: icon),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: context.pick(Hex.black, Dak.heading)),
    );
  }
}

class ErrorText extends StatelessWidget {
  const ErrorText(this.text, {super.key, this.center = false});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.pick(Hex.error, Hex.errorDark)),
      ),
    );
  }
}
