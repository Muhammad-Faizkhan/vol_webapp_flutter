import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/workspace.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/auto_grid.dart';
import '../../ui/layout.dart';
import '../../ui/states.dart';
import '../shared/action_button.dart';
import '../shared/social.dart';
import '../shared/workspace_card.dart';

class WorkspacesPage extends ConsumerStatefulWidget {
  const WorkspacesPage({super.key});

  @override
  ConsumerState<WorkspacesPage> createState() => _WorkspacesPageState();
}

class _WorkspacesPageState extends ConsumerState<WorkspacesPage> {
  String _tab = 'mine';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final path = withQuery('/workspaces', {'scope': _tab, 'page': _page, 'limit': 12});
    final result = ref.watch(query(path));
    final data = result.value == null ? null : pagedOf(ref, path, Workspace.fromJson);
    final total = data?.total;
    final mine = _tab == 'mine';
    final navy = dark ? Dak.heading : Auth.navy;

    final heading = Row(
      children: [
        Container(
          width: context.isSm ? 80 : 64,
          height: context.isSm ? 80 : 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: dark ? Dak.border : Auth.navy),
          ),
          child: const AssetIcon('illustrations/classroom-thumb-engineers.jpg', fit: BoxFit.cover),
        ),
        SizedBox(width: context.isSm ? 24 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workspaces',
                style: TextStyle(fontSize: context.isSm ? 32 : 24, fontWeight: FontWeight.w700, letterSpacing: -.32, color: navy),
              ),
              SizedBox(height: context.isSm ? 16 : 8),
              Text(
                total == null
                    ? 'Your projects, canvases and collaborators.'
                    : '$total ${mine ? 'workspace' : 'shared workspace'}${total == 1 ? '' : 's'} · projects, canvases and collaborators in one place.',
                style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.slate),
              ),
            ],
          ),
        ),
      ],
    );
    final canvasButton = CreateCanvasButton(
      builder: (onPressed) => ActionButton(
        color: Light.darkSurface,
        border: true,
        icon: const AssetIcon('icons/new-canvas-white.svg', width: 12, height: 15),
        label: 'Create Canvas',
        onTap: onPressed,
      ),
    );
    final workspaceButton = ActionButton(
      color: Dak.cta,
      icon: const AssetIcon('icons/new-workspace.svg', width: 16, height: 12),
      label: 'Create Workspace',
      onTap: () => context.go('/workspaces/create'),
    );

    Widget tab(String value, String label) {
      final on = _tab == value;
      return InkWell(
        onTap: () => setState(() {
          _tab = value;
          _page = 1;
        }),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: on ? navy : (dark ? Dak.muted : const Color(0xFF929292)),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: on ? (dark ? Dak.cta : Auth.navy) : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Widget body;
    if (result.hasError) {
      body = ErrorState(error: result.error!, onRetry: () => ref.invalidate(query(path)));
    } else if (data == null) {
      body = const LoadingGrid();
    } else if (data.items.isEmpty) {
      body = mine
          ? const EmptyState(
              title: 'No workspaces yet',
              body: 'Create a workspace to organise canvases and invite collaborators.',
              actionLabel: 'Create Workspace',
              actionHref: '/workspaces/create',
            )
          : const EmptyState(title: 'Nothing shared yet', body: 'Workspaces that businesses invite you to will appear here.');
    } else if (mine) {
      body = AutoGrid(
        minItemWidth: 260,
        gap: 24,
        fill: true,
        children: [
          for (final ws in data.items)
            WorkspaceCard(
              wide: false,
              showFooter: false,
              href: '/workspaces/${ws.id}',
              title: ws.name,
              meta:
                  '${ws.canvasCount} canvas${ws.canvasCount == 1 ? '' : 'es'} · ${ws.memberCount} member${ws.memberCount == 1 ? '' : 's'}',
              metaSecondary: 'Edited ${timeAgo(ws.lastActivityAt)} · ${ws.productCount} Product${ws.productCount == 1 ? '' : 's'}',
              collaboratorCount: ws.memberCount,
              updatedTag: updatedTag(ws.lastActivityAt),
              imageSrc: ws.imageUrl,
            ),
        ],
      );
    } else {
      body = AutoGrid(
        minItemWidth: 280,
        gap: 24,
        fill: true,
        children: [
          for (final ws in data.items)
            WorkspaceCard(
              href: '/workspaces/${ws.id}',
              title: ws.name,
              workspace: 'By ${ws.owner.name}',
              editedAgo: 'Edited ${timeAgo(ws.lastActivityAt)}',
              updatedTag: updatedTag(ws.lastActivityAt),
              collaborators: ws.members,
              collaboratorCount: ws.memberCount,
              imageSrc: ws.imageUrl,
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (context.isSm)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: heading),
              canvasButton,
              const SizedBox(width: 12),
              workspaceButton,
            ],
          )
        else ...[
          heading,
          const SizedBox(height: 16),
          canvasButton,
          const SizedBox(height: 12),
          workspaceButton,
        ],
        const SizedBox(height: 28),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: dark ? Dak.border : Light.border)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [tab('business', 'Add by Business Profiles'), const SizedBox(width: 24), tab('mine', 'My Workspaces')]),
          ),
        ),
        const SizedBox(height: 28),
        body,
        if (data != null) ...[
          const SizedBox(height: 28),
          Pager(page: data.page, pages: data.pages, onPage: (p) => setState(() => _page = p)),
        ],
      ],
    );
  }
}
