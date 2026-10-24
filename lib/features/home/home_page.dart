import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/canvas.dart';
import '../../models/classroom.dart';
import '../../models/notification.dart';
import '../../models/post.dart';
import '../../models/product.dart';
import '../../models/user.dart';
import '../../models/workspace.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/auto_grid.dart';
import '../../ui/card_box.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/link_text.dart';
import '../../ui/progress_bar.dart';
import '../../ui/user_image.dart';
import '../shared/action_button.dart';
import '../shared/social.dart';
import '../shared/workspace_card.dart';
import '../shell/notification_item.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Feed _feed = Feed.following;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final stats = ref.watch(query('/users/me/stats')).value as Map<String, dynamic>?;
    final workspaces = pagedOf(ref, '/workspaces?limit=2', Workspace.fromJson);
    final classrooms = pagedOf(ref, '/classrooms?scope=explore&limit=2', ClassroomCard.fromJson);
    final canvases = pagedOf(ref, '/canvases/recent?limit=4', CanvasCard.fromJson);
    final posts = pagedOf(ref, '/posts?feed=${_feed.name}&limit=2', Post.fromJson);
    final products = pagedOf(ref, '/products?sort=newest&limit=3', Product.fromJson);
    final notes = pagedOf(ref, '/notifications?limit=15', AppNotification.fromJson);
    final suggestions = (ref.watch(query('/users/suggestions?limit=4')).value as List?)?.cast<Map<String, dynamic>>();
    final active = pagedOf(ref, '/classrooms?scope=active&limit=2', ClassroomCard.fromJson);

    // Actionable notifications first, then the newest.
    bool actionable(AppNotification n) => !n.resolved && n.type.startsWith('WORKSPACE_');
    final sideNotes = [...?notes?.items];
    mergeSort(sideNotes, compare: (a, b) => (actionable(a) ? 1 : 0) - (actionable(b) ? 1 : 0));
    final topNotes = sideNotes.reversed.take(2).toList();

    final firstName = (user?.name ?? '').split(' ').first;
    final wide = context.isLg;

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          context,
          title: 'Recent Workspace',
          link: ('View All Workspaces', '/workspaces'),
          children: [
            if (workspaces?.items.isEmpty == true)
              _EmptyWithLink(text: 'No workspaces yet. ', link: 'Create your first one', href: '/workspaces/create'),
            AutoGrid(
              minItemWidth: 280,
              children: [
                for (final ws in workspaces?.items ?? const <Workspace>[])
                  WorkspaceCard(
                    href: '/workspaces/${ws.id}',
                    title: ws.name,
                    workspace: plural(ws.canvasCount, 'canvas', 'canvases'),
                    editedAgo: 'Edited ${timeAgo(ws.lastActivityAt)}',
                    updatedTag: updatedTag(ws.lastActivityAt),
                    collaborators: ws.members,
                    collaboratorCount: ws.memberCount,
                    imageSrc: ws.imageUrl,
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        _section(
          context,
          title: 'Featured Classrooms',
          link: ('Browse Classrooms', '/classrooms'),
          children: [
            if (classrooms?.items.isEmpty == true) Text('No public classrooms yet.', style: context.emptyText),
            AutoGrid(
              minItemWidth: 280,
              gap: 15,
              children: [for (final c in classrooms?.items ?? const <ClassroomCard>[]) _FeaturedClassroom(c)],
            ),
          ],
        ),
        const SizedBox(height: 32),
        _section(
          context,
          title: 'Recent Canvases',
          link: canvases?.items.isNotEmpty == true ? ('Open Last Canvas', '/canvas/${canvases!.items.first.id}') : null,
          children: [_CanvasTable(rows: canvases?.items)],
        ),
        const SizedBox(height: 32),
        _section(
          context,
          titleWidget: Wrap(
            spacing: context.isSm ? 24 : 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('From the community', style: context.sectionHeading),
              FeedToggle(value: _feed, onChanged: (f) => setState(() => _feed = f)),
            ],
          ),
          link: ('Explore', '/explore'),
          children: [
            if (posts?.items.isEmpty == true)
              Text(
                _feed == Feed.following ? 'Follow people and businesses to see their posts here.' : 'No trending posts yet.',
                style: context.emptyText,
              ),
            AutoGrid(minItemWidth: 260, children: [for (final p in posts?.items ?? const <Post>[]) CommunityPostCard(post: p)]),
          ],
        ),
        const SizedBox(height: 32),
        _section(
          context,
          title: 'New products near your trade',
          link: ('Open Catalog', '/products'),
          children: [
            if (products?.items.isEmpty == true) Text('No products have been published yet.', style: context.emptyText),
            AutoGrid(
              minItemWidth: 240,
              gap: context.screenWidth >= 1280 ? 33 : 16,
              children: [for (final p in products?.items ?? const <Product>[]) _ProductTile(p)],
            ),
          ],
        ),
      ],
    );

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Notifications',
          style: TextStyle(fontSize: 20, height: 32 / 20, fontWeight: FontWeight.w500, color: context.ink),
        ),
        const SizedBox(height: 24),
        if (notes != null && topNotes.isEmpty) Text("You're all caught up.", style: context.emptyText),
        for (final n in topNotes)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: NotificationItem(n: n),
          ),
        const SizedBox(height: 8),
        Text('Business profiles to follow', style: _sideHeading(context)),
        const SizedBox(height: 16),
        _SidePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (suggestions?.isEmpty == true) Text('You follow every business we know about.', style: context.emptyText),
              for (final biz in suggestions ?? const <Map<String, dynamic>>[]) ...[_Suggestion(biz), const SizedBox(height: 24)],
              const SizedBox(height: 8),
              LinkBox(
                href: '/explore?tab=peoples',
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.pick(Hex.text, Dak.border)),
                  ),
                  child: Text('See more in Explore', style: TextStyle(fontSize: 16, height: 1.5, color: context.ink)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('My Classrooms', style: _sideHeading(context)),
        const SizedBox(height: 16),
        _SidePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (active?.items.isEmpty == true)
                _EmptyWithLink(text: 'No classes in progress. ', link: 'Join one with a code', href: '/classrooms/join'),
              for (final (i, c) in (active?.items ?? const <ClassroomCard>[]).indexed) ...[
                if (i > 0) const SizedBox(height: 16),
                _ProgressCard(c),
              ],
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(greetingText: '${greeting()}, $firstName.'),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
              label: 'ACTIVE WORKSPACES',
              value: stats?['workspaces']?['total'],
              note: '+${stats?['workspaces']?['newThisWeek'] ?? 0} this week',
              noteColor: Hex.google,
              loaded: stats != null,
            ),
            _StatCard(
              label: 'CANVASES',
              value: stats?['canvases']?['total'],
              note: '${stats?['canvases']?['public'] ?? 0} Shared publicly',
              noteColor: context.mutedText,
              loaded: stats != null,
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 935, child: main),
              const SizedBox(width: 32),
              Expanded(flex: 452, child: side),
            ],
          )
        else ...[
          main,
          const SizedBox(height: 32),
          side,
        ],
      ],
    );
  }
}

