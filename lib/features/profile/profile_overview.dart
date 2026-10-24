import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/canvas.dart';
import '../../models/classroom.dart';
import '../../models/user.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/states.dart';
import '../../ui/user_image.dart';
import '../shared/report_button.dart';
import '../shared/social.dart';

/// A profile page: your own when [userId] is null, anyone else's otherwise.
class ProfileOverview extends ConsumerWidget {
  const ProfileOverview({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final id = userId ?? user?.id;
    if (id == null) return const SizedBox.shrink();
    final result = ref.watch(query('/users/$id'));
    if (result.hasError) return ErrorState(error: result.error!);
    final json = result.value as Map<String, dynamic>?;
    if (json == null) return const SizedBox.shrink();
    final p = PublicProfile.fromJson(json);

    final own = p.isSelf;
    final canvases = pagedOf(
      ref,
      own ? '/canvases/recent?limit=1' : withQuery('/canvases/public', {'authorId': p.id, 'limit': 1}),
      CanvasCard.fromJson,
    );
    final classrooms = pagedOf(
      ref,
      own ? '/classrooms?scope=enrolled&limit=2' : withQuery('/classrooms', {'scope': 'explore', 'instructorId': p.id, 'limit': 2}),
      ClassroomCard.fromJson,
    );

    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    final border = dark ? Dak.border : Light.border;
    final isBusiness = p.isBusiness;
    final bio = p.business?.description ?? p.bio;
    final cover = p.business?.coverUrl ?? p.coverUrl;
    final location = [p.city, p.country].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final interests = [...p.interests, ...p.tags, ...?p.business?.categoryTags];
    final canvas = canvases?.items.firstOrNull;

    BoxDecoration panel() => BoxDecoration(
      color: dark ? Dak.surface : Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: border),
    );
    final panelTitle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: .4, color: navy);

