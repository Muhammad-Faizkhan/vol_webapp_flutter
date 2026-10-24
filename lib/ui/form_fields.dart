import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'asset_icon.dart';
import 'layout.dart';

/// The bordered inputs used across the profile and creation forms
/// (`rounded-xl border-[rgba(43,43,49,0.6)] bg-white/50 px-6`).
class FormInput extends StatelessWidget {
  const FormInput({
    super.key,
    required this.controller,
    this.hint,
    this.height = 56,
    this.maxLines = 1,
    this.horizontalPadding = 24,
    this.keyboardType,
    this.fill = true,
    this.radius = 12,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.borderColor,
    this.fontSize = 16,
  });

  final TextEditingController controller;
  final String? hint;
  final double? height;
  final int? maxLines;
  final double horizontalPadding;
  final TextInputType? keyboardType;
  final bool fill;
  final double radius;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final Color? borderColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final multiline = maxLines != 1;

    // Like the web markup: a bordered box with a borderless input inside, so the box keeps its
    // height whatever the font metrics are.
    final field = TextField(
      controller: controller,
      maxLines: maxLines,
      expands: multiline && height != null,
      keyboardType: multiline ? TextInputType.multiline : keyboardType,
      textAlignVertical: multiline ? TextAlignVertical.top : TextAlignVertical.center,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      style: TextStyle(fontSize: fontSize, color: dark ? Dak.heading : Hex.text),
      cursorColor: dark ? Dak.heading : Hex.text,
      decoration: InputDecoration.collapsed(
        hintText: hint,
        hintStyle: TextStyle(fontSize: fontSize, color: dark ? Dak.muted : Hex.text.withValues(alpha: .6)),
      ),
    );

    return Container(
      height: height,
      // A short textarea keeps its first line visible, as the browser does by scrolling.
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: multiline ? (height == null ? 12 : ((height! - fontSize * 1.5) / 2).clamp(2, 12)) : 0,
      ),
      alignment: multiline ? Alignment.topLeft : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: dark || !fill ? Colors.transparent : Colors.white.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? (dark ? Dak.border : Hex.text.withValues(alpha: .6))),
      ),
      child: field,
    );
  }
}

/// A native-looking select with the web's dropdown-arrow icon. [value] null shows the placeholder.
class FormSelect extends StatelessWidget {
  const FormSelect({
    super.key,
    required this.value,
    required this.options,
    required this.placeholder,
    required this.onChanged,
    this.height = 56,
    this.labels,
  });

  final String? value;
  final List<String> options;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final double height;
  final Map<String, String>? labels;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    // The web leaves the select's text at 60% opacity even once something is picked.
    final textColor = dark ? Dak.heading : Hex.text.withValues(alpha: .6);

    return Container(
      height: height,
      padding: const EdgeInsets.only(left: 24, right: 20),
      decoration: BoxDecoration(
        color: dark ? Colors.transparent : Colors.white.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? Dak.border : Hex.text.withValues(alpha: .6)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(value) ? value : null,
          isExpanded: true,
          hint: Text(placeholder, style: TextStyle(fontSize: 16, color: textColor)),
          icon: AssetIcon('icons/dropdown-arrow.svg', width: 24, height: 24, color: dark ? Colors.white : null),
          dropdownColor: dark ? Dak.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(fontSize: 16, color: textColor),
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: o,
                child: Text(labels?[o] ?? o, style: TextStyle(color: dark ? Dak.heading : Hex.text)),
              ),
          ],
          selectedItemBuilder: (_) => [for (final o in options) Align(alignment: Alignment.centerLeft, child: Text(labels?[o] ?? o))],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}

/// "Label *" with the red asterisk the web uses for required fields.
class RequiredLabel extends StatelessWidget {
  const RequiredLabel(this.text, {super.key, this.required = true});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: dark ? Dak.heading : Hex.black),
        children: [
          TextSpan(text: text),
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: dark ? Dak.body : Hex.error),
            ),
        ],
      ),
    );
  }
}

/// Black (light) / purple (dark) square with the link icon, beside a portfolio URL field.
class LinkBadge extends StatelessWidget {
  const LinkBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: context.pick(Hex.black, Dak.cta), borderRadius: BorderRadius.circular(8)),
      child: const AssetIcon('icons/link.svg', width: 20, height: 10),
    );
  }
}

/// The outlined "Upload Image" button with a camera icon.
class CameraButton extends StatelessWidget {
  const CameraButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final color = dark ? Dak.heading : Hex.text;
    return Opacity(
      opacity: onPressed == null ? .6 : 1,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 17),
          side: BorderSide(color: dark ? Dak.border : Hex.text),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          foregroundColor: color,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssetIcon('icons/camera.svg', width: 18, height: 16, color: dark ? null : Colors.black),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: .28, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// The purple-bordered card with a thick top edge and glow that wraps the onboarding forms.
class GlowCard extends StatelessWidget {
  const GlowCard({super.key, required this.child, required this.padding, this.borderColor = const Color(0xFF712AE2)});

  final Widget child;
  final EdgeInsets padding;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final edge = dark ? Dak.cta : borderColor;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? Dak.surface : Colors.white.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: BorderSide(color: edge, width: 3),
          left: BorderSide(color: edge),
          right: BorderSide(color: edge),
          bottom: BorderSide(color: edge),
        ),
        boxShadow: [BoxShadow(color: Dak.cta.withValues(alpha: .5), blurRadius: 10, blurStyle: BlurStyle.outer)],
      ),
      child: child,
    );
  }
}