TextStyle _sideHeading(BuildContext context) => TextStyle(fontSize: 20, height: 32 / 20, fontWeight: FontWeight.w600, color: context.ink);

Widget _section(BuildContext context, {String? title, Widget? titleWidget, (String, String)? link, required List<Widget> children}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(
        title: titleWidget ?? Text(title!, style: context.sectionHeading),
        trailing: link == null ? null : TextLink(link.$1, href: link.$2, style: context.sectionLink),
      ),
      const SizedBox(height: 16),
      for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: 16), c],
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading({required this.greetingText});

  final String greetingText;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greetingText, style: context.pageTitle),
        const SizedBox(height: 4),
        Text("Here's what's happening across your network.", style: TextStyle(fontSize: 16, height: 1.5, color: context.body)),
      ],
    );

    final canvasButton = CreateCanvasButton(
      builder: (onPressed) => ActionButton(
        width: 185,
        color: Light.darkSurface,
        border: true,
        icon: const AssetIcon('icons/new-canvas-white.svg', width: 12, height: 15),
        label: 'Create Canvas',
        onTap: onPressed,
      ),
    );
    final workspaceButton = ActionButton(
      width: 209,
      color: Dak.cta,
      icon: const AssetIcon('icons/new-workspace.svg', width: 16, height: 12),
      label: 'Create Workspace',
      onTap: () => context.go('/workspaces/create'),
    );

    if (!context.isSm) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [title, const SizedBox(height: 16), canvasButton, const SizedBox(height: 12), workspaceButton],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: title),
        canvasButton,
        const SizedBox(width: 12),
        workspaceButton,
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.note, required this.noteColor, required this.loaded});

  final String label;
  final Object? value;
  final String note;
  final Color noteColor;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      width: context.isSm ? 240 : double.infinity,
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 41),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Dak.cta),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark ? const [Dak.surface, Dak.surface] : const [Colors.white, Color(0xFFF3E8FF)],
        ),
        boxShadow: [BoxShadow(color: Dak.cta.withValues(alpha: .25), offset: const Offset(0, 4), blurRadius: 4)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w500,
              letterSpacing: .28,
              color: dark ? Dak.heading : Hex.text,
            ),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: const TextStyle(height: 1, fontWeight: FontWeight.w500, letterSpacing: .28),
              children: [
                TextSpan(
                  text: '${value ?? '–'}',
                  style: TextStyle(fontSize: 28, color: context.ink),
                ),
                const TextSpan(text: ' '),
                TextSpan(
                  text: loaded ? note : '',
                  style: TextStyle(fontSize: 14, color: noteColor),
                ),
              ],
            ),
            softWrap: false,
          ),
        ],
      ),
    );
  }
}

