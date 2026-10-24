import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/canvas.dart';
import '../../models/classroom.dart';
import '../../models/post.dart';
import '../../models/user.dart';
import '../../theme/tokens.dart';
import '../../ui/auto_grid.dart';
import '../../ui/card_box.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/states.dart';
import '../shared/cards.dart';
import '../shared/social.dart';
import '../shared/workspace_card.dart';

const _tabs = [
  ('latest', 'Latest'),
  ('canvases', 'Canvases'),
  ('discussions', 'Discussions'),
  ('classrooms', 'Classrooms'),
  ('peoples', 'Peoples & Business'),
];

TextStyle _h3(BuildContext context) => TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: context.ink);

TextStyle _empty(BuildContext context) => TextStyle(fontSize: 14, color: context.pick(const Color(0xFF929292), Dak.muted));

Widget _classCard(ClassroomCard c) => ClassCard(
  href: '/classrooms/${c.id}',
  title: c.title,
  subtitle: c.instructor.name,
  modules: plural(c.moduleCount, 'module'),
  tag: '${c.enrolledCount} Enrolled',
  imageSrc: c.imageUrl,
);

Widget _canvasCard(CanvasCard c) => WorkspaceCard(
  href: '/canvas/${c.id}',
  title: c.title,
  workspace: c.workspaceName,
  editedAgo: 'Edited ${timeAgo(c.updatedAt)} · ${plural(c.productCount, 'Product')}',
  updatedTag: 'By ${c.createdBy.name}',
  collaborators: [c.createdBy],
  collaboratorCount: c.collaboratorCount,
  imageSrc: c.thumbnailUrl,
);

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, this.tab, this.q = ''});

  final String? tab;
  final String q;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late String _tab = _tabs.any((t) => t.$1 == widget.tab) ? widget.tab! : 'latest';

  void _select(String tab) {
    setState(() => _tab = tab);
    context.go(withQuery('/explore', {'tab': tab == 'latest' ? null : tab, 'q': widget.q.isEmpty ? null : widget.q}));
  }

  @override
  void didUpdateWidget(covariant ExplorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab) _tab = _tabs.any((t) => t.$1 == widget.tab) ? widget.tab! : 'latest';
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final q = widget.q;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          q.isNotEmpty ? 'Results for “$q”' : 'Explore what the trades are building',
          style: TextStyle(
            fontSize: context.isSm ? 32 : 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -.32,
            color: dark ? Dak.heading : Auth.navy,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                'Public canvases, classrooms, profiles. Newest first.',
                style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.slate),
              ),
            ),
            if (q.isNotEmpty) ...[
              const SizedBox(width: 8),
              const TextLink(
                'Clear search',
                href: '/explore',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Dak.cta),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: dark ? Dak.border : Light.border)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, (id, label)) in _tabs.indexed) ...[
                  if (i > 0) const SizedBox(width: 32),
                  InkWell(
                    onTap: () => _select(id),
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: _tab == id ? Border(bottom: BorderSide(color: dark ? Dak.cta : Hex.black, width: 4)) : null,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: _tab == id ? context.ink : (dark ? Dak.muted : const Color(0xFF929292)),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        switch (_tab) {
          'canvases' => _CanvasesTab(q: q),
          'discussions' => _DiscussionsTab(q: q),
          'classrooms' => _ClassroomsTab(q: q),
          'peoples' => _PeopleTab(q: q),
          _ => _Latest(q: q, onTab: _select),
        },
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: _h3(context))),
      if (onSeeAll != null)
        InkWell(
          onTap: onSeeAll,
          child: const Text(
            'See All',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Dak.cta),
          ),
        ),
    ],
  );
}

Widget _section(List<Widget> children) => Padding(
  padding: const EdgeInsets.only(bottom: 24),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: 16), c],
    ],
  ),
);

class _Latest extends ConsumerStatefulWidget {
  const _Latest({required this.q, required this.onTab});

  final String q;
  final ValueChanged<String> onTab;

