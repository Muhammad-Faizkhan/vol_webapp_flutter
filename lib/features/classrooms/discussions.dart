import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/api/upload.dart';
import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/post.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/layout.dart';
import '../../ui/page_bits.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';
import '../shared/post_widgets.dart';
import '../shared/rich_text.dart';

/// Classroom discussion threads: start a thread, like it, reply under it.
class Discussions extends ConsumerStatefulWidget {
  const Discussions({super.key, required this.classroomId});

  final String classroomId;

  @override
  ConsumerState<Discussions> createState() => _DiscussionsState();
}

class _DiscussionsState extends ConsumerState<Discussions> {
  // null: the newest thread is open; '' : everything is closed.
  String? _openId;

  @override
  Widget build(BuildContext context) {
    final data = pagedOf(ref, '/classrooms/${widget.classroomId}/posts?limit=50', Post.fromJson);
    final items = data?.items ?? const <Post>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Composer(classroomId: widget.classroomId),
        if (data != null && items.isEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'No discussions yet — start the first one.',
            style: TextStyle(fontSize: 14, color: context.pick(const Color(0xFF45464D), Dak.muted)),
          ),
        ],
        for (final post in items) ...[
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final expanded = _openId == post.id || (_openId == null && items.first.id == post.id);
              return _Thread(
                key: ValueKey(post.id),
                post: post,
                expanded: expanded,
                onToggle: () => setState(() => _openId = expanded ? '' : post.id),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _Thread extends ConsumerWidget {
  const _Thread({super.key, required this.post, required this.expanded, required this.onToggle});

  final Post post;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    final border = dark ? Dak.border : Light.border;
    final grey = dark ? Dak.muted : const Color(0xFF45464D);
    final ink = dark ? Dak.heading : Hex.black;

    Future<void> remove() async {
      if (!await confirmAction(context, 'Delete this discussion?')) return;
      try {
        await ref.read(apiProvider).delete<dynamic>('/posts/${post.id}');
        invalidateQueries(ref);
      } catch (e) {
        ref.read(toastProvider.notifier).error(errorMessage(e));
      }
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? Dak.surface : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(src: post.author.avatarUrl, name: post.author.name),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.title,
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: ink),
                                ),
                                const SizedBox(height: 4),
                                Text.rich(
                                  TextSpan(
                                    style: TextStyle(fontSize: 14, color: grey),
                                    children: [
                                      TextSpan(
                                        text: post.author.name,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      TextSpan(text: '  • ${timeAgo(post.createdAt)}'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (post.author.id == ref.watch(authProvider)?.id)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: InkWell(
                                onTap: remove,
                                child: const Text('Delete', style: TextStyle(fontSize: 14, color: Color(0xFF929292))),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      PostText(post.body, style: TextStyle(fontSize: 16, color: dark ? Dak.body : Hex.text)),
                      if (post.imageUrl != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(height: 260, child: UserImage(src: post.imageUrl)),
                        ),
                      ],
                      if (post.tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in post.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: dark ? Dak.bg : const Color(0xFFF4F4F4),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dark ? Dak.heading : Hex.text),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      DefaultTextStyle.merge(
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ink),
                        child: Row(
                          children: [
                            LikeButton(postId: post.id, liked: post.liked, count: post.likeCount, size: 17),
                            const SizedBox(width: 24),
                            InkWell(
                              onTap: onToggle,
                              child: Row(
                                children: [
                                  AssetIcon('icons/comment-bubble.svg', width: 16.667, height: 16.667, color: dark ? Colors.white : null),
                                  const SizedBox(width: 4),
                                  Text('${post.commentCount} ${post.commentCount == 1 ? 'Reply' : 'Replies'}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (expanded)
            Container(
              color: dark ? Dak.bg : const Color(0xFFF8F8F8),
              padding: const EdgeInsets.all(24),
              child: CommentThread(postId: post.id, postAuthorId: post.author.id),
            ),
        ],
      ),
    );
  }
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer({required this.classroomId});

  final String classroomId;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _bodyFocus = FocusNode();
  String? _imageUrl;
  bool _busy = false;
  bool _uploading = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _format(Format kind) {
    _body.value = applyFormat(_body.value, kind);
    _bodyFocus.requestFocus();
    setState(() {});
  }

  Future<void> _insertLink() async {
    final url = (await promptText(context, 'Link URL (https://…)'))?.trim();
    if (url == null || url.isEmpty) return;
    final b = _body.text;
    setState(() => _body.text = '$b${b.isNotEmpty && !b.endsWith(' ') ? ' ' : ''}$url');
  }

  Future<void> _attachImage() async {
    final file = await pickFile(UploadKind.image);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await uploadFile(ref.read(apiProvider), file);
      setState(() => _imageUrl = url);
    } catch (e) {
      ref.read(toastProvider.notifier).error(errorMessage(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      return ref.read(toastProvider.notifier).error('Add a title and a message.');
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).post<dynamic>('/classrooms/${widget.classroomId}/posts', {
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'imageUrl': _imageUrl,
      });
      _title.clear();
      _body.clear();
      _imageUrl = null;
      invalidateQueries(ref);
    } catch (e) {
      ref.read(toastProvider.notifier).error(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final user = ref.watch(authProvider);
    final line = dark ? Dak.border : Hex.text.withValues(alpha: .4);
    final ink = dark ? Dak.heading : Hex.black;
    final surface = dark ? Dak.surface : Colors.white;
    final ready = !_busy && _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;

    Widget tool(String icon, String label, VoidCallback? onTap, double w, double h) => Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AssetIcon(icon, width: w, height: h, color: dark ? Colors.white : null),
        ),
      ),
    );
    Widget divider() => Container(width: 1, height: 16, color: dark ? Dak.border : Hex.text);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Avatar(src: user?.avatarUrl, name: user?.name ?? ''),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: dark ? Dak.bg : const Color(0xFFEAEAEA),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: dark ? Dak.border : Light.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: TextField(
                    controller: _title,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: ink),
                    decoration: const InputDecoration.collapsed(hintText: 'Discussion title'),
                  ),
                ),
                Container(height: 1, color: line),
                Container(
                  color: surface,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      tool('icons/format-bold.svg', 'Bold', () => _format(Format.bold), 7.8, 10.5),
                      const SizedBox(width: 8),
                      tool('icons/format-italic.svg', 'Italic', () => _format(Format.italic), 9.75, 10.5),
                      const SizedBox(width: 8),
                      divider(),
                      const SizedBox(width: 8),
                      tool('icons/format-list-bulleted.svg', 'Bulleted list', () => _format(Format.bulleted), 13.5, 12),
                      const SizedBox(width: 8),
                      tool('icons/format-list-numbered.svg', 'Numbered list', () => _format(Format.numbered), 13.5, 15),
                      const SizedBox(width: 8),
                      divider(),
                      const SizedBox(width: 8),
                      tool('icons/link.svg', 'Insert link', _insertLink, 16.667, 8.333),
                      const SizedBox(width: 8),
                      tool('icons/image-insert.svg', 'Insert image', _uploading ? null : _attachImage, 15, 15),
                      if (_imageUrl != null) ...[
                        const Spacer(),
                        Text('Image attached', style: TextStyle(fontSize: 12, color: dark ? Dak.muted : const Color(0xFF45464D))),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Remove image',
                          child: InkWell(
                            onTap: () => setState(() => _imageUrl = null),
                            child: Text('✕', style: TextStyle(fontSize: 12, color: ink)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(height: 1, color: line),
                Container(
                  constraints: const BoxConstraints(minHeight: 120),
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _body,
                    focusNode: _bodyFocus,
                    minLines: 4,
                    maxLines: null,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 16, color: ink),
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Start a discussion with your class...',
                      hintStyle: TextStyle(fontSize: 16, color: Color(0x8045464D)),
                    ),
                  ),
                ),
                Container(height: 1, color: line),
                Container(
                  color: surface,
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: ready ? 1 : .4,
                    child: Material(
                      color: dark ? Dak.cta : Hex.black,
                      borderRadius: BorderRadius.circular(4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: ready ? _submit : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          child: Text(
                            _busy ? 'Posting…' : 'Post Discussion',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