class _EmptyWithLink extends StatelessWidget {
  const _EmptyWithLink({required this.text, required this.link, required this.href});

  final String text;
  final String link;
  final String href;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        children: [
          LinkText(
            text: text.trimRight(),
            link: link,
            underline: false,
            textColor: context.pick(const Color(0xFF45464D), Dak.muted),
            onTap: () => context.go(href),
          ),
          Text('.', style: context.emptyText),
        ],
      ),
    );
  }
}

class _FeaturedClassroom extends StatelessWidget {
  const _FeaturedClassroom(this.c);

  final ClassroomCard c;

  @override
  Widget build(BuildContext context) {
    return LinkBox(
      href: '/classrooms/${c.id}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 100),
        padding: const EdgeInsets.fromLTRB(24, 9, 25, 9),
        decoration: cardDecoration(context),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.pick(Hex.black, Dak.border), width: .5),
              ),
              child: UserImage(src: c.imageUrl, fallback: 'illustrations/classroom-thumb-laptop.jpg'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 16, 4),
                    child: Text(
                      c.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, height: 16 / 14, fontWeight: FontWeight.w500, letterSpacing: .28, color: context.ink),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      c.instructor.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, height: 16 / 12, letterSpacing: .28, color: context.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [PurpleTag('${c.enrolledCount} Enrolled'), PurpleTag(c.progress == null ? 'Public Preview' : 'Enrolled')],
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

class _CanvasTable extends StatelessWidget {
  const _CanvasTable({required this.rows});

  final List<CanvasCard>? rows;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final gapX = context.dvw(16, 3.3, 62);