  @override
  ConsumerState<_Latest> createState() => _LatestState();
}

class _LatestState extends ConsumerState<_Latest> {
  Feed _feed = Feed.trending;

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final classrooms = pagedOf(ref, withQuery('/classrooms', {'scope': 'explore', 'q': q, 'limit': 4}), ClassroomCard.fromJson);
    final posts = pagedOf(ref, withQuery('/posts', {'feed': _feed.name, 'q': q, 'limit': 3}), Post.fromJson);
    final people = pagedOf(ref, withQuery('/people', {'type': 'BUSINESS', 'q': q, 'limit': 3}), PersonCard.fromJson);
    final canvases = pagedOf(ref, withQuery('/canvases/public', {'q': q, 'limit': 4}), CanvasCard.fromJson);

    final community = Wrap(
      spacing: context.isSm ? 24 : 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('From the community', style: _h3(context)),
        FeedToggle(value: _feed, onChanged: (f) => setState(() => _feed = f)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section([
          _Header(title: 'Classrooms', onSeeAll: () => widget.onTab('classrooms')),
          if (classrooms?.items.isEmpty == true) Text('No public classrooms yet.', style: _empty(context)),
          AutoGrid(
            minItemWidth: 240,
            gap: 24,
            fill: true,
            children: [for (final c in classrooms?.items ?? const <ClassroomCard>[]) _classCard(c)],
          ),
        ]),
        _section([
          context.isSm
              ? Row(
                  children: [
                    Expanded(child: community),
                    const TextLink(
                      'See All',
                      href: '/discover',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Dak.cta),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    community,
                    const SizedBox(height: 16),
                    const TextLink(
                      'See All',
                      href: '/discover',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Dak.cta),
                    ),
                  ],
                ),
          if (posts?.items.isEmpty == true) Text('No posts to show.', style: _empty(context)),
          AutoGrid(minItemWidth: 260, fill: true, children: [for (final p in posts?.items ?? const <Post>[]) CommunityPostCard(post: p)]),
        ]),
        _section([
          _Header(title: 'Business Profiles', onSeeAll: () => widget.onTab('peoples')),
          if (people?.items.isEmpty == true) Text('No business profiles yet.', style: _empty(context)),
          AutoGrid(
            minItemWidth: 300,
            gap: 24,
            fill: true,
            children: [for (final p in people?.items ?? const <PersonCard>[]) BusinessProfileCard(person: p)],
          ),
        ]),
        _section([
          _Header(title: 'Public Canvases', onSeeAll: () => widget.onTab('canvases')),
          if (canvases?.items.isEmpty == true) Text('No public canvases yet.', style: _empty(context)),
          AutoGrid(
            minItemWidth: 280,
            gap: 24,
            fill: true,
            children: [for (final c in canvases?.items ?? const <CanvasCard>[]) _canvasCard(c)],
          ),
        ]),
      ],
    );
  }
}

class _CanvasesTab extends ConsumerStatefulWidget {
  const _CanvasesTab({required this.q});

  final String q;

  @override
  ConsumerState<_CanvasesTab> createState() => _CanvasesTabState();
}

class _CanvasesTabState extends ConsumerState<_CanvasesTab> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final data = pagedOf(ref, withQuery('/canvases/public', {'q': widget.q, 'page': _page, 'limit': 12}), CanvasCard.fromJson);
    return _section([
      Text('Public Canvases', style: _h3(context)),
      if (data == null)
        const LoadingGrid(minWidth: 280)
      else if (data.items.isEmpty)
        const EmptyState(title: 'No public canvases', body: 'Canvases made public by their creators appear here.')
      else
        AutoGrid(minItemWidth: 280, gap: 24, fill: true, children: [for (final c in data.items) _canvasCard(c)]),
      if (data != null) Pager(page: data.page, pages: data.pages, onPage: (p) => setState(() => _page = p)),
    ]);
  }
}

class _DiscussionsTab extends ConsumerStatefulWidget {
  const _DiscussionsTab({required this.q});

  final String q;

