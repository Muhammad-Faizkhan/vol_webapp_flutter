import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/canvas.dart';
import '../../models/notification.dart';
import '../../models/product.dart';
import '../../models/workspace.dart';
import '../../theme/tokens.dart';
import '../../ui/auto_grid.dart';
import '../../ui/card_box.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/link_text.dart';
import '../../ui/user_image.dart';
import '../shared/action_button.dart';
import '../shared/product_card.dart';
import '../shared/social.dart';
import '../shell/notification_item.dart';
import 'business_widgets.dart';

class BusinessHomePage extends ConsumerWidget {
  const BusinessHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final stats = ref.watch(query('/users/me/stats')).value as Map<String, dynamic>?;
    final canvases = pagedOf(ref, '/canvases/recent?limit=3', CanvasCard.fromJson);
    final products = pagedOf(ref, '/products/mine?limit=3', Product.fromJson);
    final workspaces = pagedOf(ref, '/workspaces?limit=4', Workspace.fromJson);
    final notes = pagedOf(ref, '/notifications?limit=2', AppNotification.fromJson);
    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;
    final border = dark ? Dak.border : Light.border;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${greeting()}, ${user?.name ?? ''}', style: businessTitle(context)),
        const SizedBox(height: 4),
        Text(
          user?.business?.verification == 'PENDING'
              ? 'Your business verification is under review. Here is your overview for today.'
              : 'Here is your overview for today.',
          style: businessSubtitle(context),
        ),
      ],
    );
    final canvasButton = CreateCanvasButton(
      builder: (onPressed) => ActionButton(color: Light.darkSurface, label: 'Create Canvas', onTap: onPressed),
    );
    final workspaceButton = ActionButton(color: Dak.cta, label: 'Create Workspace', onTap: () => context.go('/workspaces/create'));

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          alignEnd: true,
          title: Text('Recent Canvases', style: businessHeading(context)),
          trailing: canvases?.items.isNotEmpty == true
              ? TextLink(
                  'Open Last Canvas',
                  href: '/canvas/${canvases!.items.first.id}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Dak.cta),
                )
              : null,
        ),
        const SizedBox(height: 16),
        if (canvases?.items.isEmpty == true) ...[
          Text('Canvases you create or edit show up here.', style: context.emptyText),
          const SizedBox(height: 16),
        ],
        AutoGrid(minItemWidth: 280, children: canvasGrid(canvases?.items ?? const [])),
        const SizedBox(height: 32),
        SectionHeader(
          alignEnd: true,
          title: Text('Your Product Catalog', style: businessHeading(context)),
          trailing: const TextLink(
            'Open Catalog',
            href: '/business/dashboard',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Dak.cta),
          ),
        ),
        const SizedBox(height: 16),
        if (products?.items.isEmpty == true) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: LinkText(
              text: 'No products yet.',
              link: 'Add your first product',
              underline: false,
              textColor: context.pick(const Color(0xFF45464D), Dak.muted),
              onTap: () => context.go('/business/products/add'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        AutoGrid(
          minItemWidth: 240,
          gap: 24,
          children: [
            for (final p in products?.items ?? const <Product>[])
              ProductCard(
                href: '/business/products/${p.id}/edit',
                brand: p.brand ?? '—',
                name: p.name,
                specs: productSpecs(p),
                imageSrc: p.images.firstOrNull,
              ),
          ],
        ),
      ],
    );

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Notifications', style: businessHeading(context)),
        const SizedBox(height: 16),
        if (notes?.items.isEmpty == true) Text("You're all caught up.", style: context.emptyText),
        for (final n in notes?.items ?? const <AppNotification>[])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: NotificationItem(n: n),
          ),
        const SizedBox(height: 8),
        Text('Active Workspaces', style: businessHeading(context)),
        const SizedBox(height: 16),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: dark ? Dak.bg : const Color(0xFFE7E8E9),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'Active Workspaces (${workspaces?.total ?? 0})',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: .28, color: navy),
                ),
              ),
              ColoredBox(
                color: dark ? Dak.surface : const Color(0xFFF8F9FF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (workspaces?.items.isEmpty == true)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No workspaces yet.', style: context.emptyText),
                      ),
                    for (final (i, ws) in (workspaces?.items ?? const <Workspace>[]).indexed)
                      LinkBox(
                        href: '/workspaces/${ws.id}',
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: i == 0
                              ? null
                              : BoxDecoration(
                                  border: Border(top: BorderSide(color: border)),
                                ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(color: dark ? Dak.cta : Auth.navy, borderRadius: BorderRadius.circular(8)),
                                child: UserImage(src: ws.imageUrl, fallback: 'illustrations/canvas-thumb-mortar-pattern.jpg'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ws.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                                    ),
                                    Text(
                                      '${plural(ws.memberCount, 'member')} • Updated ${timeAgo(ws.lastActivityAt)}',
                                      style: TextStyle(fontSize: 12, color: dark ? Dak.muted : const Color(0xFF929292)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              LinkBox(
                href: '/workspaces',
                child: Container(
                  color: dark ? Dak.bg : const Color(0xFFF2F2F3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: Text(
                    'View All Workspaces',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (context.isSm)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: title),
              canvasButton,
              const SizedBox(width: 12),
              workspaceButton,
            ],
          )
        else ...[
          title,
          const SizedBox(height: 16),
          canvasButton,
          const SizedBox(height: 12),
          workspaceButton,
        ],
        const SizedBox(height: 32),
        BusinessStats(stats: stats),
        const SizedBox(height: 32),
        if (context.isLg)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: main),
              const SizedBox(width: 32),
              Expanded(child: side),
            ],
          )
        else ...[
          main,
          const SizedBox(height: 32),
          side,
        ],
      ],
    );
  }
}
