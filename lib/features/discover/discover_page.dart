import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/post.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/card_box.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/states.dart';
import '../shared/post_widgets.dart';

const _tabs = [('latest', 'For You', 115.0), ('following', 'Following', 147.0)];

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  String _feed = 'latest';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final posts = pagedOf(ref, withQuery('/posts', {'feed': _feed, 'page': _page, 'limit': 10}), Post.fromJson);
    final trending = pagedOf(ref, '/posts?feed=trending&limit=4', Post.fromJson);
    final following = _feed == 'following';
    final grey = dark ? Dak.muted : const Color(0xFF929292);

    final tabs = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, (value, label, width)) in _tabs.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Material(
            color: _feed == value ? (dark ? Dak.cta : Hex.text) : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: _feed == value ? BorderSide.none : BorderSide(color: dark ? Dak.border : Hex.text),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() {
                _feed = value;
                _page = 1;
              }),
              child: SizedBox(
                width: width,
                height: 48,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .28,
                      color: _feed == value ? Colors.white : context.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
    final create = Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Dak.cta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide.none),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go('/discover/create-post'),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .2))),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AssetIcon('icons/plus.svg', width: 11, height: 11),
                SizedBox(width: 8),
                Text(
                  'Create Post',
                  style: TextStyle(fontSize: 14, height: 1, fontWeight: FontWeight.w500, letterSpacing: .28, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final feed = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 17),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: dark ? Dak.border : Dak.line)),
          ),
          child: context.isSm
              ? Row(children: [tabs, const Spacer(), create])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [tabs, const SizedBox(height: 16), create]),
        ),
        const SizedBox(height: 24),
        if (posts == null)
          const LoadingGrid(count: 2, minWidth: 500, height: 360)
        else if (posts.items.isEmpty)
          EmptyState(
            title: following ? 'Nothing from people you follow yet' : 'No posts yet',
            body: following
                ? 'Follow people and businesses from Explore to fill this feed.'
                : 'Be the first to share something with the network.',
            actionLabel: following ? 'Explore' : 'Create Post',
            actionHref: following ? '/explore?tab=peoples' : '/discover/create-post',
          )
        else
          for (final (i, post) in posts.items.indexed) ...[
            if (i > 0) const SizedBox(height: 24),
            FeedPostCard(key: ValueKey(post.id), post: post),
          ],
        if (posts != null) ...[
          const SizedBox(height: 24),
          Pager(page: posts.page, pages: posts.pages, onPage: (p) => setState(() => _page = p)),
        ],
      ],
    );

    final aside = Container(
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.all(17),
      decoration: cardDecoration(context, blur: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 9),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: dark ? Dak.border : Dak.line)),
            ),
            child: Row(
              children: [
                AssetIcon('icons/trending-up.svg', width: 15, height: 9, color: dark ? Colors.white : null),
                const SizedBox(width: 8),
                Text(
                  'Trending',
                  style: TextStyle(fontSize: 14, height: 1, fontWeight: FontWeight.w700, letterSpacing: .28, color: context.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (trending?.items.isEmpty == true) Text('Nothing trending this month.', style: TextStyle(fontSize: 14, color: grey)),
          for (final (i, item) in (trending?.items ?? const <Post>[]).indexed) ...[
            if (i > 0) const SizedBox(height: 16),
            LinkBox(
              href: '/discover/post/${item.id}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(fontSize: 14, height: 1.15, fontWeight: FontWeight.w500, letterSpacing: .28, color: context.ink),
                  ),
                  const SizedBox(height: 3.5),
                  Text(
                    'By ${item.author.name} • ${compactNumber(item.viewCount)} views',
                    style: TextStyle(fontSize: 14, height: 20 / 14, color: grey),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Discover Feeds', style: context.pageTitle),
        const SizedBox(height: 4),
        Text('Here’s what’s happening across your network.', style: TextStyle(fontSize: 16, height: 1.5, color: context.body)),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: context.screenWidth >= 1280
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: feed),
                    const SizedBox(width: 32),
                    SizedBox(width: 320, child: aside),
                  ],
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [feed, const SizedBox(height: 32), aside]),
        ),
      ],
    );
  }
}