    Widget cols(List<Widget> cells) => Row(
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: SizedBox(width: 290, child: cells[0]),
          ),
        ),
        SizedBox(width: gapX),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: SizedBox(width: 200, child: cells[1]),
          ),
        ),
        SizedBox(width: gapX),
        SizedBox(width: 94, child: cells[2]),
        SizedBox(width: gapX),
        SizedBox(width: 81, child: cells[3]),
      ],
    );

    final cell = TextStyle(fontSize: 16, height: 1, letterSpacing: .28, color: dark ? Dak.muted : Hex.text);
    final items = rows ?? const <CanvasCard>[];

    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: dark ? Light.darkSurface : Hex.text,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(fontSize: 16, height: 40 / 16, letterSpacing: -.32, color: Colors.white),
            child: cols(const [
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('Canvas', overflow: TextOverflow.ellipsis),
              ),
              Text('Workspace', overflow: TextOverflow.ellipsis),
              Text('Last Edited', softWrap: false),
              Padding(padding: EdgeInsets.only(left: 12), child: Text('Visibility', softWrap: false)),
            ]),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: dark ? Dak.surface : Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            border: Border(
              left: BorderSide(color: dark ? Dak.border : Hex.text.withValues(alpha: .4)),
              right: BorderSide(color: dark ? Dak.border : Hex.text.withValues(alpha: .4)),
              bottom: BorderSide(color: dark ? Dak.border : Hex.text.withValues(alpha: .4)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows != null && items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Canvases you create or edit show up here.', style: context.emptyText),
                ),
              for (final (i, row) in items.indexed) ...[
                if (i > 0) const SizedBox(height: 16),
                LinkBox(
                  href: '/canvas/${row.id}',
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: i == items.length - 1
                        ? null
                        : BoxDecoration(
                            border: Border(bottom: BorderSide(color: dark ? Dak.border : Dak.line, width: .5)),
                          ),
                    child: cols([
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: dark ? Dak.border : const Color(0xFF191919)),
                            ),
                            child: UserImage(src: row.thumbnailUrl, fallback: 'illustrations/canvas-thumb-mortar-pattern.jpg'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              row.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1,
                                fontWeight: FontWeight.w500,
                                letterSpacing: .28,
                                color: context.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(row.workspaceName, overflow: TextOverflow.ellipsis, style: cell),
                      Text(timeAgo(row.updatedAt), softWrap: false, style: cell),
                      VisibilityBadge(public: row.visibility == Access.public),
                    ]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Hex.text.withValues(alpha: .2), offset: const Offset(0, 4), blurRadius: 4)],
      ),
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 600
            ? table
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: 600, child: table),
              ),
      ),
    );
  }
}

/// Green "Public" / grey "Private" badge.
class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge({super.key, required this.public, this.width = 81});

  final bool public;
  final double width;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      width: width,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: public ? Hex.google.withValues(alpha: .15) : (dark ? Dak.cta.withValues(alpha: .1) : Hex.black.withValues(alpha: .1)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          width: .5,
          color: public ? Hex.google.withValues(alpha: .15) : (dark ? Dak.border : Hex.black.withValues(alpha: .15)),
        ),
      ),
      child: Text(
        public ? 'Public' : 'Private',
        style: TextStyle(
          fontSize: 14,
          height: 15 / 14,
          fontWeight: FontWeight.w500,
          color: public ? Hex.google : (dark ? Dak.heading : Hex.black),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile(this.p);

  final Product p;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return LinkBox(
      href: '/products/${p.id}',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 130,
              child: ColoredBox(
                color: dark ? Dak.surface : Hex.text,
                child: UserImage(src: p.images.firstOrNull, fallback: 'illustrations/classroom-thumb-engineers.jpg'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: TextStyle(fontSize: 16, height: 1, fontWeight: FontWeight.w500, letterSpacing: .28, color: context.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By ${p.business.name}',
                    style: TextStyle(fontSize: 14, height: 16 / 14, letterSpacing: .28, color: context.mutedText),
                  ),
                  if (p.size != null) ...[const SizedBox(height: 8), PurpleTag(p.size!, bordered: true)],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(24), decoration: cardDecoration(context, radius: 16), child: child);
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion(this.biz);

  final Map<String, dynamic> biz;

  @override
  Widget build(BuildContext context) {
    final summary = UserSummary.fromJson(biz);
    final href = '/business/${summary.id}';
    return Row(
      children: [
        LinkBox(
          href: href,
          child: Avatar(src: summary.avatarUrl, name: summary.name),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: LinkBox(
            href: href,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, height: 1, fontWeight: FontWeight.w500, letterSpacing: .28, color: context.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '${biz['industry'] ?? 'Business'}. ${plural(biz['productCount'] as int? ?? 0, 'product')}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, height: 20 / 14, color: context.mutedText),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        FollowButton(userId: summary.id, initial: false),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard(this.c);

  final ClassroomCard c;

  @override
  Widget build(BuildContext context) {
    final progress = c.progress ?? 0;
    return LinkBox(
      href: '/classrooms/${c.id}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 105),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Hex.text,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Hex.black.withValues(alpha: .3), offset: const Offset(0, 8), blurRadius: 4)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    c.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFFF3F3F3)),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${c.progress}%', style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            ProgressBar(value: progress / 100),
            const SizedBox(height: 8),
            Text(
              '${c.completedLessons} of ${plural(c.lessonCount, 'lesson')} complete',
              style: const TextStyle(fontSize: 12, height: 18 / 12, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
