import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/user.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/card_box.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/progress_bar.dart';
import '../../ui/user_image.dart';
import 'social.dart';

/// Port of components/cards/ClassCard.tsx. With [progress] it becomes the "Active Classroom" variant.
class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.href,
    required this.title,
    required this.subtitle,
    required this.modules,
    this.tag,
    this.badge,
    this.progress,
    this.imageSrc,
  });

  final String href;
  final String title;
  final String subtitle;
  final String modules;
  final String? tag;
  final String? badge;
  final int? progress;
  final String? imageSrc;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final inProgress = progress != null;
    final navy = dark ? Dak.heading : Auth.navy;

    return LinkBox(
      href: href,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: inProgress
            ? BoxDecoration(
                color: dark ? Dak.surface : const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dark ? Dak.border : Light.border),
              )
            : BoxDecoration(
                color: dark ? Dak.surface : Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Hex.text.withValues(alpha: .2), offset: const Offset(0, 4), blurRadius: 8)],
              ),
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
                      const Center(child: AssetIcon('illustrations/auth-placeholder.svg', width: 36, height: 36)),
                    if (tag != null)
                      Positioned(
                        right: 16,
                        top: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: dark ? Dak.bg : Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            tag!,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: navy),
                          ),
                        ),
                      ),
                    if (badge != null)
                      Positioned(
                        right: 16,
                        top: 16,
                        child: Container(
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(color: const Color(0xFF45464D), borderRadius: BorderRadius.circular(8)),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              badge!,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white),
                            ),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, height: 1, fontWeight: FontWeight.w500, letterSpacing: .28, color: context.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, height: 16 / 14, letterSpacing: .28, color: context.mutedText),
                  ),
                  const SizedBox(height: 8),
                  if (inProgress) ...[
                    Row(
                      children: [
                        Text('Progress', style: TextStyle(fontSize: 12, height: 1, color: context.body)),
                        const Spacer(),
                        Text(
                          '$progress%',
                          style: TextStyle(fontSize: 12, height: 1, fontWeight: FontWeight.w600, color: context.ink),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ProgressBar(
                      value: progress! / 100,
                      track: dark ? Dak.border : const Color(0xFFCCCED2),
                      fill: dark ? Dak.cta : Hex.black,
                    ),
                  ] else
                    Text(
                      modules,
                      style: TextStyle(fontSize: 14, height: 20 / 14, color: context.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Port of components/cards/BusinessProfileCard.tsx (used for people too).
class BusinessProfileCard extends StatelessWidget {
  const BusinessProfileCard({super.key, required this.person});

  final PersonCard person;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final p = person;
    final line = dark ? Dak.border : Dak.line;

    Widget stat(int value, String label) => Column(
      children: [
        Text(
          compactNumber(value),
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: context.ink),
        ),
        Text(label, style: TextStyle(fontSize: 14, color: context.mutedText)),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(context, blur: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(src: p.avatarUrl, name: p.name),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: context.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (p.industry ?? p.specialty ?? titleCase(p.isBusiness ? 'BUSINESS' : 'INDIVIDUAL')).toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: .6,
                        color: dark ? Dak.muted : const Color(0xFF929292),
                      ),
                    ),
                  ],
                ),
              ),
              if (p.verified)
                Tooltip(
                  message: 'Verified business',
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Dak.cta, borderRadius: BorderRadius.circular(12)),
                    child: const AssetIcon('icons/verified-badge.svg', width: 22, height: 21),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Text(
              p.bio ?? 'No bio yet.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: context.body),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 17),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: line)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: stat(p.workspaceCount, 'Projects')),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: line),
                          right: BorderSide(color: line),
                        ),
                      ),
                      child: stat(p.classroomCount, 'Classrooms'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: stat(p.followerCount, 'Followers')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: LinkBox(
                  href: profileHref(p),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Dak.cta,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Dak.cta.withValues(alpha: .4), offset: const Offset(0, 8), blurRadius: 6)],
                    ),
                    child: const Text(
                      'View Profile',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FollowButton(
                userId: p.id,
                initial: p.isFollowing,
                look: (context, following) => Container(
                  width: 127,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: following ? null : Hex.text,
                    borderRadius: BorderRadius.circular(8),
                    border: following ? Border.all(color: dark ? Dak.border : Hex.text) : null,
                  ),
                  child: Text(
                    following ? 'Following' : 'Follow',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: following ? (dark ? Dak.heading : Hex.text) : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
