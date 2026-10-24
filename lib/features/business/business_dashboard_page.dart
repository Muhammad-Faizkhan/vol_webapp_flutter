import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth.dart';
import '../../core/query.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../ui/auto_grid.dart';
import '../../ui/layout.dart';
import '../../ui/states.dart';
import '../shared/product_card.dart';
import 'business_widgets.dart';

const _filters = [(null, 'All'), ('PUBLISHED', 'Published'), ('DRAFT', 'Drafts')];

class BusinessDashboardPage extends ConsumerStatefulWidget {
  const BusinessDashboardPage({super.key});

  @override
  ConsumerState<BusinessDashboardPage> createState() => _BusinessDashboardPageState();
}

class _BusinessDashboardPageState extends ConsumerState<BusinessDashboardPage> {
  String? _status;
  String _q = '';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final stats = ref.watch(query('/users/me/stats')).value as Map<String, dynamic>?;
    final products = pagedOf(
      ref,
      withQuery('/products/mine', {'status': _status, 'q': _q.trim(), 'page': _page, 'limit': 12}),
      Product.fromJson,
    );
    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;
    final filtered = _q.isNotEmpty || _status != null;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome back, ${user?.name ?? ''}', style: businessTitle(context)),
        const SizedBox(height: 4),
        Text('Manage the products you share with the network.', style: businessSubtitle(context)),
      ],
    );
    final addButton = Material(
      color: Dak.cta,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go('/business/products/add'),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            '+ Add Product',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (context.isSm)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: heading),
              addButton,
            ],
          )
        else ...[
          heading,
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerLeft, child: addButton),
        ],
        const SizedBox(height: 24),
        BusinessStats(stats: stats),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Your Product Catalog', style: businessHeading(context)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (value, label) in _filters)
                  _FilterChip(
                    label: label,
                    selected: _status == value,
                    onTap: () => setState(() {
                      _status = value;
                      _page = 1;
                    }),
                  ),
                SizedBox(
                  width: 180,
                  height: 36,
                  child: TextField(
                    onChanged: (v) => setState(() {
                      _q = v;
                      _page = 1;
                    }),
                    style: TextStyle(fontSize: 14, color: navy),
                    decoration: InputDecoration(
                      hintText: 'Search products',
                      hintStyle: TextStyle(fontSize: 14, color: dark ? Dak.muted : const Color(0xFF757575)),
                      filled: true,
                      fillColor: dark ? Dak.surface : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      enabledBorder: _outline(dark),
                      focusedBorder: _outline(dark),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (products == null)
          const LoadingGrid(minWidth: 240, height: 300)
        else if (products.items.isEmpty)
          EmptyState(
            title: filtered ? 'No matching products' : 'Your catalog is empty',
            body: filtered ? null : 'Add products so people can place them on their canvases.',
            actionLabel: filtered ? null : '+ Add Product',
            actionHref: '/business/products/add',
          )
        else
          AutoGrid(
            minItemWidth: 240,
            gap: 24,
            fill: true,
            children: [
              for (final p in products.items)
                ProductCard(
                  href: '/business/products/${p.id}/edit',
                  brand: p.brand ?? '—',
                  name: p.name,
                  specs: productSpecs(p),
                  imageSrc: p.images.firstOrNull,
                ),
            ],
          ),
        if (products != null) ...[
          const SizedBox(height: 16),
          Pager(page: products.page, pages: products.pages, onPage: (p) => setState(() => _page = p)),
        ],
      ],
    );
  }

  OutlineInputBorder _outline(bool dark) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: dark ? Dak.border : Light.border),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Material(
      color: selected ? (dark ? Dak.cta : Light.darkSurface) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: selected ? BorderSide.none : BorderSide(color: dark ? Dak.border : Light.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(label, style: TextStyle(fontSize: 14, color: selected ? Colors.white : (dark ? Dak.heading : Auth.navy))),
        ),
      ),
    );
  }
}
