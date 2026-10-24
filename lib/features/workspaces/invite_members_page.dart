import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/workspace.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/button.dart';
import '../../ui/layout.dart';
import '../../ui/page_bits.dart';
import '../../ui/small_select.dart';
import '../../ui/text_field.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';
import 'workspace_panels.dart';

const _roleDefinitions = [
  ('Viewer', 'View only access to workspaces and assets.'),
  ('Collaborator', 'View and Edit capabilities for all active projects.'),
  ('Admin', 'Full management, user roles.'),
];

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class InviteMembersPage extends ConsumerStatefulWidget {
  const InviteMembersPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<InviteMembersPage> createState() => _InviteMembersPageState();
}

class _InviteMembersPageState extends ConsumerState<InviteMembersPage> {
  final _input = TextEditingController();
  final _pending = <(String, WorkspaceRole)>[];
  Map<String, dynamic>? _link;
  String? _error;
  bool _saving = false;
  bool _copied = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final value = _input.text.trim().toLowerCase();
    if (!_email.hasMatch(value)) return setState(() => _error = 'Enter a valid email address.');
    if (value == ref.read(authProvider)?.email) return setState(() => _error = "That's you — you're already in this workspace.");
    if (_pending.any((p) => p.$1 == value)) return setState(() => _error = 'Already in the list.');
    setState(() {
      _error = null;
      _pending.add((value, WorkspaceRole.collaborator));
      _input.clear();
    });
  }

  Future<void> _save() async {
    if (_pending.isEmpty) return setState(() => _error = 'Add at least one email address.');
    setState(() => _saving = true);
    try {
      final results = await ref.read(apiProvider).post<List<dynamic>>('/workspaces/${widget.id}/invites', {
        'invites': [
          for (final (email, role) in _pending) {'email': email, 'role': roleJson(role)},
        ],
      });
      final invited = results.where((r) => (r as Map)['status'] != 'already_member').length;
      final already = results.length - invited;
      ref
          .read(toastProvider.notifier)
          .show('$invited invite${invited == 1 ? '' : 's'} sent${already > 0 ? ' · $already already a member' : ''}');
      invalidateQueries(ref);
      if (mounted) context.go('/workspaces/${widget.id}/members');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _saving = false;
      });
    }
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    setState(() => _copied = true);
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _resetLink() async {
    if (!await confirmAction(context, 'Reset the link? The old link stops working.')) return;
    try {
      final link = await ref.read(apiProvider).post<Map<String, dynamic>>('/workspaces/${widget.id}/invite-link', {});
      setState(() => _link = link);
      ref.read(toastProvider.notifier).show('New invite link created');
    } catch (e) {
      ref.read(toastProvider.notifier).error(errorMessage(e));
    }
  }

  Future<void> _setLinkRole(WorkspaceRole role) async {
    try {
      final link = await ref.read(apiProvider).post<Map<String, dynamic>>('/workspaces/${widget.id}/invite-link', {'role': roleJson(role)});
      setState(() => _link = link);
    } catch (e) {
      ref.read(toastProvider.notifier).error(errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final user = ref.watch(authProvider);
    final ws = oneOf(ref, '/workspaces/${widget.id}', Workspace.fromJson);
    final isAdmin = ws?.canManage ?? false;
    final link = _link ?? (isAdmin ? ref.watch(query('/workspaces/${widget.id}/invite-link')).value as Map<String, dynamic>? : null);
    final navy = dark ? Dak.heading : Auth.navy;
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    final border = dark ? Dak.border : Light.border;
    final pale = dark ? Dak.bg : const Color(0xFFF2F2F3);

    if (ws != null && !isAdmin) {
      return Text('Only workspace admins can invite members.', style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.slate));
    }

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                padding: const EdgeInsets.only(left: 17, right: 16),
                decoration: BoxDecoration(
                  color: dark ? Colors.transparent : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    AssetIcon('icons/search.svg', width: 15, height: 15, color: dark ? Colors.white : null),
                    const SizedBox(width: 9),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        keyboardType: TextInputType.emailAddress,
                        onSubmitted: (_) => _add(),
                        style: TextStyle(fontSize: 16, color: navy),
                        decoration: InputDecoration.collapsed(
                          hintText: 'Add by email and press Enter',
                          hintStyle: TextStyle(fontSize: 16, color: grey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Light.darkSurface,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _add,
                child: const SizedBox(
                  height: 56,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Center(
                      widthFactor: 1,
                      child: Text('Add', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[const SizedBox(height: 12), ErrorText(_error!)],
        const SizedBox(height: 24),
        DarkTitledPanel(
          title: 'Selected Members (${_pending.length + 1})',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, (email, role)) in _pending.indexed)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: border)),
                  ),
                  child: Row(
                    children: [
                      Avatar(src: null, name: email),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                            ),
                            Text('Invitation', style: TextStyle(fontSize: 14, color: grey)),
                          ],
                        ),
                      ),
                      SmallSelect<WorkspaceRole>(
                        value: role,
                        fill: pale,
                        options: [
                          (WorkspaceRole.viewer, 'Viewer'),
                          (WorkspaceRole.collaborator, 'Collaborator'),
                          if (ws?.myRole == WorkspaceRole.owner) (WorkspaceRole.admin, 'Admin'),
                        ],
                        onChanged: (r) => setState(() => _pending[i] = (email, r)),
                      ),
                      const SizedBox(width: 12),
                      Tooltip(
                        message: 'Remove $email',
                        child: InkWell(
                          onTap: () => setState(() => _pending.removeAt(i)),
                          child: Text('✕', style: TextStyle(color: navy)),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Avatar(src: user?.avatarUrl, name: user?.name ?? ''),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                          ),
                          Text('You', style: TextStyle(fontSize: 14, color: grey)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: border),
                      ),
                      child: Text(ws?.myRole != null ? titleCase(roleJson(ws!.myRole!)) : '', style: TextStyle(fontSize: 14, color: navy)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: dark ? Dak.surface : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Invite via link',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navy),
                    ),
                  ),
                  if (link != null)
                    SmallSelect<WorkspaceRole>(
                      value: parseRole(link['role']),
                      height: 36,
                      fill: pale,
                      options: const [(WorkspaceRole.viewer, 'Joins as Viewer'), (WorkspaceRole.collaborator, 'Joins as Collaborator')],
                      onChanged: _setLinkRole,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Anyone with this link can request to join. You approve each request.', style: TextStyle(fontSize: 14, color: grey)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: dark ? Dak.bg : const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: border),
                      ),
                      child: SelectableText(
                        link?['url'] as String? ?? 'Loading…',
                        maxLines: 1,
                        style: TextStyle(fontSize: 14, color: navy),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Copy invite link',
                    child: Material(
                      color: pale,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: link == null ? null : () => _copy(link['url'] as String),
                        child: SizedBox.square(
                          dimension: 44,
                          child: Center(
                            child: _copied
                                ? Text('✓', style: TextStyle(color: navy))
                                : AssetIcon('icons/copy.svg', width: 16, height: 16, color: navy),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: _resetLink,
                  child: const Text(
                    'Reset link',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Dak.cta),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        VolButton(label: _saving ? 'Sending invites…' : 'Save Changes', variant: ButtonVariant.cta, onPressed: _saving ? null : _save),
      ],
    );

    final roles = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: dark ? Dak.surface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Role Definitions',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: navy),
          ),
          const SizedBox(height: 16),
          for (final (i, (role, desc)) in _roleDefinitions.indexed) ...[
            if (i > 0) const SizedBox(height: 16),
            Text(
              role,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: navy),
            ),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.slate)),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BackLink(href: '/workspaces/${widget.id}/members'),
        const SizedBox(height: 24),
        Text(
          'Invite Team Members',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -.32, color: navy),
        ),
        const SizedBox(height: 8),
        Text(
          'Add collaborators to ${ws?.name ?? 'your workspace'} and assign their permission levels.',
          style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.slate),
        ),
        const SizedBox(height: 24),
        if (context.screenWidth >= 1280)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: form),
              ),
              const SizedBox(width: 24),
              SizedBox(width: 400, child: roles),
            ],
          )
        else ...[
          form,
          const SizedBox(height: 24),
          roles,
        ],
      ],
    );
  }
}