  @override
  ConsumerState<_DiscussionsTab> createState() => _DiscussionsTabState();
}

class _DiscussionsTabState extends ConsumerState<_DiscussionsTab> {
  Feed _feed = Feed.following;

  @override
  Widget build(BuildContext context) {
    final posts = pagedOf(ref, withQuery('/posts', {'feed': _feed.name, 'q': widget.q, 'limit': 6}), Post.fromJson);
    final latest = pagedOf(ref, withQuery('/posts', {'feed': 'latest', 'q': widget.q, 'limit': 6}), Post.fromJson);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section([
          Wrap(
            spacing: context.isSm ? 24 : 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('From the community', style: _h3(context)),
              FeedToggle(value: _feed, onChanged: (f) => setState(() => _feed = f)),
            ],
          ),
          if (posts?.items.isEmpty == true) Text('Nothing here yet.', style: _empty(context)),
          AutoGrid(minItemWidth: 260, fill: true, children: [for (final p in posts?.items ?? const <Post>[]) CommunityPostCard(post: p)]),
        ]),
        _section([
          Text('Latest Posts', style: _h3(context)),
          AutoGrid(minItemWidth: 260, fill: true, children: [for (final p in latest?.items ?? const <Post>[]) CommunityPostCard(post: p)]),
        ]),
      ],
    );
  }
}

class _ClassroomsTab extends ConsumerStatefulWidget {
  const _ClassroomsTab({required this.q});

  final String q;

  @override
  ConsumerState<_ClassroomsTab> createState() => _ClassroomsTabState();
}

class _ClassroomsTabState extends ConsumerState<_ClassroomsTab> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final data = pagedOf(
      ref,
      withQuery('/classrooms', {'scope': 'explore', 'q': widget.q, 'page': _page, 'limit': 12}),
      ClassroomCard.fromJson,
    );
    return _section([
      Text('Classrooms', style: _h3(context)),
      if (data == null)
        const LoadingGrid(minWidth: 240)
      else if (data.items.isEmpty)
        const EmptyState(title: 'No public classrooms', body: 'Published public classrooms appear here.')
      else
        AutoGrid(minItemWidth: 240, gap: 24, fill: true, children: [for (final c in data.items) _classCard(c)]),
      if (data != null) Pager(page: data.page, pages: data.pages, onPage: (p) => setState(() => _page = p)),
    ]);
  }
}

class _PeopleTab extends ConsumerStatefulWidget {
  const _PeopleTab({required this.q});

  final String q;

  @override
  ConsumerState<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends ConsumerState<_PeopleTab> {
  String? _type = 'BUSINESS';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final data = pagedOf(ref, withQuery('/people', {'type': _type, 'q': widget.q, 'page': _page, 'limit': 12}), PersonCard.fromJson);
    const filters = [('BUSINESS', 'Businesses'), ('INDIVIDUAL', 'People'), (null, 'Everyone')];
    final title = _type == 'INDIVIDUAL' ? 'People' : (_type != null ? 'Business Profiles' : 'Peoples & Business');

    return _section([
      Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(title, style: _h3(context)),
          Wrap(
            spacing: 8,
            children: [
              for (final (value, label) in filters)
                Material(
                  color: _type == value ? (dark ? Dak.cta : Hex.text) : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: _type == value ? BorderSide.none : BorderSide(color: dark ? Dak.border : Hex.black),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() {
                      _type = value;
                      _page = 1;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _type == value ? FontWeight.w600 : FontWeight.w400,
                          color: _type == value ? Colors.white : context.ink,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      if (data == null)
        const LoadingGrid(minWidth: 300)
      else if (data.items.isEmpty)
        const EmptyState(title: 'No profiles found', body: 'Only public, searchable profiles appear here.')
      else
        AutoGrid(minItemWidth: 300, gap: 24, fill: true, children: [for (final p in data.items) BusinessProfileCard(person: p)]),
      if (data != null) Pager(page: data.page, pages: data.pages, onPage: (p) => setState(() => _page = p)),
    ]);
  }
}
