import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../ui/auto_grid.dart';
import '../../ui/layout.dart';

/// The four-up stat strip on the business home and dashboard.
class BusinessStats extends StatelessWidget {
  const BusinessStats({super.key, required this.stats});

  final Map<String, dynamic>? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final cards = [
      ('ACTIVE WORKSPACES', s?['workspaces']?['total'], '+${s?['workspaces']?['newThisWeek'] ?? 0} this week'),
      ('TOTAL PRODUCTS', s?['products']?['total'], '${s?['products']?['public'] ?? 0} shared publicly'),
      ('CANVASES', s?['canvases']?['total'], '${s?['canvases']?['public'] ?? 0} shared publicly'),
      ('FOLLOWERS', s?['followers']?['total'], '+${s?['followers']?['newThisMonth'] ?? 0} this month'),
    ];
    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;

    return AutoGrid(
      minItemWidth: 180,
      children: [
        for (final (label, value, note) in cards)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 17),
            decoration: BoxDecoration(
              color: dark ? Dak.surface : const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dark ? Dak.cta : Light.border),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: .28, color: navy),
                ),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${value ?? '–'} ',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: navy),
                      ),
                      TextSpan(
                        text: s != null ? note : '',
                        style: TextStyle(fontSize: 14, color: dark ? Dak.muted : const Color(0xFF889298)),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

TextStyle businessHeading(BuildContext context) =>
    TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: context.pick(Auth.navy, Dak.heading));

TextStyle businessTitle(BuildContext context) => TextStyle(
  fontSize: context.isSm ? 32 : 24,
  fontWeight: FontWeight.w700,
  letterSpacing: -.32,
  color: context.pick(Auth.navy, Dak.heading),
);

TextStyle businessSubtitle(BuildContext context) => TextStyle(fontSize: 16, color: context.pick(Auth.slate, Dak.body));
