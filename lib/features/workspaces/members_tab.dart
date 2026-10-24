import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/user.dart';
import '../../models/workspace.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/layout.dart';
import '../../ui/page_bits.dart';
import '../../ui/small_select.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';

const _assignable = [WorkspaceRole.admin, WorkspaceRole.collaborator, WorkspaceRole.viewer];

class MembersTab extends ConsumerWidget {
  const MembersTab({super.key, required this.id, required this.ws});

  final String id;
  final Workspace? ws;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    final isAdmin = ws?.canManage ?? false;
    final isOwner = ws?.myRole == WorkspaceRole.owner;
    final members = listOf(ref, '/workspaces/$id/members', WorkspaceMember.fromJson);
    final requests = isAdmin ? listOf(ref, '/workspaces/$id/join-requests', JoinRequest.fromJson) : null;
    final invites = isAdmin ? listOf(ref, '/workspaces/$id/invites', PendingInvite.fromJson) : null;
    final api = ref.read(apiProvider);
    final navy = dark ? Dak.heading : Auth.navy;
    const grey = Color(0xFF929292);
    final border = dark ? Dak.border : Light.border;

    Future<void> run(Future<Object?> Function() action, String success) async {
      final toast = ref.read(toastProvider.notifier);
      try {
        await action();
        invalidateQueries(ref);
        toast.show(success);
      } catch (e) {
        toast.error(errorMessage(e));
      }
    }

    // Only the owner can promote to or demote from admin; admins manage collaborators and viewers.
    bool canEdit(WorkspaceMember m) => isAdmin && m.role != WorkspaceRole.owner && !m.isYou && (isOwner || m.role != WorkspaceRole.admin);

