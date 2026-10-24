import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A 6px rounded progress track. [value] is 0..1.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.height = 6, this.track = const Color(0xFFE0E0E0), this.fill = Dak.cta});

  final double value;
  final double height;
  final Color track;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
