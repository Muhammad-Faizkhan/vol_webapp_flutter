import 'package:flutter/material.dart';

import 'asset_icon.dart';
import 'layout.dart';

class SwirlBackground extends StatelessWidget {
  const SwirlBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AssetIcon(context.pick('illustrations/light-swirl-bg.png', 'illustrations/dark-swirl-bg.svg'), fit: BoxFit.cover),
      ),
    );
  }
}
