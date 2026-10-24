import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'layout.dart';

/// The white card with a 40% ink border and soft shadow that most lists use
/// (`border-[rgba(43,43,49,0.4)] bg-white shadow-[0px_4px_8px_0px_rgba(43,43,49,0.2)]`).
BoxDecoration cardDecoration(BuildContext context, {double radius = 8, double blur = 8, double y = 4}) {
  final dark = context.isDark;
  return BoxDecoration(
    color: dark ? Dak.surface : Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: dark ? Dak.border : Hex.text.withValues(alpha: .4)),
    boxShadow: [BoxShadow(color: Hex.text.withValues(alpha: .2), offset: Offset(0, y), blurRadius: blur)],
  );
}

/// Common text styles, named after the Tailwind classes they replace.
extension WebText on BuildContext {
  Color get ink => pick(Hex.black, Dak.heading);
  Color get body => pick(Hex.text, Dak.body);
  Color get mutedText => pick(Hex.text, Dak.muted);
  Color get grey => pick(const Color(0xFF45464D), Dak.muted);

  TextStyle get sectionHeading =>
      TextStyle(fontSize: isSm ? 24 : 20, height: 32 / (isSm ? 24 : 20), fontWeight: FontWeight.w600, color: ink);

  TextStyle get sectionLink => TextStyle(fontSize: isSm ? 16 : 14, fontWeight: FontWeight.w500, color: Dak.cta);

  TextStyle get emptyText => TextStyle(fontSize: 14, color: pick(const Color(0xFF45464D), Dak.muted));

  TextStyle get pageTitle =>
      TextStyle(fontSize: isSm ? 32 : 24, height: isSm ? 40 / 32 : null, fontWeight: FontWeight.w700, letterSpacing: -.32, color: ink);
}

/// "Title ........ Link" row above each section.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing, this.alignEnd = false});

  final Widget title;
  final Widget? trailing;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.center,
      children: [
        Expanded(child: title),
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}

/// Small purple tag (`bg-[rgba(148,54,251,0.1)] text-dak-cta text-[10px]`).
class PurpleTag extends StatelessWidget {
  const PurpleTag(this.label, {super.key, this.bordered = false, this.radius = 2});

  final String label;
  final bool bordered;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: EdgeInsets.symmetric(horizontal: bordered ? 9 : 8),
      decoration: BoxDecoration(
        color: Dak.cta.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(radius),
        border: bordered ? Border.all(color: Dak.cta) : null,
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, height: 1.5, fontWeight: FontWeight.w500, color: Dak.cta),
        ),
      ),
    );
  }
}
