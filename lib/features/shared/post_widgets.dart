import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/post.dart';
import '../../models/user.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/page_bits.dart';
import '../../ui/popover.dart';
import '../../ui/states.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';
import 'report_button.dart';
import 'rich_text.dart';

/// Optimistic like toggle.
class LikeButton extends ConsumerStatefulWidget {
  const LikeButton({super.key, required this.postId, required this.liked, required this.count, this.size = 21});

  final String postId;
  final bool liked;
  final int count;
  final double size;

  @override
  ConsumerState<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<LikeButton> {
  late bool _liked = widget.liked;
  late int _count = widget.count;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final next = !_liked;
    setState(() {
      _liked = next;
      _count += next ? 1 : -1;
      _busy = true;
    });
    final api = ref.read(apiProvider);
    try {
      final res = next
          ? await api.post<Map<String, dynamic>>('/posts/${widget.postId}/like')
          : await api.delete<Map<String, dynamic>>('/posts/${widget.postId}/like');
      if (mounted) setState(() => _count = res['likeCount'] as int);
    } catch (e) {
      if (mounted) {
        setState(() {
          _liked = !next;
          _count += next ? -1 : 1;
        });
      }
      ref.read(toastProvider.notifier).error(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final icon = AssetIcon('icons/like.svg', width: widget.size, height: widget.size - 1);
    return Tooltip(
      message: _liked ? 'Unlike' : 'Like',
      child: InkWell(
        onTap: _toggle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_liked)
              icon
            else
              Opacity(
                opacity: .5,
                child: ColorFiltered(colorFilter: ColorFilter.mode(dark ? Colors.white : Colors.grey, BlendMode.srcIn), child: icon),
              ),
            const SizedBox(width: 8),
            Text('$_count', style: TextStyle(color: _liked ? Dak.cta : null)),
          ],
        ),
      ),
    );
  }
}

/// Post card in the Discover feed, from components/cards/FeedPostCard.tsx.
class FeedPostCard extends ConsumerStatefulWidget {
  const FeedPostCard({super.key, required this.post});

  final Post post;

