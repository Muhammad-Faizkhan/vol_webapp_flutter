import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// An image from assets/, svg or raster. [color] tints every painted pixel, which is how the web's
/// `invert` on white icons is reproduced.
class AssetIcon extends StatelessWidget {
  const AssetIcon(this.path, {super.key, this.width, this.height, this.color, this.fit = BoxFit.contain});

  final String path;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final asset = 'assets/$path';
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        width: width,
        height: height,
        fit: fit,
        colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      );
    }
    return Image.asset(asset, width: width, height: height, fit: fit, color: color);
  }
}
