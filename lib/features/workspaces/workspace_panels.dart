import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/workspace.dart';
import '../../theme/tokens.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/user_image.dart';

/// Bordered panel with the dark title strip used beside workspace pages.
class DarkTitledPanel extends StatelessWidget {
  const DarkTitledPanel({super.key, required this.title, required this.child, this.width});

  final String title;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dark ? Dak.border : Light.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Light.darkSurface,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: .28, color: Colors.white),
            ),
          ),
          ColoredBox(color: dark ? Dak.surface : Colors.white, child: child),
        ],
      ),
    );
  }
}

class MembersPanel extends ConsumerWidget {
  const MembersPanel({super.key, required this.workspaceId, required this.myRole, this.showManageRoles = true});

  final String workspaceId;
  final WorkspaceRole? myRole;
  final bool showManageRoles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    final members = listOf(ref, '/workspaces/$workspaceId/members', WorkspaceMember.fromJson);
    final canManage = myRole == WorkspaceRole.owner || myRole == WorkspaceRole.admin;
    final navy = dark ? Dak.heading : Auth.navy;
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    final border = dark ? Dak.border : Light.border;

    return DarkTitledPanel(
      title: 'Members (${members?.length ?? '…'})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, m) in (members ?? const <WorkspaceMember>[]).take(6).indexed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: i == 0
                  ? null
                  : BoxDecoration(
                      border: Border(top: BorderSide(color: border)),
                    ),
              child: Row(
                children: [
                  Avatar(src: m.avatarUrl, name: m.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                        ),
                        Text(
                          m.isYou ? 'You' : (m.specialty ?? titleCase(m.isBusiness ? 'BUSINESS' : 'INDIVIDUAL')),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  RoleBadge(role: m.role),
                ],
              ),
            ),
          if (members != null && members.length > 6)
            LinkBox(
              href: '/workspaces/$workspaceId/members',
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: border)),
                ),
                child: Text(
                  '+${members.length - 6} more',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Dak.cta),
                ),
              ),
            ),
          if (showManageRoles && canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: LinkBox(
                href: '/workspaces/$workspaceId/members',
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Dak.cta,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Dak.cta.withValues(alpha: .4), offset: const Offset(0, 8), blurRadius: 16)],
                  ),
                  child: const Text(
                    'Manage Roles',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: .28, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dark pill for Owner/Admin, outlined for the other roles.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final WorkspaceRole role;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final strong = role == WorkspaceRole.admin || role == WorkspaceRole.owner;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: strong ? Light.darkSurface : null,
        borderRadius: BorderRadius.circular(8),
        border: strong ? null : Border.all(color: dark ? Dak.border : Light.border),
      ),
      child: Text(
        titleCase(roleJson(role)),
        style: TextStyle(fontSize: 14, color: strong ? Colors.white : (dark ? Dak.heading : Auth.navy)),
      ),
    );
  }
}

class ActivityPanel extends ConsumerStatefulWidget {
  const ActivityPanel({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState extends ConsumerState<ActivityPanel> {
  bool _expanded = false;
  String? _openId;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final activity = listOf(ref, '/workspaces/${widget.workspaceId}/activity?limit=${_expanded ? 50 : 3}', Activity.fromJson);
    final items = activity ?? const <Activity>[];
    final navy = dark ? Dak.heading : Auth.navy;
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    final border = dark ? Dak.border : Light.border;

    return DarkTitledPanel(
      title: 'Workspace Activity',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (activity != null && items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No activity yet.', style: TextStyle(fontSize: 14, color: grey)),
                ),
              for (final (i, item) in items.indexed)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: i == 0
                      ? null
                      : BoxDecoration(
                          border: Border(top: BorderSide(color: border)),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.actor?.name ?? 'Someone'} ${item.message}', style: TextStyle(fontSize: 14, color: navy)),
                                const SizedBox(height: 4),
                                Text(timeAgo(item.createdAt), style: TextStyle(fontSize: 12, color: grey)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Material(
                            color: Light.darkSurface,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setState(() => _openId = _openId == item.id ? null : item.id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Text(
                                  _openId == item.id ? 'Hide' : 'See details',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_openId == item.id) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: dark ? Dak.bg : const Color(0xFFF8F9FF), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            '${_localeString(item.createdAt)} · ${item.actor == null ? 'System' : '${item.actor!.name}${item.actor!.username != null ? ' (@${item.actor!.username})' : ''}'}',
                            style: TextStyle(fontSize: 12, color: dark ? Dak.body : const Color(0xFF45464D)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (!_expanded && items.length >= 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: OutlinedButton(
                    onPressed: () => setState(() => _expanded = true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navy,
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('See Full Audit Trail', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Date.toLocaleString() in en-US: "10/24/2026, 1:37:27 PM".
String _localeString(DateTime d) {
  final l = d.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.month}/${l.day}/${l.year}, $h:${two(l.minute)}:${two(l.second)} ${l.hour < 12 ? 'AM' : 'PM'}';
}
