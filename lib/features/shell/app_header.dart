import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth.dart';
import '../../core/query.dart';
import '../../models/notification.dart';
import '../../models/paged.dart';
import '../../theme/theme_mode.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/layout.dart';
import '../../ui/popover.dart';
import '../../ui/user_image.dart';
import 'notification_item.dart';

enum _Open { account, notifications, search }

const _grey = Color(0xFF6B7280);

class AppHeader extends ConsumerStatefulWidget {
  const AppHeader({super.key, this.onMenu});

  final VoidCallback? onMenu;

  @override
  ConsumerState<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends ConsumerState<AppHeader> {
  final _search = TextEditingController();
  _Open? _open;
  String _debounced = '';
  Timer? _debounce;
  Timer? _poll;

  static const _notesPath = '/notifications?limit=15';

  @override
  void initState() {
    super.initState();
    // Polled every minute so new invites show up without a reload.
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => ref.invalidate(query(_notesPath)));
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  void _close() => setState(() => _open = null);

  Future<void> _openNotifications(int unread) async {
    setState(() => _open = _open == _Open.notifications ? null : _Open.notifications);
    if (unread > 0) {
      await ref.read(apiProvider).post<dynamic>('/notifications/read');
      ref.invalidate(query(_notesPath));
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _open = _Open.search);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => setState(() => _debounced = value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final user = ref.watch(authProvider);
    final notesJson = ref.watch(query(_notesPath)).value as Map<String, dynamic>?;
    final notes = notesJson == null ? null : Paged.fromJson(notesJson, AppNotification.fromJson);
    final unread = notesJson?['unread'] as int? ?? 0;
    final wide = context.isLg;
    final navy = dark ? Dak.heading : Auth.navy;

    return Container(
      height: wide ? 100 : 80,
      padding: EdgeInsets.symmetric(horizontal: wide ? 40 : (context.isSm ? 24 : 16)),
      decoration: BoxDecoration(
        color: dark ? Dak.bg : Light.appBg,
        border: Border(bottom: BorderSide(color: dark ? Dak.border : Light.border)),
      ),
      child: Row(
        children: [
          if (!wide) ...[
            IconButton(
              tooltip: 'Open menu',
              onPressed: widget.onMenu,
              icon: Icon(Icons.menu, color: navy),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: Popover(
                  open: _open == _Open.search && _debounced.length >= 2,
                  onClose: _close,
                  alignRight: false,
                  matchWidth: true,
                  panel: _SearchResults(term: _debounced, onPick: _close),
                  child: _SearchField(
                    controller: _search,
                    onChanged: _onSearchChanged,
                    onTap: () => setState(() => _open = _Open.search),
                    onSubmitted: (v) {
                      _close();
                      if (v.trim().isNotEmpty) context.go(withQuery('/explore', {'q': v.trim()}));
                    },
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: context.isSm ? 16 : 8),
          _RoundButton(
            tooltip: 'Toggle theme',
            bordered: true,
            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
            child: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: dark ? 20 : 18, color: navy),
          ),
          SizedBox(width: context.isSm ? 16 : 8),
          Popover(
            open: _open == _Open.notifications,
            onClose: _close,
            width: (context.screenWidth - 32).clamp(0, 380),
            panel: MenuCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: dark ? Dak.border : Light.border)),
                    ),
                    child: Text(
                      'Notifications',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: navy),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: context.screenHeight * .6),
                    child: notes == null || notes.items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                            child: Text(
                              "You're all caught up.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: dark ? Dak.muted : _grey),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: notes.items.length,
                            separatorBuilder: (_, _) => Divider(height: 1, color: dark ? Dak.border : Light.border),
                            itemBuilder: (_, i) => NotificationItem(n: notes.items[i], compact: true, onDone: _close),
                          ),
                  ),
                ],
              ),
            ),
            child: _RoundButton(
              tooltip: unread > 0 ? 'Notifications ($unread unread)' : 'Notifications',
              onTap: () => _openNotifications(unread),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AssetIcon('icons/bell.svg', width: 16, height: 20, color: dark ? Colors.white : null),
                  if (unread > 0)
                    Positioned(
                      right: -10,
                      top: -8,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: Dak.cta, borderRadius: BorderRadius.circular(8)),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: context.isSm ? 16 : 8),
          Popover(
            open: _open == _Open.account,
            onClose: _close,
            width: 224,
            panel: MenuCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: dark ? Dak.border : Light.border)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: navy),
                        ),
                        Text(
                          user?.email ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: dark ? Dak.muted : _grey),
                        ),
                      ],
                    ),
                  ),
                  _MenuLink(label: 'Profile', onTap: () => _go('/profile')),
                  _MenuLink(label: 'Settings', onTap: () => _go('/settings')),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: dark ? Dak.border : Light.border)),
                    ),
                    child: _MenuLink(
                      label: 'Logout',
                      color: Hex.error,
                      bold: true,
                      onTap: () async {
                        _close();
                        await ref.read(apiProvider).logout();
                        if (context.mounted) context.go('/');
                      },
                    ),
                  ),
                ],
              ),
            ),
            child: Tooltip(
              message: 'Account menu',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _open = _open == _Open.account ? null : _Open.account),
                child: Avatar(src: user?.avatarUrl, name: user?.name ?? '', size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _go(String href) {
    _close();
    context.go(href);
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.tooltip, required this.onTap, required this.child, this.bordered = false});

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final shape = bordered
        ? CircleBorder(side: BorderSide(color: context.pick(Light.border, Dak.border)))
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox.square(dimension: 44, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _MenuLink extends StatelessWidget {
  const _MenuLink({required this.label, required this.onTap, this.color, this.bold = false});

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: context.pick(Auth.navy.withValues(alpha: .05), Colors.white.withValues(alpha: .05)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
            color: color ?? context.pick(Auth.navy, Dak.heading),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged, required this.onTap, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: dark ? Dak.border : Light.border),
    );
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTap: onTap,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 16, color: dark ? Dak.heading : Auth.navy),
        decoration: InputDecoration(
          hintText: 'Search workspaces, classrooms, peers...',
          hintStyle: TextStyle(fontSize: 16, color: dark ? Dak.muted : _grey),
          filled: true,
          fillColor: dark ? Dak.surface : const Color(0xFFFDFDFD),
          contentPadding: const EdgeInsets.only(right: 17),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 17, right: 9),
            child: AssetIcon('icons/search.svg', width: 15, height: 15, color: dark ? Colors.white : null),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.term, required this.onPick});

  final String term;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    final json = ref.watch(query(withQuery('/search', {'q': term}))).value as Map<String, dynamic>?;
    if (json == null) return const SizedBox.shrink();

    List<(String, String)> group(String key, String Function(Map<String, dynamic>) href, String label) => [
      for (final e in (json[key] as List).cast<Map<String, dynamic>>()) (href(e), e[label] as String),
    ];

    final groups = [
      ('People', group('people', (p) => p['accountType'] == 'BUSINESS' ? '/business/${p['id']}' : '/profile/${p['id']}', 'name')),
      ('Workspaces', group('workspaces', (w) => '/workspaces/${w['id']}', 'name')),
      ('Classrooms', group('classrooms', (c) => '/classrooms/${c['id']}', 'title')),
      ('Posts', group('posts', (p) => '/discover/post/${p['id']}', 'title')),
      ('Products', group('products', (p) => '/products/${p['id']}', 'name')),
    ].where((g) => g.$2.isNotEmpty).toList();

    return MenuCard(
      maxHeight: context.screenHeight * .7,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('No matches for “$term”.', style: TextStyle(fontSize: 14, color: dark ? Dak.muted : _grey)),
            ),
          for (final (title, items) in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .7, color: dark ? Dak.muted : _grey),
              ),
            ),
            for (final (href, label) in items)
              InkWell(
                onTap: () {
                  onPick();
                  context.go(href);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: dark ? Dak.heading : Auth.navy),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