    Widget smallButton(String label, VoidCallback onTap, {bool filled = false}) => Material(
      color: filled ? Light.darkSurface : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: filled ? BorderSide.none : BorderSide(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(label, style: TextStyle(fontSize: 14, color: filled ? Colors.white : (dark ? Dak.heading : navy))),
        ),
      ),
    );

    Widget person(String? avatar, String name, String line) => SizedBox(
      width: 300,
      child: Row(
        children: [
          Avatar(src: avatar, name: name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                ),
                Text(
                  line,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: dark ? Dak.muted : grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final table = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final rows = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: Light.darkSurface,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 300,
                      child: Text('Member', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                    SizedBox(
                      width: 260,
                      child: Text('Profile Type', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                    Text('Action', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ],
                ),
              ),
              ColoredBox(
                color: dark ? Dak.surface : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, m) in (members ?? const <WorkspaceMember>[]).indexed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: i == 0
                            ? null
                            : BoxDecoration(
                                border: Border(top: BorderSide(color: border)),
                              ),
                        child: Row(
                          children: [
                            person(m.avatarUrl, m.name, m.isYou ? 'You' : (m.email ?? '')),
                            SizedBox(
                              width: 260,
                              child: Text(
                                m.specialty ?? titleCase(m.isBusiness ? 'BUSINESS' : 'INDIVIDUAL'),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 16, color: dark ? Dak.muted : grey),
                              ),
                            ),
                            if (canEdit(m)) ...[
                              SmallSelect<WorkspaceRole>(
                                value: m.role,
                                options: [
                                  for (final r in _assignable)
                                    if (isOwner || r != WorkspaceRole.admin) (r, titleCase(roleJson(r))),
                                ],
                                onChanged: (r) => run(
                                  () => api.patch<dynamic>('/workspaces/$id/members/${m.id}', {'role': roleJson(r)}),
                                  '${m.name} is now ${titleCase(roleJson(r))}',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Remove ${m.name}',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () async {
                                    if (await confirmAction(context, 'Remove ${m.name} from this workspace?')) {
                                      await run(() => api.delete<dynamic>('/workspaces/$id/members/${m.id}'), '${m.name} removed');
                                    }
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    child: Text('✕', style: TextStyle(fontSize: 14, color: grey)),
                                  ),
                                ),
                              ),
                            ] else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: m.role == WorkspaceRole.admin || m.role == WorkspaceRole.owner ? Light.darkSurface : null,
                                  borderRadius: BorderRadius.circular(8),
                                  border: m.role == WorkspaceRole.admin || m.role == WorkspaceRole.owner ? null : Border.all(color: border),
                                ),
                                child: Text(
                                  titleCase(roleJson(m.role)),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: m.role == WorkspaceRole.admin || m.role == WorkspaceRole.owner
                                        ? Colors.white
                                        : (dark ? Dak.heading : grey),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    for (final invite in invites ?? const <PendingInvite>[])
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: border)),
                        ),
                        child: Row(
                          children: [
                            person(null, invite.email, 'Invited ${timeAgo(invite.createdAt)}'),
                            SizedBox(
                              width: 260,
                              child: Text(
                                'Pending · ${titleCase(roleJson(invite.role))}',
                                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: dark ? Dak.muted : grey),
                              ),
                            ),
                            smallButton(
                              'Cancel invite',
                              () => run(() => api.delete<dynamic>('/workspaces/$id/invites/${invite.id}'), 'Invite cancelled'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
          return c.maxWidth >= 640
              ? rows
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: 760, child: rows),
                );
        },
      ),
    );

    Widget visibilityOption(Access value, String icon, double w, double h, String title, String body) {
      final checked = ws?.visibility == value;
      return Opacity(
        opacity: isAdmin ? 1 : .7,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: !isAdmin || checked
              ? null
              : () => run(
                  () => api.patch<dynamic>('/workspaces/$id', {'visibility': accessJson(value)}),
                  value == Access.public ? 'Workspace is now public' : 'Workspace is now private',
                ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: checked ? (dark ? Dak.line : Auth.navy) : border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: checked ? (dark ? Dak.cta : Auth.navy) : Colors.white,
                      border: Border.all(color: checked ? (dark ? Dak.cta : Auth.navy) : const Color(0xFF767676)),
                    ),
                    child: checked
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AssetIcon(icon, width: w, height: h, color: dark ? Colors.white : Colors.black),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: .28, color: navy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(body, style: TextStyle(fontSize: 14, color: dark ? Dak.body : const Color(0xFF45464D))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isAdmin && (requests?.isNotEmpty ?? false)) ...[
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Dak.cta),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: Dak.cta,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text('Join requests (${requests!.length})', style: const TextStyle(fontSize: 16, color: Colors.white)),
                ),
                ColoredBox(
                  color: dark ? Dak.surface : Colors.white,
                  child: Column(
                    children: [
                      for (final (i, r) in requests.indexed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: i == 0
                              ? null
                              : BoxDecoration(
                                  border: Border(top: BorderSide(color: border)),
                                ),
                          child: Row(
                            children: [
                              Avatar(src: r.user.avatarUrl, name: r.user.name),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.user.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                                    ),
                                    Text('Asked ${timeAgo(r.createdAt)}', style: TextStyle(fontSize: 12, color: dark ? Dak.muted : grey)),
                                  ],
                                ),
                              ),
                              smallButton(
                                'Accept',
                                () => run(() => api.post<dynamic>('/join-requests/${r.id}/accept'), '${r.user.name} added'),
                                filled: true,
                              ),
                              const SizedBox(width: 12),
                              smallButton(
                                'Decline',
                                () => run(() => api.post<dynamic>('/join-requests/${r.id}/decline'), 'Request declined'),
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
          const SizedBox(height: 32),
        ],
        table,
        const SizedBox(height: 32),
        Align(
          alignment: Alignment.topLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 463),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: dark ? Dak.surface : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
              boxShadow: const [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 1)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Visibility',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: navy),
                ),
                const SizedBox(height: 24),
                visibilityOption(
                  Access.public,
                  'icons/globe.svg',
                  17,
                  17,
                  'Public to explore',
                  'Your profile, projects, and credentials will be visible to all platform users.',
                ),
                const SizedBox(height: 24),
                visibilityOption(
                  Access.private,
                  'icons/lock-small.svg',
                  14,
                  18,
                  'Private to members',
                  'You can only collaborate via direct invites from existing workspaces or verified connections.',
                ),
                if (!isAdmin) ...[
                  const SizedBox(height: 16),
                  Text('Only workspace admins can change visibility.', style: TextStyle(fontSize: 14, color: dark ? Dak.muted : grey)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
