import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/canvas.dart';
import '../../models/user.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/card_box.dart';
import '../../ui/layout.dart';
import '../../ui/user_image.dart';
import 'workspace_card.dart';

/// Port of components/cards/ProductCard.tsx.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.href, required this.brand, required this.name, required this.specs, this.imageSrc});

  final String href;
  final String brand;
  final String name;
  final List<(String, String)> specs;
  final String? imageSrc;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final line = dark ? Dak.border : Dak.line;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? Dak.surface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dark ? Dak.border : Light.border.withValues(alpha: .6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 130,
            child: ColoredBox(
              color: dark ? Dak.surface : Auth.navy,
              child: imageSrc != null
                  ? UserImage(src: imageSrc)
                  : const Center(child: AssetIcon('illustrations/auth-placeholder.svg', width: 36, height: 36)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(brand.toUpperCase(), style: TextStyle(fontSize: 12, height: 1, letterSpacing: .6, color: dark ? Dak.muted : Hex.text)),
                const SizedBox(height: 4),
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600, color: context.ink),
                ),
                const SizedBox(height: 12),
                for (final (i, (label, value)) in specs.indexed) ...[
                  if (i > 0) const SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.only(bottom: i != specs.length - 1 ? 4.5 : 0),
                    decoration: i != specs.length - 1
                        ? BoxDecoration(
                            border: Border(bottom: BorderSide(color: line, width: .5)),
                          )
                        : null,
                    child: Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(fontSize: 14, height: 20 / 14, color: context.body),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            value,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, color: context.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.only(top: 24.5),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: line, width: .5)),
                  ),
                  child: Material(
                    color: Dak.cta,
                    borderRadius: BorderRadius.circular(16),
                    shadowColor: Dak.cta.withValues(alpha: .4),
                    elevation: 4,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.go(href),
                      child: const SizedBox(
                        height: 33,
                        child: Center(
                          child: Text(
                            'View Details',
                            style: TextStyle(fontSize: 14, height: 1, fontWeight: FontWeight.w500, letterSpacing: .28, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Canvas cards in the workspace "grid" style; [footer] renders under each card.
List<Widget> canvasGrid(List<CanvasCard> canvases, {Widget Function(CanvasCard c)? footer}) => [
  for (final c in canvases)
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkspaceCard(
          wide: false,
          href: '/canvas/${c.id}',
          title: c.title,
          meta: c.workspaceName,
          metaSecondary: 'Edited ${timeAgo(c.updatedAt)} · ${plural(c.productCount, 'Product')}',
          collaboratorCount: c.collaboratorCount,
          updatedTag: c.visibility == Access.public ? 'PUBLIC' : null,
          imageSrc: c.thumbnailUrl,
        ),
        if (footer != null) ...[const SizedBox(height: 8), footer(c)],
      ],
    ),
];
