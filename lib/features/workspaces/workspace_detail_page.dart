import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/canvas.dart';
import '../../models/user.dart';
import '../../models/workspace.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/auto_grid.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/page_bits.dart';
import '../../ui/popover.dart';
import '../../ui/states.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';
import '../shared/action_button.dart';
import '../shared/product_card.dart';
import '../shared/social.dart';
import 'members_tab.dart';
import 'workspace_panels.dart';

const _tabs = [('canvases', 'Canvases'), ('files', 'Files'), ('members', 'Members & Roles')];

/// The workspace header and tab strip from (tabs)/layout.tsx, with the selected tab below.
class WorkspaceDetailPage extends ConsumerStatefulWidget {
  const WorkspaceDetailPage({super.key, required this.id, required this.tab});

  final String id;
  final String tab;

  @override
  ConsumerState<WorkspaceDetailPage> createState() => _WorkspaceDetailPageState();
}

class _WorkspaceDetailPageState extends ConsumerState<WorkspaceDetailPage> {
  bool _menu = false;

  Future<void> _leaveOrDelete(Workspace ws) async {
    setState(() => _menu = false);
    final owner = ws.myRole == WorkspaceRole.owner;
    final ok = await confirmAction(
      context,
      owner ? 'Delete "${ws.name}" and all its canvases? This can\'t be undone.' : 'Leave "${ws.name}"?',
    );
    if (!ok) return;
    final api = ref.read(apiProvider);
    final toast = ref.read(toastProvider.notifier);
    try {
      if (owner) {
        await api.delete<dynamic>('/workspaces/${ws.id}');
      } else {
        await api.delete<dynamic>('/workspaces/${ws.id}/members/${ref.read(authProvider)!.id}');
      }
      invalidateQueries(ref);
      toast.show(owner ? 'Workspace deleted' : 'You left the workspace');
      if (mounted) context.go('/workspaces');
    } catch (e) {
      toast.error(errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final path = '/workspaces/${widget.id}';
    final result = ref.watch(query(path));
    if (result.hasError) return ErrorState(error: result.error!, onRetry: () => ref.invalidate(query(path)));
    final ws = result.value == null ? null : Workspace.fromJson(result.value as Map<String, dynamic>);
    final navy = dark ? Dak.heading : Auth.navy;
    final canEdit = ws?.canEdit ?? false;
    final isAdmin = ws?.canManage ?? false;

    final title = Row(
      children: [
        Container(
          width: context.isSm ? 80 : 64,
          height: context.isSm ? 80 : 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: dark ? Dak.cta : Auth.navy, borderRadius: BorderRadius.circular(16)),
          child: ws?.imageUrl != null
              ? UserImage(src: ws!.imageUrl)
              : const Center(child: AssetIcon('illustrations/auth-placeholder.svg', width: 24, height: 24)),
        ),
        SizedBox(width: context.isSm ? 24 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ws?.name ?? ' ',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: context.isSm ? 32 : 24, fontWeight: FontWeight.w700, letterSpacing: -.32, color: navy),
              ),
              const SizedBox(height: 8),
              Text(
                ws == null
                    ? ' '
                    : [
                        plural(ws.canvasCount, 'canvas', 'canvases'),
                        plural(ws.memberCount, 'member'),
                        ws.visibility == Access.public ? 'public to explore' : 'private to members',
                        'last activity ${timeAgo(ws.lastActivityAt)}',
                      ].join(' · '),
                style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.slate),
              ),
            ],
          ),
        ),
      ],
    );

    final actions = <Widget>[
      if (canEdit)
        CreateCanvasButton(
          workspaceId: widget.id,
          builder: (onPressed) => ActionButton(
            color: Light.darkSurface,
            icon: const AssetIcon('icons/new-canvas.svg', width: 12, height: 15),
            label: 'Create Canvas',
            onTap: onPressed,
          ),
        ),
      if (isAdmin)
        ActionButton(
          color: Dak.cta,
          icon: const AssetIcon('icons/plus.svg', width: 24, height: 24),
          label: 'Invite Members',
          onTap: () => context.go('/workspaces/${widget.id}/invite'),
        ),
      if (ws?.myRole != null)
        Popover(
          open: _menu,
          onClose: () => setState(() => _menu = false),
          width: 192,
          panel: MenuCard(
            child: InkWell(
              onTap: () => _leaveOrDelete(ws),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  ws!.myRole == WorkspaceRole.owner ? 'Delete workspace' : 'Leave workspace',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Hex.error),
                ),
              ),
            ),
          ),
          child: Tooltip(
            message: 'Workspace options',
            child: Material(
              type: MaterialType.transparency,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: dark ? Dak.border : Light.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _menu = !_menu),
                child: SizedBox(
                  height: 56,
                  width: context.isSm ? null : double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      widthFactor: 1,
                      child: Text('⋯', style: TextStyle(fontSize: 20, color: navy)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];

    final tabBody = switch (widget.tab) {
      'files' => _FilesTab(id: widget.id, ws: ws),
      'members' => MembersTab(id: widget.id, ws: ws),
      _ => _CanvasesTab(id: widget.id, ws: ws),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BackLink(href: '/workspaces'),
        const SizedBox(height: 8),
        Text('Workspaces', style: TextStyle(fontSize: 18, color: dark ? Dak.body : Auth.navy)),
        const SizedBox(height: 24),
        if (context.isSm)
          Row(
            children: [
              Expanded(child: title),
              for (final (i, a) in actions.indexed) ...[if (i > 0) const SizedBox(width: 12), a],
            ],
          )
        else ...[
          title,
          for (final a in actions) ...[const SizedBox(height: 12), a],
        ],
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: dark ? Dak.border : Light.border)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, (href, label)) in _tabs.indexed) ...[
                  if (i > 0) const SizedBox(width: 32),
                  LinkBox(
                    href: '/workspaces/${widget.id}/$href',
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: widget.tab == href ? Border(bottom: BorderSide(color: dark ? Dak.cta : Auth.navy, width: 4)) : null,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: widget.tab == href ? navy : (dark ? Dak.muted : const Color(0xFF929292)),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        tabBody,
      ],
    );
  }
}

