import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/notification.dart';
import '../../theme/tokens.dart';
import '../../ui/layout.dart';
import '../../ui/pill_button.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';

/// Where a notification leads when it has no inline actions.
(String href, String label)? _linkFor(AppNotification n) {
  final d = n.data;
  switch (n.type) {
    case 'WORKSPACE_JOIN_ACCEPTED':
      return d['workspaceId'] != null ? ('/workspaces/${d['workspaceId']}', 'Open Workspace') : null;
    case 'CLASSROOM_ENROLLED':
      return d['classroomId'] != null ? ('/classrooms/${d['classroomId']}', 'Open Classroom') : null;
    case 'POST_COMMENT' || 'POST_LIKE':
      if (d['classroomId'] != null) return ('/classrooms/${d['classroomId']}?tab=discussions', 'View Discussion');
      return d['postId'] != null ? ('/discover/post/${d['postId']}', 'View Post') : null;
    case 'NEW_FOLLOWER':
      return d['userId'] != null ? ('/profile/${d['userId']}', 'View Profile') : null;
    case 'WORKSPACE_INVITE' || 'WORKSPACE_JOIN_REQUEST':
      return n.resolved && d['workspaceId'] != null ? ('/workspaces/${d['workspaceId']}', 'Open Workspace') : null;
    default:
      return null;
  }
}

class NotificationItem extends ConsumerStatefulWidget {
  const NotificationItem({super.key, required this.n, this.compact = false, this.onDone});

  final AppNotification n;
  final bool compact;
  final VoidCallback? onDone;

  @override
  ConsumerState<NotificationItem> createState() => _NotificationItemState();
}

class _NotificationItemState extends ConsumerState<NotificationItem> {
  bool _busy = false;

  Future<void> _answer(bool accept) async {
    final n = widget.n;
    final api = ref.read(apiProvider);
    final toast = ref.read(toastProvider.notifier);
    setState(() => _busy = true);
    try {
      if (n.type == 'WORKSPACE_INVITE') {
        await api.post<dynamic>('/invites/${n.data['inviteId']}/${accept ? 'accept' : 'decline'}');
        toast.show(accept ? 'You joined the workspace' : 'Invitation declined');
        if (accept && mounted) context.go('/workspaces/${n.data['workspaceId']}');
      } else {
        await api.post<dynamic>('/join-requests/${n.data['requestId']}/${accept ? 'accept' : 'decline'}');
        toast.show(accept ? 'Request accepted' : 'Request declined');
      }
      invalidateQueries(ref);
      widget.onDone?.call();
    } catch (e) {
      toast.error(errorMessage(e));
      invalidateQueries(ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final n = widget.n;
    final compact = widget.compact;
    final actionable = !n.resolved && (n.type == 'WORKSPACE_INVITE' || n.type == 'WORKSPACE_JOIN_REQUEST');
    final link = _linkFor(n);

    final content = Row(
      crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Avatar(src: n.actor?.avatarUrl, name: n.actor?.name ?? 'VÔL', size: compact ? 36 : 40),
        SizedBox(width: compact ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 14, height: 16 / 14, letterSpacing: .28, color: dark ? Dak.body : Hex.text),
                  children: [
                    TextSpan(text: '${n.title} '),
                    TextSpan(
                      text: '· ${timeAgo(n.createdAt)}',
                      style: TextStyle(fontSize: 12, color: dark ? Dak.muted : const Color(0xFF9C9C9C)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                n.body,
                style: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, color: dark ? Dak.heading : Hex.black),
              ),
              if (actionable)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      PillButton(label: 'Accept', width: 80, onPressed: _busy ? null : () => _answer(true)),
                      const SizedBox(width: 8),
                      PillButton(label: 'Decline', width: 80, outline: true, onPressed: _busy ? null : () => _answer(false)),
                    ],
                  ),
                )
              else if (link != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: PillButton(
                    label: link.$2,
                    minWidth: 132,
                    onPressed: () {
                      widget.onDone?.call();
                      context.go(link.$1);
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (compact) {
      return Container(
        color: n.read ? null : Dak.cta.withValues(alpha: .05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: content,
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: dark ? Dak.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? Dak.border : Hex.text.withValues(alpha: .4)),
        boxShadow: [BoxShadow(color: Hex.text.withValues(alpha: .2), offset: const Offset(0, 4), blurRadius: 4)],
      ),
      child: content,
    );
  }
}
