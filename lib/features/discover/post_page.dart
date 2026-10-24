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
import '../../ui/states.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';
import '../shared/post_widgets.dart';
import '../shared/report_button.dart';
import '../shared/rich_text.dart';

class PostPage extends ConsumerWidget {
  const PostPage({super.key, required this.postId});

  final String postId;

  Future<void> _remove(BuildContext context, WidgetRef ref, Post post) async {
    if (!await confirmAction(context, 'Delete this post?')) return;
    final toast = ref.read(toastProvider.notifier);
    try {
      await ref.read(apiProvider).delete<dynamic>('/posts/${post.id}');
      invalidateQueries(ref);
      toast.show('Post deleted');
      if (context.mounted) context.go('/discover');
    } catch (e) {
      toast.error(errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(query('/posts/$postId'));
    if (result.hasError) return ErrorState(error: result.error!);
    final json = result.value as Map<String, dynamic>?;
    if (json == null) return const SizedBox.shrink();
    final post = Post.fromJson(json);

    final dark = context.isDark;
    final mine = post.author.id == ref.watch(authProvider)?.id;
    final image = post.imageUrl ?? post.canvas?.thumbnailUrl;
    final navy = dark ? Dak.heading : Auth.navy;
    final border = dark ? Dak.border : Light.border;
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    final kind = post.author.specialty ?? titleCase(post.author.isBusiness ? 'BUSINESS' : 'INDIVIDUAL');

    BoxDecoration panel() => BoxDecoration(
      color: dark ? Dak.surface : Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: border),
    );
    final caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: .4, color: grey);

    final details = [
      ('Posted', timeAgo(post.createdAt)),
      ('Views', compactNumber(post.viewCount)),
      ('Category', post.category ?? '—'),
      ('Visibility', titleCase(post.visibility == Access.private ? 'PRIVATE' : 'PUBLIC')),
      if (post.canvas != null) ('Canvas', post.canvas!.title),
    ];

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (image != null)
          Container(
            height: 380,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              border: Border(
                top: BorderSide(color: border),
                left: BorderSide(color: border),
                right: BorderSide(color: border),
              ),
            ),
            child: UserImage(src: image),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: dark ? Dak.surface : Colors.white,
            borderRadius: image != null ? const BorderRadius.vertical(bottom: Radius.circular(6)) : BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
            child: Row(
              children: [
                LikeButton(postId: post.id, liked: post.liked, count: post.likeCount, size: 18),
                const SizedBox(width: 24),
                Text('💬 ${post.commentCount} Comments'),
                const Spacer(),
                if (mine)
                  InkWell(
                    onTap: () => _remove(context, ref, post),
                    child: Text(
                      'Delete',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: grey),
                    ),
                  )
                else
                  ReportButton(targetType: 'POST', targetId: post.id),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        CommentThread(postId: post.id, postAuthorId: post.author.id),
      ],
    );

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: panel(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AUTHOR', style: caption),
              const SizedBox(height: 16),
              Row(
                children: [
                  Avatar(src: post.author.avatarUrl, name: post.author.name),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.name,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: navy),
                      ),
                      Text(kind, style: TextStyle(fontSize: 14, color: grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextLink(
                'View Profile →',
                href: mine ? '/profile' : profileHref(post.author),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Dak.cta),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: panel(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('DETAILS', style: caption),
              const SizedBox(height: 12),
              for (final (i, (label, value)) in details.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: i == 0
                      ? null
                      : BoxDecoration(
                          border: Border(top: BorderSide(color: border)),
                        ),
                  child: Row(
                    children: [
                      Text(label, style: TextStyle(fontSize: 14, color: dark ? Dak.body : Auth.navy)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          value,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                        ),
                      ),
                    ],
                  ),
                ),
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('TAGS', style: caption),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in post.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: dark ? Dak.bg : const Color(0xFFF2F2F3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Text(tag, style: TextStyle(fontSize: 14, color: navy)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => context.go('/discover'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.flip(
                  flipX: true,
                  child: AssetIcon(
                    context.pick('icons/arrow-narrow-right.svg', 'icons/arrow-narrow-right-light.svg'),
                    width: 20,
                    height: 20,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Back to feed',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navy),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          post.title,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: navy),
        ),
        const SizedBox(height: 8),
        PostText(post.body, style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.navy)),
        if (post.canvas != null) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: dark ? Dak.cta : Auth.navy,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.go('/discover-canvas/${post.id}'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    '⧉ Open Canvas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (context.isLg)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              const SizedBox(width: 24),
              SizedBox(width: 360, child: side),
            ],
          )
        else ...[
          main,
          const SizedBox(height: 24),
          side,
        ],
      ],
    );
  }
}
