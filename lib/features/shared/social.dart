import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/canvas.dart';
import '../../models/post.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/card_box.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';

enum Feed { trending, following }

class FeedToggle extends StatelessWidget {
  const FeedToggle({super.key, required this.value, required this.onChanged});

  final Feed value;
  final ValueChanged<Feed> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    Widget button(Feed f, String label) {
      final on = value == f;
      return Material(
        color: on ? (dark ? Dak.cta : Hex.text) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: on ? BorderSide.none : BorderSide(color: dark ? Dak.border : Hex.black),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(f),
          child: SizedBox(
            width: 120,
            height: 40,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                  color: on ? Colors.white : (dark ? Dak.heading : Hex.black),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [button(Feed.trending, 'Trending'), const SizedBox(width: 8), button(Feed.following, 'Following')],
    );
  }
}

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final count = TextStyle(fontSize: 12, height: 1, fontWeight: FontWeight.w600, color: context.body);

    return LinkBox(
      href: '/discover/post/${post.id}',
      child: Container(
        padding: const EdgeInsets.all(21),
        decoration: cardDecoration(context, blur: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(src: post.author.avatarUrl, name: post.author.name),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.name,
                      style: TextStyle(fontSize: 16, height: 1, fontWeight: FontWeight.w500, letterSpacing: .28, color: context.ink),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Posted ${timeAgo(post.createdAt)}',
                      style: TextStyle(fontSize: 14, height: 12 / 14, color: dark ? Dak.muted : const Color(0xFF9C9C9C)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.title,
              style: TextStyle(fontSize: 20, height: 32 / 20, fontWeight: FontWeight.w600, color: context.ink),
            ),
            const SizedBox(height: 8),
            Text(
              post.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, height: 1.5, color: context.body),
            ),
            if (post.imageUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 210,
                  child: ColoredBox(
                    color: dark ? Dak.surface : Hex.text,
                    child: UserImage(src: post.imageUrl),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 17),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Dak.line)),
              ),
              child: Row(
                children: [
                  const AssetIcon('icons/like.svg', width: 16, height: 15),
                  const SizedBox(width: 4),
                  Text('${post.likeCount}', style: count),
                  const SizedBox(width: 16),
                  const AssetIcon('icons/comment.svg', width: 15, height: 15),
                  const SizedBox(width: 4),
                  Text('${post.commentCount}', style: count),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optimistic follow / unfollow, like components/social/FollowButton.tsx.
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({
    super.key,
    required this.userId,
    required this.initial,
    this.labels = const ('Follow', 'Following'),
    this.width = 80,
    this.height = 32,
    this.fontSize = 14,
    this.radius = 8,
    this.padding = 8,
    this.look,
  });

  final String userId;
  final bool initial;
  final (String, String) labels;
  final double? width;
  final double height;
  final double fontSize;
  final double radius;
  final double padding;

  /// Custom appearance for each state; the button keeps the tap and busy handling.
  final Widget Function(BuildContext context, bool following)? look;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  late bool _following = widget.initial;
  bool _busy = false;

  Future<void> _toggle() async {
    final next = !_following;
    setState(() {
      _busy = true;
      _following = next;
    });
    final api = ref.read(apiProvider);
    try {
      if (next) {
        await api.post<dynamic>('/users/${widget.userId}/follow');
      } else {
        await api.delete<dynamic>('/users/${widget.userId}/follow');
      }
      invalidateQueries(ref);
    } catch (e) {
      if (mounted) setState(() => _following = !next);
      ref.read(toastProvider.notifier).error(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.look != null) {
      return Opacity(
        opacity: _busy ? .6 : 1,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: _busy ? null : _toggle, child: widget.look!(context, _following)),
        ),
      );
    }
    final dark = context.isDark;
    final on = _following;
    final radius = BorderRadius.circular(widget.radius);
    return Opacity(
      opacity: _busy ? .6 : 1,
      child: Material(
        color: on ? Colors.transparent : (dark ? Dak.cta : Hex.text),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: on ? BorderSide(color: dark ? Dak.border : Hex.text) : BorderSide.none,
        ),
        child: InkWell(
          onTap: _busy ? null : _toggle,
          borderRadius: radius,
          child: Container(
            width: widget.width,
            height: widget.height,
            padding: EdgeInsets.symmetric(horizontal: widget.padding),
            child: Center(
              widthFactor: 1,
              child: Text(
                on ? widget.labels.$2 : widget.labels.$1,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w500,
                  color: on ? (dark ? Dak.heading : Hex.text) : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Creates a canvas and opens it in the editor. Without a workspace it lands in the user's most
/// recently used workspace (or a new personal one).
class CreateCanvasButton extends ConsumerStatefulWidget {
  const CreateCanvasButton({super.key, required this.builder, this.workspaceId, this.folderId});

  final String? workspaceId;
  final String? folderId;
  final Widget Function(VoidCallback? onPressed) builder;

  @override
  ConsumerState<CreateCanvasButton> createState() => _CreateCanvasButtonState();
}

class _CreateCanvasButtonState extends ConsumerState<CreateCanvasButton> {
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final json = await ref.read(apiProvider).post<Map<String, dynamic>>('/canvases', {
        if (widget.workspaceId != null) 'workspaceId': widget.workspaceId,
        if (widget.folderId != null) 'folderId': widget.folderId,
      });
      if (mounted) context.go('/canvas/${CanvasCard.fromJson(json).id}');
    } catch (e) {
      ref.read(toastProvider.notifier).error(errorMessage(e));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Opacity(opacity: _busy ? .6 : 1, child: widget.builder(_busy ? null : _create));
}
