import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'layout.dart';

/// Opens [child] in the centred card from components/ui/Modal.tsx.
Future<T?> showModal<T>(BuildContext context, {required Widget Function(BuildContext) builder, double maxWidth = 768}) {
  return showDialog<T>(
    context: context,
    barrierColor: const Color(0xB03A3A3A),
    builder: (context) {
      final dark = context.isDark;
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: dark ? Dak.surface : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dark ? Dak.border : Light.border),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: context.screenHeight * .9),
          child: SingleChildScrollView(child: builder(context)),
        ),
      );
    },
  );
}

/// Small 44px-high bordered field used inside modals.
class ModalField extends StatelessWidget {
  const ModalField({
    super.key,
    required this.controller,
    this.hint,
    this.lines = 1,
    this.autofocus = false,
    this.onChanged,
    this.maxLength,
  });

  final TextEditingController controller;
  final String? hint;
  final int lines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      height: lines == 1 ? 44 : null,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: lines == 1 ? 0 : 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: dark ? Dak.bg : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dark ? Dak.border : Light.border),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: lines,
        maxLines: lines,
        maxLength: maxLength,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: dark ? Dak.heading : Auth.navy),
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14, color: dark ? Dak.muted : const Color(0xFF757575)),
        ).copyWith(counterText: ''),
      ),
    );
  }
}

/// Bordered (Cancel) and filled (confirm) buttons at the bottom of a modal.
class ModalButton extends StatelessWidget {
  const ModalButton({super.key, required this.label, required this.onTap, this.color, this.outline = false});

  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Opacity(
      opacity: onTap == null ? .6 : 1,
      child: Material(
        color: outline ? Colors.transparent : (color ?? Dak.cta),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: outline ? BorderSide(color: dark ? Dak.border : Light.border) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: outline ? FontWeight.w400 : FontWeight.w500,
                color: outline ? (dark ? Dak.heading : Hex.black) : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
