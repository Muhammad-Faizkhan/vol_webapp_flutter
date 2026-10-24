import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/layout.dart';

typedef _NavItem = ({String href, String label, String icon});

const List<_NavItem> _individualNav = [
  (href: '/home', label: 'Home', icon: 'home'),
  (href: '/discover', label: 'Feed', icon: 'feed'),
  (href: '/workspaces', label: 'Workspaces', icon: 'workspaces'),
  (href: '/explore', label: 'Explore', icon: 'explore'),
  (href: '/classrooms', label: 'Classrooms', icon: 'classrooms'),
  (href: '/products', label: 'Products', icon: 'products'),
  (href: '/profile', label: 'Profile', icon: 'profile'),
];

// Business accounts get no Feed or Explore, and Products/Classrooms swap places (Figma 562:31634).
const List<_NavItem> _businessNav = [
  (href: '/business/home', label: 'Home', icon: 'home'),
  (href: '/workspaces', label: 'Workspaces', icon: 'workspaces'),
  (href: '/business/dashboard', label: 'Products', icon: 'products'),
  (href: '/classrooms', label: 'Classrooms', icon: 'classrooms'),
  (href: '/profile', label: 'Profile', icon: 'profile'),
];

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key, required this.location, this.onClose});

  final String location;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final items = user?.isBusiness == true ? _businessNav : _individualNav;
    final wide = context.isLg;
    final hPad = wide ? 20.0 : 16.0;

    Widget link(String href, String label, String icon, bool active) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? context.pick(Light.sidebarActive, Dak.cta) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            onClose?.call();
            context.go(href);
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: context.dvh(6, 1.2, 12)),
            child: Row(
              children: [
                AssetIcon('icons/nav/$icon.svg', width: 24, height: 24),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: .28, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Container(
      color: context.pick(Dak.cta, Dak.bg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 32 : 24, wide ? context.dvh(20, 4, 40) : context.dvh(16, 4, 32), wide ? 32 : 24, 0),
            child: Row(
              children: [
                SizedBox.square(dimension: context.dvh(48, 8, 80), child: const AssetIcon('illustrations/vol-logo.png')),
                const Spacer(),
                if (!wide)
                  IconButton(
                    tooltip: 'Close menu',
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
              ],
            ),
          ),
          SizedBox(height: context.dvh(16, 3, 32)),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              children: [
                for (final item in items)
                  link(item.href, item.label, item.icon, location == item.href || location.startsWith('${item.href}/')),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, context.dvh(8, 2, 16)),
            child: link('/settings', 'Settings', 'settings', location == '/settings'),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, context.dvh(12, 3, 24)),
            child: Material(
              color: context.pick(Colors.black.withValues(alpha: .2), Colors.white.withValues(alpha: .1)),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  onClose?.call();
                  await ref.read(apiProvider).logout();
                  if (context.mounted) context.go('/');
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: context.dvh(6, 1.2, 12)),
                  child: const Row(
                    children: [
                      AssetIcon('icons/nav/logout.svg', width: 24, height: 24),
                      SizedBox(width: 12),
                      Text(
                        'Logout',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: .28, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