    final header = Container(
      clipBehavior: Clip.antiAlias,
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 190,
            child: UserImage(src: cover, fallback: 'illustrations/profile-cover.png'),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Flex(
              direction: context.isSm ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: context.isSm ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Flex(
                    direction: context.isSm ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: context.isSm ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 120,
                        height: context.isSm ? 64 : 120,
                        // The avatar overlaps the cover by 56px from sm up (-mt-14 in the web markup).
                        child: OverflowBox(
                          alignment: Alignment.bottomCenter,
                          maxHeight: 120,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: dark ? Dak.surface : Colors.white, width: 4),
                            ),
                            child: Avatar(src: p.avatarUrl, name: p.name, size: 112),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16, height: 16),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    p.name,
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: navy),
                                  ),
                                ),
                                if (p.verified) ...[
                                  const SizedBox(width: 8),
                                  AssetIcon('icons/verified-check-small.svg', width: 18, height: 18, color: dark ? Colors.white : null),
                                ],
                              ],
                            ),
                            Text(
                              own ? (user?.email ?? '') : (p.username != null ? '@${p.username}' : (p.specialty ?? '')),
                              style: TextStyle(fontSize: 16, color: grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${p.stats['followers'] ?? 0} followers · ${p.stats['following'] ?? 0} following',
                              style: TextStyle(fontSize: 14, color: grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (context.isSm) const Spacer() else const SizedBox(height: 16),
                if (own)
                  OutlinedButton(
                    onPressed: () => context.go(isBusiness ? '/profile/edit-business' : '/profile/edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navy,
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: const Text('✎ Edit Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FollowButton(userId: p.id, initial: p.isFollowing, width: null, height: 44, fontSize: 16, padding: 24),
                      const SizedBox(width: 12),
                      ReportButton(targetType: 'USER', targetId: p.id),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (p.isPrivate) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Title(own: own, isBusiness: isBusiness, name: p.name),
          const SizedBox(height: 24),
          header,
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: panel(),
            child: Text(
              'This profile is private.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.slate),
            ),
          ),
        ],
      );
    }

    final facts = [
      ('Location', location.isEmpty ? '—' : location),
      ('Member Since', '${p.joinedAt.toLocal().year}'),
      if (p.portfolioUrl != null) ('Portfolio', p.portfolioUrl!),
      if (p.business?.website != null) ('Website', p.business!.website!),
    ];

    final bioPanel = Container(
      padding: const EdgeInsets.all(24),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ⓘ ${isBusiness ? 'PROFESSIONAL BIO' : 'BIO'}', style: panelTitle),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Text(
              (bio?.isNotEmpty ?? false) ? bio! : (own ? 'Add a bio from Edit Profile so people know what you work on.' : 'No bio yet.'),
              style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.navy),
            ),
          ),
          const SizedBox(height: 16),
          for (final (label, value) in facts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(label, style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.navy)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: value.startsWith('http')
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: () => launchUrl(Uri.parse(value), webOnlyWindowName: '_blank'),
                              child: Text(
                                value.replaceFirst(RegExp(r'^https?://'), ''),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Dak.cta),
                              ),
                            ),
                          )
                        : Text(
                            value,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navy),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final canvasPanel = Container(
      padding: const EdgeInsets.all(24),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('ⓘ ${own ? 'ACTIVE CANVASES' : 'PUBLIC CANVASES'}', style: panelTitle)),
              if (own)
                const TextLink(
                  'View All',
                  href: '/workspaces',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Dak.cta),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (canvas != null)
            LinkBox(
              href: '/canvas/${canvas.id}',
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 130,
                      child: ColoredBox(
                        color: dark ? Dak.surface : Auth.navy,
                        child: UserImage(src: canvas.thumbnailUrl, fallback: 'illustrations/canvas-thumb-mortar-pattern.jpg'),
                      ),
                    ),
                    Container(
                      color: dark ? Dak.surface : Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            canvas.title,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navy),
                          ),
                          Text(
                            '${canvas.workspaceName} · edited ${timeAgo(canvas.updatedAt)}',
                            style: TextStyle(fontSize: 14, color: grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Text(canvases != null ? 'No canvases yet.' : '', style: TextStyle(fontSize: 14, color: grey)),
        ],
      ),
    );

    final interestPanel = Container(
      padding: const EdgeInsets.all(24),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('⊙ TRADE INTEREST', style: panelTitle),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (interests.isEmpty) Text('None listed.', style: TextStyle(fontSize: 14, color: grey)),
              for (final tag in interests)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: dark ? Dak.bg : const Color(0xFFF2F2F3), borderRadius: BorderRadius.circular(8)),
                  child: Text(tag, style: TextStyle(fontSize: 14, color: navy)),
                ),
            ],
          ),
        ],
      ),
    );

    final classroomPanel = Container(
      padding: const EdgeInsets.all(24),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('🎓 ${own ? 'ACTIVE CLASSROOMS' : 'CLASSROOMS'}', style: panelTitle),
          const SizedBox(height: 16),
          if (classrooms?.items.isEmpty == true) Text('No classrooms yet.', style: TextStyle(fontSize: 14, color: grey)),
          for (final c in classrooms?.items ?? const <ClassroomCard>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LinkBox(
                href: '/classrooms/${c.id}',
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox.square(
                          dimension: 40,
                          child: UserImage(src: c.imageUrl, fallback: 'illustrations/classroom-thumb-engineers.jpg'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                            ),
                            const SizedBox(height: 4),
                            Text(c.instructor.name, style: TextStyle(fontSize: 12, color: grey)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final tag in [
                                  '${c.enrolledCount} Enrolled',
                                  c.progress != null ? '${c.progress}% done' : 'Public Preview',
                                ])
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: dark ? Dak.bg : Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                      border: Border.all(color: border),
                                    ),
                                    child: Text(tag, style: TextStyle(fontSize: 10, color: navy)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    Widget pair(Widget a, Widget b) => context.isLg
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: a),
                const SizedBox(width: 24),
                Expanded(child: b),
              ],
            ),
          )
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 24), b]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(own: own, isBusiness: isBusiness, name: p.name),
        const SizedBox(height: 24),
        header,
        const SizedBox(height: 24),
        pair(bioPanel, canvasPanel),
        const SizedBox(height: 24),
        pair(interestPanel, classroomPanel),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.own, required this.isBusiness, required this.name});

  final bool own;
  final bool isBusiness;
  final String name;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          own ? (isBusiness ? 'My Business Profile' : 'My Personal Profile') : name,
          style: TextStyle(
            fontSize: context.isSm ? 32 : 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -.32,
            color: dark ? Dak.heading : Auth.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          own ? 'Manage your profile' : (isBusiness ? 'Business profile' : 'Member profile'),
          style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.slate),
        ),
      ],
    );
  }
}
