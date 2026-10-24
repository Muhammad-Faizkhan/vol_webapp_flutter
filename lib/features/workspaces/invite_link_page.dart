import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/user.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/layout.dart';
import '../../ui/states.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';

/// Where a workspace invite link lands: preview the workspace and ask to join.
class InviteLinkPage extends ConsumerStatefulWidget {
  const InviteLinkPage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<InviteLinkPage> createState() => _InviteLinkPageState();
}

class _InviteLinkPageState extends ConsumerState<InviteLinkPage> {
  bool _busy = false;

  String get _path => '/invite-links/${widget.token}';

  Future<void> _request() async {
    setState(() => _busy = true);
    final toast = ref.read(toastProvider.notifier);
    try {
      await ref.read(apiProvider).post<dynamic>('$_path/request');
      ref.invalidate(query(_path));
      toast.show("Request sent. You'll be notified when an admin approves it.");
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(query(_path));
    if (result.hasError) return ErrorState(error: result.error!);
    final data = result.value as Map<String, dynamic>?;
    if (data == null) return const SizedBox.shrink();

    final dark = context.isDark;
    final ws = data['workspace'] as Map<String, dynamic>;
    final owner = UserSummary.fromJson(ws['owner'] as Map<String, dynamic>);
    final memberCount = ws['memberCount'] as int? ?? 0;
    final status = data['requestStatus'] as String?;
    final navy = dark ? Dak.heading : Auth.navy;
    final slate = dark ? Dak.body : Auth.slate;

    Widget wide(Widget child, {Color color = Dak.cta, VoidCallback? onTap}) => Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(child: child),
        ),
      ),
    );

    final Widget action;
    if (data['isMember'] == true) {
      action = wide(
        const Text(
          'Open workspace',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        onTap: () => context.go('/workspaces/${ws['id']}'),
      );
    } else if (status == 'PENDING') {
      action = wide(
        const Text(
          'Request sent · waiting for approval',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Dak.cta),
        ),
        color: dark ? Dak.cta.withValues(alpha: .1) : const Color(0xFFF3E8FF),
      );
    } else {
      action = Opacity(
        opacity: _busy ? .6 : 1,
        child: wide(
          Text(
            _busy ? 'Sending…' : (status == 'DECLINED' ? 'Ask again' : 'Request to join'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          onTap: _busy ? null : _request,
        ),
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: dark ? Dak.surface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? Dak.border : Light.border),
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: dark ? Dak.cta : Auth.navy, borderRadius: BorderRadius.circular(16)),
              child: ws['imageUrl'] != null
                  ? UserImage(src: ws['imageUrl'] as String)
                  : const Center(child: AssetIcon('illustrations/auth-placeholder.svg', width: 28, height: 28)),
            ),
            const SizedBox(height: 24),
            Text(
              "YOU'RE INVITED TO JOIN",
              style: TextStyle(fontSize: 14, letterSpacing: .7, color: dark ? Dak.muted : const Color(0xFF929292)),
            ),
            const SizedBox(height: 8),
            Text(
              ws['name'] as String,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: navy),
            ),
            if (ws['description'] != null) ...[
              const SizedBox(height: 8),
              Text(
                ws['description'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: slate),
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Avatar(src: owner.avatarUrl, name: owner.name, size: 28),
                Text(
                  'Owned by ${owner.name} · $memberCount member${memberCount == 1 ? '' : 's'} · joins as ${titleCase(data['role'] as String)}',
                  style: TextStyle(fontSize: 14, color: slate),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: action),
          ],
        ),
      ),
    );
  }
}