  @override
  ConsumerState<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends ConsumerState<FeedPostCard> {
  bool _menu = false;

  Future<void> _remove() async {
    setState(() => _menu = false);
    if (!await confirmAction(context, 'Delete this post?')) return;
    final toast = ref.read(toastProvider.notifier);
    try {
      await ref.read(apiProvider).delete<dynamic>('/posts/${widget.post.id}');
      invalidateQueries(ref);
      toast.show('Post deleted');
    } catch (e) {
      toast.error(errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final dark = context.isDark;
    final mine = post.author.id == ref.watch(authProvider)?.id;
    final href = '/discover/post/${post.id}';
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    final body = dark ? Dak.body : Hex.text;
    final meta = [
      post.author.specialty ?? titleCase(post.author.isBusiness ? 'BUSINESS' : 'INDIVIDUAL'),
      timeAgo(post.createdAt),
      if (post.visibility == Access.private) 'Private',
    ].join(' • ');

    return Container(
      padding: EdgeInsets.all(context.isSm ? 25 : 16),
      decoration: BoxDecoration(
        color: dark ? Dak.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? Dak.border : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LinkBox(
                  href: profileHref(post.author),
                  child: Row(
                    children: [
                      Avatar(src: post.author.avatarUrl, name: post.author.name),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.author.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 16 / 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .28,
                                color: dark ? Dak.heading : Hex.black,
                              ),
                            ),
                            Text(
                              meta,
                              softWrap: false,
                              style: TextStyle(fontSize: 14, height: 20 / 14, color: grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Popover(
                open: _menu,
                onClose: () => setState(() => _menu = false),
                width: 160,
                panel: MenuCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: mine
                        ? InkWell(
                            onTap: _remove,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 40),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Text(
                                'Delete post',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Hex.error),
                              ),
                            ),
                          )
                        : Container(
                            constraints: const BoxConstraints(minHeight: 40),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ReportButton(
                              targetType: 'POST',
                              targetId: post.id,
                              label: 'Report post',
                              style: TextStyle(fontSize: 14, color: dark ? Dak.heading : Auth.navy),
                            ),
                          ),
                  ),
                ),
                child: Tooltip(
                  message: 'More',
                  child: InkWell(
                    onTap: () => setState(() => _menu = !_menu),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                      child: AssetIcon('icons/dots-horizontal.svg', width: 16, height: 4, color: dark ? Colors.white : null),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinkBox(
            href: href,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    post.title,
                    style: TextStyle(
                      fontSize: context.isSm ? 24 : 20,
                      height: 32 / (context.isSm ? 24 : 20),
                      fontWeight: FontWeight.w600,
                      color: dark ? Dak.heading : Hex.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PostText(post.body, style: TextStyle(fontSize: 16, height: 1.5, color: body)),
                  if (post.imageUrl != null) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: context.isSm ? 400 : 220,
                        child: ColoredBox(
                          color: dark ? Dak.bg : const Color(0xFFEAEAEA),
                          child: UserImage(src: post.imageUrl),
                        ),
                      ),
                    ),
                  ],
                  if (post.canvas != null && post.imageUrl == null) ...[
                    const SizedBox(height: 16),
                    CustomPaint(
                      foregroundPainter: DashedBorder(color: Dak.cta, radius: 16),
                      child: Container(
                        height: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Dak.cta.withValues(alpha: .06), borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          'Shared canvas: ${post.canvas!.title}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Dak.cta),
                        ),
                      ),
                    ),
                  ],
                  if (post.tags.isNotEmpty || post.category != null) ...[
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (post.category != null) _Chip(post.category!, fill: dark ? Dak.cta : Hex.text, color: Colors.white),
                        for (final tag in post.tags)
                          _Chip(
                            '#${tag.replaceAll(RegExp(r'\s+'), '').toLowerCase()}',
                            fill: Dak.cta.withValues(alpha: .1),
                            color: Dak.cta,
                            border: Dak.cta,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 17),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: dark ? Dak.border : Dak.line)),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w500,
                letterSpacing: .28,
                color: dark ? Dak.heading : Hex.text,
              ),
              child: Row(
                children: [
                  LikeButton(postId: post.id, liked: post.liked, count: post.likeCount),
                  const SizedBox(width: 24),
                  InkWell(
                    onTap: () => context.go(href),
                    child: Row(
                      children: [
                        AssetIcon('icons/comment.svg', width: 20, height: 20, color: dark ? Colors.white : null),
                        const SizedBox(width: 8),
                        Text('${post.commentCount}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.fill, required this.color, this.border});

  final String label;
  final Color fill;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(12),
      border: border == null ? null : Border.all(color: border!),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, height: 1, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

/// Comments under a post (Discover posts and classroom discussions).
class CommentThread extends ConsumerStatefulWidget {
  const CommentThread({super.key, required this.postId, required this.postAuthorId});

  final String postId;
  final String postAuthorId;

  @override
  ConsumerState<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends ConsumerState<CommentThread> {
  final _text = TextEditingController();
  bool _busy = false;

  String get _key => '/posts/${widget.postId}/comments?limit=100';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).post<dynamic>('/posts/${widget.postId}/comments', {'body': body});
      _text.clear();
      invalidateQueries(ref);
    } catch (e) {
      ref.read(toastProvider.notifier).error(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String id) async {
    try {
      await ref.read(apiProvider).delete<dynamic>('/comments/$id');
      invalidateQueries(ref);
    } catch (e) {
      ref.read(toastProvider.notifier).error(errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final me = ref.watch(authProvider)?.id;
    final comments = pagedOf(ref, _key, Comment.fromJson)?.items ?? const <Comment>[];
    final navy = dark ? Dak.heading : Auth.navy;
    const grey = Color(0xFF929292);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in comments) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinkBox(
                href: profileHref(c.author),
                child: Avatar(src: c.author.avatarUrl, name: c.author.name, size: 36),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: dark ? Dak.bg : const Color(0xFFF2F2F3), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          LinkBox(
                            href: profileHref(c.author),
                            child: Text(
                              c.author.name,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: navy),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('• ${timeAgo(c.createdAt)}', style: TextStyle(fontSize: 12, color: dark ? Dak.muted : grey)),
                          const Spacer(),
                          if (c.isMine || widget.postAuthorId == me)
                            InkWell(
                              onTap: () => _remove(c.id),
                              child: const Text('Delete', style: TextStyle(fontSize: 12, color: grey)),
                            ),
                          if (!c.isMine) ...[
                            const SizedBox(width: 12),
                            ReportButton(
                              targetType: 'COMMENT',
                              targetId: c.id,
                              style: const TextStyle(fontSize: 12, color: grey),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(c.body, style: TextStyle(fontSize: 14, color: dark ? Dak.body : Auth.navy)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: dark ? Dak.surface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: dark ? Dak.border : Light.border),
                ),
                child: TextField(
                  controller: _text,
                  maxLength: 5000,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                  style: TextStyle(fontSize: 16, color: navy),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(fontSize: 16, color: dark ? Dak.muted : grey),
                  ).copyWith(counterText: ''),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Opacity(
              opacity: _busy || _text.text.trim().isEmpty ? .5 : 1,
              child: Material(
                color: Dak.cta,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _busy || _text.text.trim().isEmpty ? null : _submit,
                  child: const SizedBox(
                    height: 56,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          'Post',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
