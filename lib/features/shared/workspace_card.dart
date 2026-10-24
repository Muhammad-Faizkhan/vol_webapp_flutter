import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/card_box.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/user_image.dart';

/// Port of components/cards/WorkspaceCard.tsx. `wide` shows canvases and last edit; `grid` shows
/// [meta] lines instead.
class WorkspaceCard extends StatelessWidget {
  const WorkspaceCard({
    super.key,
    required this.href,
    required this.title,
    this.wide = true,
    this.workspace,
    this.editedAgo,
    this.updatedTag,
    this.collaborators = const [],
    this.collaboratorCount = 0,
    this.meta,
    this.metaSecondary,
    this.imageSrc,
    this.showFooter = true,
  });

  final String href;
  final String title;
  final bool wide;
  final String? workspace;
  final String? editedAgo;
  final String? updatedTag;
  final List<UserSummary> collaborators;
  final int collaboratorCount;
  final String? meta;
  final String? metaSecondary;
  final String? imageSrc;
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final footer = showFooter && collaboratorCount > 0;

    return LinkBox(
      href: href,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 130,
              child: ColoredBox(
                color: dark ? Dak.surface : Auth.navy,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageSrc != null)
                      UserImage(src: imageSrc)
                    else
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: AssetIcon('illustrations/auth-placeholder.svg', width: wide ? 73 : 36, height: wide ? 73 : 36),
                        ),
                      ),
                    Positioned(
                      right: 24,
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF45464D), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          updatedTag ?? '+$collaboratorCount Collabs',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, height: 1, fontWeight: FontWeight.w500, letterSpacing: .28, color: context.ink),
                  ),
                  const SizedBox(height: 8),
                  if (wide) ...[
                    Text(
                      workspace ?? '',
                      style: TextStyle(fontSize: 14, height: 16 / 14, letterSpacing: .28, color: context.body),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      editedAgo ?? '',
                      style: TextStyle(fontSize: 14, height: 20 / 14, color: context.grey),
                    ),
                  ] else ...[
                    Text(meta ?? '', style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.slate)),
                    const SizedBox(height: 8),
                    Text(metaSecondary ?? '', style: TextStyle(fontSize: 14, color: dark ? Dak.muted : const Color(0xFF929292))),
                  ],
                ],
              ),
            ),
            if (footer) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: dark ? Dak.border : Dak.line)),
                ),
                child: Row(
                  children: [
                    AvatarStack(people: collaborators, count: collaboratorCount),
                    const SizedBox(width: 16),
                    Text('+$collaboratorCount Collabs', style: TextStyle(fontSize: 16, color: dark ? Dak.heading : Hex.text)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Up to three overlapping 24px avatars with a ring in the card colour.
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.people, required this.count, this.size = 24});

  final List<UserSummary> people;
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final shown = people.take(3).toList();
    final slots = shown.isNotEmpty ? shown.length : count.clamp(0, 3);
    final ring = size + 4;

    return SizedBox(
      height: ring,
      width: slots == 0 ? 0 : ring + (slots - 1) * (ring - 10),
      child: Stack(
        children: [
          for (var i = 0; i < slots; i++)
            Positioned(
              left: i * (ring - 10),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, color: dark ? Dak.surface : Colors.white),
                child: i < shown.length
                    ? Avatar(src: shown[i].avatarUrl, name: shown[i].name, size: size)
                    : Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dark ? Dak.cta.withValues(alpha: .2) : Auth.navy.withValues(alpha: .1),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
