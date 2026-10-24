import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/query.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/auto_grid.dart';
import '../../ui/card_box.dart';
import '../../ui/layout.dart';
import '../../ui/states.dart';
import '../shared/product_card.dart';

const _sortOptions = [('relevance', 'Relevance'), ('newest', 'Newest'), ('name', 'Name (A–Z)')];

typedef _Facet = ({String value, int count});

List<_Facet> _facets(Object? list) => [
  for (final f in (list as List? ?? const [])) (value: (f as Map)['value'] as String, count: f['count'] as int),
];

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  List<String> _trades = [];
  List<String> _brands = [];
  String _sort = 'relevance';
  String _q = '';
  int _page = 1;

  void _toggle(List<String> list, void Function(List<String>) set, String option) => setState(() {
    set(list.contains(option) ? list.where((o) => o != option).toList() : [...list, option]);
    _page = 1;
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final facets = ref.watch(query('/products/facets')).value as Map<String, dynamic>?;
    final products = pagedOf(
      ref,
      withQuery('/products', {'trade': _trades, 'brand': _brands, 'sort': _sort, 'q': _q.trim(), 'page': _page, 'limit': 12}),
      Product.fromJson,
    );
    final line = dark ? Dak.border : Dak.line;
    final ink = context.ink;

    final groups = [
      ('Trade Specialization', _facets(facets?['trades']), _trades, (List<String> v) => _trades = v),
      ('Brand', _facets(facets?['brands']), _brands, (List<String> v) => _brands = v),
    ];

    final aside = Container(
      width: context.isLg ? 275 : double.infinity,
      constraints: BoxConstraints(minHeight: context.isLg ? 783 : 0),
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 17),
      decoration: cardDecoration(context, radius: 16, blur: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 25),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'FILTERS',
                    style: TextStyle(fontSize: 14, height: 1, fontWeight: FontWeight.w500, letterSpacing: .7, color: ink),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() {
                    _trades = [];
                    _brands = [];
                    _page = 1;
                  }),
                  child: Text(
                    'Clear All',
                    style: TextStyle(fontSize: 12, height: 1, fontWeight: FontWeight.w600, color: ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (final (i, (title, options, selected, set)) in groups.indexed) ...[
            if (i > 0) const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.only(bottom: 9),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: line)),
              ),
              child: Text(
                title,
                style: TextStyle(fontSize: 14, height: 1, fontWeight: FontWeight.w500, letterSpacing: .28, color: ink),
              ),
            ),
            const SizedBox(height: 12),
            if (options.isEmpty) Text('None yet', style: TextStyle(fontSize: 14, color: dark ? Dak.muted : const Color(0xFF929292))),
            for (final o in options)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _FilterCheckbox(
                  label: '${o.value} (${o.count})',
                  checked: selected.contains(o.value),
                  onChanged: () => _toggle(selected, set, o.value),
                ),
              ),
          ],
        ],
      ),
    );

    final search = SizedBox(
      width: context.isSm ? 240 : double.infinity,
      height: 40,
      child: TextField(
        onChanged: (v) => setState(() {
          _q = v;
          _page = 1;
        }),
        style: TextStyle(fontSize: 14, color: ink),
        decoration: InputDecoration(
          hintText: 'Search products or brands',
          hintStyle: TextStyle(fontSize: 14, color: dark ? Dak.muted : const Color(0xFF757575)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: _outline(dark),
          focusedBorder: _outline(dark),
        ),
      ),
    );
    final sort = Container(
      width: context.isSm ? 192 : double.infinity,
      height: 40,
      padding: const EdgeInsets.only(left: 13, right: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: dark ? Dak.border : Hex.text),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sort,
          isExpanded: true,
          icon: AssetIcon('icons/sort-chevron-down.svg', width: 21, height: 21, color: dark ? Colors.white : null),
          dropdownColor: dark ? Dak.surface : Colors.white,
          style: TextStyle(fontSize: 14, height: 20 / 14, color: ink),
          items: [for (final (v, l) in _sortOptions) DropdownMenuItem(value: v, child: Text('Sort by: $l'))],
          onChanged: (v) => setState(() {
            _sort = v ?? _sort;
            _page = 1;
          }),
        ),
      ),
    );

    final summary = Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 14, height: 20 / 14, color: context.body),
        children: [
          const TextSpan(text: 'Showing '),
          TextSpan(
            text: '${products?.total ?? '…'}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const TextSpan(text: ' products in '),
          TextSpan(
            text: _trades.isEmpty ? 'all trades' : _trades.join(', '),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    final results = Container(
      color: dark ? Colors.transparent : Colors.white,
      padding: EdgeInsets.only(left: context.isLg ? 32 : 0, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (context.isSm)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: summary),
                const SizedBox(width: 12),
                search,
                const SizedBox(width: 12),
                sort,
              ],
            )
          else ...[
            summary,
            const SizedBox(height: 12),
            search,
            const SizedBox(height: 12),
            sort,
          ],
          const SizedBox(height: 24),
          if (products == null)
            const LoadingGrid(minWidth: 280, height: 320)
          else if (products.items.isEmpty)
            const EmptyState(title: 'No products match', body: 'Try clearing some filters or searching for something else.')
          else
            AutoGrid(
              minItemWidth: 280,
              fill: true,
              children: [
                for (final p in products.items)
                  ProductCard(
                    href: '/products/${p.id}',
                    brand: p.brand ?? p.business.name,
                    name: p.name,
                    specs: productSpecs(p),
                    imageSrc: p.images.firstOrNull,
                  ),
              ],
            ),
          if (products != null) ...[
            const SizedBox(height: 24),
            Pager(page: products.page, pages: products.pages, onPage: (p) => setState(() => _page = p)),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Product Catalog', style: context.pageTitle),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 570),
            child: Text(
              'Browse and specify trade-accurate inventory, structural components, and finishing materials for your '
              'architectural canvases.',
              style: TextStyle(fontSize: 16, height: 1.5, color: dark ? Dak.body : Hex.black),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (context.isLg)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              aside,
              Expanded(child: results),
            ],
          )
        else ...[
          aside,
          const SizedBox(height: 24),
          results,
        ],
      ],
    );
  }

  OutlineInputBorder _outline(bool dark) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: dark ? Dak.border : Hex.text),
  );
}

class _FilterCheckbox extends StatelessWidget {
  const _FilterCheckbox({required this.label, required this.checked, required this.onChanged});

  final String label;
  final bool checked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onChanged,
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: checked ? (dark ? Dak.cta : Hex.black) : (dark ? Colors.transparent : Colors.white),
                borderRadius: BorderRadius.circular(2),
                border: checked ? null : Border.all(color: dark ? Dak.border : Hex.text),
              ),
              child: checked ? const AssetIcon('icons/checkbox-tick-white.svg', width: 16, height: 16) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: checked ? (dark ? Dak.heading : Hex.black) : (dark ? Dak.body : Hex.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