/// Main content plus the members/activity column on the right from [breakpoint] up.
Widget _withSide(BuildContext context, Workspace? ws, String id, Widget main, {double breakpoint = 1280, bool manageRoles = true}) {
  if (ws?.myRole == null) return main;
  final side = Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MembersPanel(workspaceId: id, myRole: ws!.myRole, showManageRoles: manageRoles),
      const SizedBox(height: 24),
      ActivityPanel(workspaceId: id),
    ],
  );
  if (context.screenWidth >= breakpoint) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: main),
        const SizedBox(width: 32),
        SizedBox(width: 360, child: side),
      ],
    );
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [main, const SizedBox(height: 32), side]);
}

class _CanvasesTab extends ConsumerWidget {
  const _CanvasesTab({required this.id, required this.ws});

  final String id;
  final Workspace? ws;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = pagedOf(ref, '/workspaces/$id/canvases?limit=100', CanvasCard.fromJson);
    final canEdit = ws?.canEdit ?? false;

    final Widget main;
    if (data == null) {
      main = const LoadingGrid(count: 4);
    } else if (data.items.isEmpty) {
      main = EmptyState(
        title: 'No canvases yet',
        body: canEdit ? 'Create the first canvas for this workspace.' : 'Canvases shared here will appear in this list.',
        action: canEdit
            ? CreateCanvasButton(
                workspaceId: id,
                builder: (onPressed) => Material(
                  color: Dak.cta,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onPressed,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text(
                        'Create Canvas',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      );
    } else {
      main = AutoGrid(minItemWidth: 260, gap: 24, fill: true, children: canvasGrid(data.items));
    }
    return _withSide(context, ws, id, main);
  }
}

class _FilesTab extends ConsumerStatefulWidget {
  const _FilesTab({required this.id, required this.ws});

  final String id;
  final Workspace? ws;

  @override
  ConsumerState<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<_FilesTab> {
  String? _folderId;
  final _newFolder = TextEditingController();
  final _newFolderFocus = FocusNode();
  bool _naming = false;

  @override
  void initState() {
    super.initState();
    _newFolderFocus.addListener(() {
      if (!_newFolderFocus.hasFocus && _naming) _createFolder();
    });
  }

  @override
  void dispose() {
    _newFolder.dispose();
    _newFolderFocus.dispose();
    super.dispose();
  }

  Future<void> _createFolder() async {
    final name = _newFolder.text.trim();
    setState(() => _naming = false);
    _newFolder.clear();
    if (name.isEmpty) return;
    try {
      await ref.read(apiProvider).post<dynamic>('/workspaces/${widget.id}/folders', {'name': name});
      invalidateQueries(ref);
    } catch (e) {
      ref.read(toastProvider.notifier).error(errorMessage(e));
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    if (!await confirmAction(context, 'Delete the folder "${folder.name}"? Its canvases stay in the workspace.')) return;
    try {
      await ref.read(apiProvider).delete<dynamic>('/workspaces/${widget.id}/folders/${folder.id}');
      if (_folderId == folder.id) setState(() => _folderId = null);
      invalidateQueries(ref);
    } catch (e) {
      ref.read(toastProvider.notifier).error(errorMessage(e));
    }
  }

  Future<void> _move(String canvasId, String target) async {
    final toast = ref.read(toastProvider.notifier);
    try {
      await ref.read(apiProvider).patch<dynamic>('/canvases/$canvasId', {'folderId': target.isEmpty ? null : target});
      invalidateQueries(ref);
      toast.show('Canvas moved');
    } catch (e) {
      toast.error(errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final id = widget.id;
    final canEdit = widget.ws?.canEdit ?? false;
    final foldersJson = ref.watch(query('/workspaces/$id/folders')).value as Map<String, dynamic>?;
    final folders = [for (final f in (foldersJson?['folders'] as List? ?? const [])) Folder.fromJson(f as Map<String, dynamic>)];
    final data = pagedOf(ref, withQuery('/workspaces/$id/canvases', {'folderId': _folderId, 'limit': 100}), CanvasCard.fromJson);
    final navy = dark ? Dak.heading : Auth.navy;

    final rows = [
      (id: null as String?, name: 'All Canvases', count: foldersJson?['total'] as int? ?? 0, folder: null as Folder?),
      for (final f in folders) (id: f.id, name: f.name, count: f.canvasCount, folder: f),
    ];

    final folderPanel = DarkTitledPanel(
      title: 'Folders',
      width: context.screenWidth >= 1536 ? 233 : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in rows)
              _FolderRow(
                name: row.name,
                count: row.count,
                selected: _folderId == row.id,
                onTap: () => setState(() => _folderId = row.id),
                onDelete: canEdit && row.folder != null ? () => _deleteFolder(row.folder!) : null,
              ),
            if (canEdit)
              _naming
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Dak.cta),
                        ),
                        child: TextField(
                          controller: _newFolder,
                          focusNode: _newFolderFocus,
                          autofocus: true,
                          onSubmitted: (_) => _createFolder(),
                          style: TextStyle(fontSize: 14, color: navy),
                          decoration: const InputDecoration.collapsed(hintText: 'Folder name'),
                        ),
                      ),
                    )
                  : InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _naming = true),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          '+ New folder',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Dak.cta),
                        ),
                      ),
                    ),
          ],
        ),
      ),
    );

    final Widget grid;
    if (data == null) {
      grid = const LoadingGrid(count: 4);
    } else if (data.items.isEmpty) {
      grid = EmptyState(title: 'This folder is empty', body: canEdit ? 'Move canvases here from All Canvases.' : null);
    } else {
      grid = AutoGrid(
        minItemWidth: 260,
        gap: 24,
        fill: true,
        children: canvasGrid(
          data.items,
          footer: canEdit && foldersJson != null
              ? (c) => Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: dark ? Dak.surface : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: dark ? Dak.border : Light.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: c.folderId ?? '',
                      isExpanded: true,
                      dropdownColor: dark ? Dak.surface : Colors.white,
                      style: TextStyle(fontSize: 14, color: navy),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('No folder')),
                        for (final f in folders) DropdownMenuItem(value: f.id, child: Text(f.name)),
                      ],
                      onChanged: (v) => _move(c.id, v ?? ''),
                    ),
                  ),
                )
              : null,
        ),
      );
    }

    final wide = context.screenWidth >= 1536;
    final ws = widget.ws;
    final side = ws?.myRole == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MembersPanel(workspaceId: id, myRole: ws!.myRole, showManageRoles: false),
              const SizedBox(height: 24),
              ActivityPanel(workspaceId: id),
            ],
          );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          folderPanel,
          const SizedBox(width: 24),
          Expanded(child: grid),
          if (side != null) ...[const SizedBox(width: 24), SizedBox(width: 360, child: side)],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        folderPanel,
        const SizedBox(height: 24),
        grid,
        if (side != null) ...[const SizedBox(height: 24), side],
      ],
    );
  }
}

class _FolderRow extends StatefulWidget {
  const _FolderRow({required this.name, required this.count, required this.selected, required this.onTap, this.onDelete});

  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  State<_FolderRow> createState() => _FolderRowState();
}

class _FolderRowState extends State<_FolderRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final color = widget.selected ? Colors.white : (dark ? Dak.heading : Auth.navy);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: widget.selected ? Light.darkSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: color),
                        ),
                      ),
                      Text('${widget.count}', style: TextStyle(fontSize: 14, color: color)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.onDelete != null) ...[
            const SizedBox(width: 4),
            Opacity(
              opacity: _hover ? 1 : 0,
              child: Tooltip(
                message: 'Delete folder ${widget.name}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: widget.onDelete,
                  child: const SizedBox.square(
                    dimension: 32,
                    child: Center(
                      child: Text('✕', style: TextStyle(color: Color(0xFF929292))),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
