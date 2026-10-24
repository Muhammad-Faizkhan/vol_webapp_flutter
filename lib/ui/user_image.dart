import 'package:flutter/material.dart';

import '../core/format.dart';
import '../theme/tokens.dart';
import 'asset_icon.dart';

/// An uploaded image filling its box, or a bundled fallback when there is none.
class UserImage extends StatelessWidget {
  const UserImage({super.key, required this.src, this.fallback, this.opacity = 1});

  final String? src;
  final String? fallback;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final Widget? image = src != null && src!.isNotEmpty
        ? Image.network(
            src!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        : fallback != null
        ? AssetIcon(fallback!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
        : null;
    if (image == null) return const SizedBox.shrink();
    return opacity == 1 ? image : Opacity(opacity: opacity, child: image);
  }
}

/// Round avatar: the user's photo, or their initials on a purple disc.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.src, required this.name, this.size = 40});

  final String? src;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letters = initials(name);
    return Tooltip(
      message: name,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Dak.cta, shape: BoxShape.circle),
        child: src != null && src!.isNotEmpty
            ? UserImage(src: src)
            : Text(
                letters.isEmpty ? '?' : letters,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: (size * .38).clamp(10, double.infinity)),
              ),
      ),
    );
  }
}
