import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'layout.dart';

/// Six single-digit boxes with a dash after the third, as in components/ui/OtpInput.tsx.
class OtpInput extends StatefulWidget {
  const OtpInput({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  static const _length = 6;

  final _controllers = List.generate(_length, (_) => TextEditingController());
  final _nodes = List.generate(_length, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _length; i++) {
      _nodes[i].onKeyEvent = (_, event) => _onKey(i, event);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(_controllers.map((c) => c.text).join());

  void _onChanged(int i, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    // Pasting the whole code into one box fills them all.
    if (digits.length > 1) {
      for (var j = 0; j < _length; j++) {
        _controllers[j].text = j < digits.length ? digits[j] : '';
      }
      _nodes[(digits.length - 1).clamp(0, _length - 1)].requestFocus();
    } else {
      _controllers[i].text = digits;
      if (digits.isNotEmpty && i < _length - 1) _nodes[i + 1].requestFocus();
    }
    setState(() {});
    _emit();
  }

  KeyEventResult _onKey(int i, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace && _controllers[i].text.isEmpty && i > 0) {
      _nodes[i - 1].requestFocus();
      _emit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final width = context.dvw(32, 8, 56);
    final height = context.dvh(44, 7, 64);
    final gap = context.isSm ? 8.0 : 4.0;

    Widget box(int i) {
      final filled = _controllers[i].text.isNotEmpty;
      final idle = filled ? Dak.cta : (dark ? Dak.border : const Color(0xFF9E9E9E));
      OutlineInputBorder outline(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: c),
      );

      return SizedBox(
        width: width,
        height: height,
        child: TextField(
          controller: _controllers[i],
          focusNode: _nodes[i],
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
          autofillHints: i == 0 ? const [AutofillHints.oneTimeCode] : null,
          onChanged: (v) => _onChanged(i, v),
          style: TextStyle(fontSize: context.isSm ? 20 : 18, color: dark ? Dak.heading : Hex.text),
          cursorColor: dark ? Dak.heading : Hex.text,
          decoration: InputDecoration(
            filled: true,
            fillColor: dark ? Colors.transparent : Colors.white.withValues(alpha: .7),
            contentPadding: EdgeInsets.zero,
            enabledBorder: outline(idle),
            focusedBorder: outline(Dak.cta),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          if (i == 3)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.isSm ? 4 : 2),
              child: Text(
                '-',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: dark ? Dak.border : Hex.text),
              ),
            ),
          if (i == 3) SizedBox(width: gap),
          box(i),
        ],
      ],
    );
  }
}
