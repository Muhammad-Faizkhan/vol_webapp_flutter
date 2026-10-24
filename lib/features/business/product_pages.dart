import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/query.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/button.dart';
import '../../ui/layout.dart';
import '../../ui/page_bits.dart';
import '../../ui/states.dart';
import '../../ui/text_field.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';
import 'business_widgets.dart';
import 'product_form.dart';

const _steps = ['Identity', 'Specs', 'Review'];

/// Rounded outline button used for Cancel / Publish / Save as draft.
class _OutlineAction extends StatelessWidget {
  const _OutlineAction({required this.label, required this.onTap, this.pill = true});

  final String label;
  final VoidCallback? onTap;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final radius = BorderRadius.circular(pill ? 999 : 16);
    return Opacity(
      opacity: onTap == null ? .6 : 1,
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: dark ? Dak.border : Light.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: dark ? Dak.heading : Auth.navy),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _footer(BuildContext context, List<Widget> children) {
  final dark = context.isDark;
  return Container(
    padding: const EdgeInsets.only(top: 24),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: dark ? Hex.text.withValues(alpha: .4) : Light.border)),
    ),
    child: Row(
      children: [
        for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(width: 16), c],
      ],
    ),
  );
}

const _arrow = AssetIcon('icons/arrow-right-small.svg', width: 12, height: 12);

class AddProductPage extends ConsumerStatefulWidget {
  const AddProductPage({super.key});

  @override
  ConsumerState<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends ConsumerState<AddProductPage> {
  // Coming back from the review step ("Edit") restores what was typed.
  late final ProductDraft _draft = ref.read(productDraftProvider).draft ?? ProductDraft();
  String? _error;

  void _next() {
    if (_draft.name.trim().isEmpty) return setState(() => _error = 'Give the product a name.');
    if (_draft.hasNegativeDimension) return setState(() => _error = "Dimensions can't be negative.");
    ref.read(productDraftProvider).draft = _draft;
    context.go('/business/products/add/review');
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BackLink(href: '/business/dashboard'),
            const SizedBox(height: 16),
            Text('Add New Product', style: businessTitle(context)),
            const SizedBox(height: 16),
            const StepTrack(steps: _steps, current: 0),
            const SizedBox(height: 16),
            ProductForm(
              value: _draft,
              onChanged: () {},
              error: _error,
              onError: (m) => setState(() => _error = m),
              footer: _footer(context, [
                _OutlineAction(
                  label: 'Cancel',
                  onTap: () {
                    ref.read(productDraftProvider).draft = null;
                    context.go('/business/dashboard');
                  },
                ),
                Expanded(
                  child: VolButton(label: 'Next Step', variant: ButtonVariant.cta, trailing: _arrow, onPressed: _next),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewProductPage extends ConsumerStatefulWidget {
  const ReviewProductPage({super.key});

  @override
  ConsumerState<ReviewProductPage> createState() => _ReviewProductPageState();
}

class _ReviewProductPageState extends ConsumerState<ReviewProductPage> {
  String? _saving;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (ref.read(productDraftProvider).draft == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/business/products/add'));
    }
  }

  Future<void> _save(ProductDraft draft, String status) async {
    setState(() {
      _saving = status;
      _error = null;
    });
    try {
      await ref.read(apiProvider).post<dynamic>('/products', {...draft.toBody(), 'status': status});
      ref.read(productDraftProvider).draft = null;
      invalidateQueries(ref);
      ref.read(toastProvider.notifier).show(status == 'PUBLISHED' ? 'Product published' : 'Draft saved');
      if (mounted) context.go('/business/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _saving = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.read(productDraftProvider).draft;
    if (draft == null) return const SizedBox.shrink();

    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;
    final border = dark ? Light.border.withValues(alpha: .4) : Light.border;
    String or(String v, [String unit = '']) => v.isEmpty ? '—' : '$v$unit';
    final dims = [
      ('Height', or(draft.heightMm, ' mm')),
      ('Width', or(draft.widthMm, ' mm')),
      ('Length', or(draft.lengthMm, ' mm')),
      ('Weight', or(draft.weightKg, ' kg')),
    ];
    final cover = draft.images.firstOrNull;
    final rest = draft.images.skip(1).toList();

    Widget card(String title, Widget child) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: dark ? Dak.surface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: navy),
                  ),
                ),
                InkWell(
                  onTap: () => context.go('/business/products/add'),
                  child: Row(
                    children: [
                      AssetIcon('icons/edit-pencil.svg', width: 12, height: 12, color: dark ? null : Colors.black),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: navy),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );

    Widget fieldView(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .3, color: dark ? Dak.muted : const Color(0xFF929292)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navy),
        ),
      ],
    );

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BackLink(href: '/business/products/add'),
            const SizedBox(height: 16),
            Text('Review & Publish', style: businessTitle(context)),
            const SizedBox(height: 16),
            Text('Verify all product details before committing to the catalog.', style: businessSubtitle(context)),
            const SizedBox(height: 16),
            const StepTrack(steps: _steps, current: 2),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 320,
                child: ColoredBox(
                  color: dark ? Dak.surface : Auth.navy,
                  child: cover != null
                      ? UserImage(src: cover)
                      : Center(
                          child: Text('No images added', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: .7))),
                        ),
                ),
              ),
            ),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final src in rest)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: UserImage(src: src),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            card(
              'Product Details',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: fieldView('Product Name', draft.name)),
                      Expanded(child: fieldView('Category', or(draft.category))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: fieldView('Brand', or(draft.brand))),
                      Expanded(child: fieldView('Trade', or(draft.trade))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SHORT DESCRIPTION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .3,
                      color: dark ? Dak.muted : const Color(0xFF929292),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(or(draft.description), style: TextStyle(fontSize: 14, color: navy)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            card(
              'Dimensional',
              GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 82,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final (label, value) in dims)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dark ? Dak.border : const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: dark ? Light.border.withValues(alpha: .3) : Light.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dark ? Dak.body : Auth.slate),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            value,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navy),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null) ...[const SizedBox(height: 16), ErrorText(_error!)],
            const SizedBox(height: 16),
            Flex(
              direction: context.isSm ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OutlineAction(
                  label: _saving == 'DRAFT' ? 'Saving…' : 'Save as draft',
                  pill: false,
                  onTap: _saving != null ? null : () => _save(draft, 'DRAFT'),
                ),
                SizedBox(width: 12, height: 12),
                Flexible(
                  fit: context.isSm ? FlexFit.tight : FlexFit.loose,
                  child: VolButton(
                    label: _saving == 'PUBLISHED' ? 'Publishing…' : 'Publish Product',
                    variant: ButtonVariant.cta,
                    trailing: _arrow,
                    onPressed: _saving != null ? null : () => _save(draft, 'PUBLISHED'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EditProductPage extends ConsumerWidget {
  const EditProductPage({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(query('/products/$productId'));
    if (result.hasError) return ErrorState(error: result.error!);
    final json = result.value as Map<String, dynamic>?;
    if (json == null) return const SizedBox.shrink();
    final product = Product.fromJson(json);
    if (!product.isMine) return ErrorState(error: ApiError(403, 'You can only edit your own products.'));
    return _Editor(key: ValueKey(product.id), product: product);
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final _draft = ProductDraft.fromProduct(widget.product);
  String? _error;
  bool _busy = false;

  Future<void> _save([String? status]) async {
    if (_draft.name.trim().isEmpty) return setState(() => _error = 'Give the product a name.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).patch<dynamic>('/products/${widget.product.id}', {..._draft.toBody(), 'status': ?status});
      invalidateQueries(ref);
      ref
          .read(toastProvider.notifier)
          .show(status == 'PUBLISHED' ? 'Product published' : (status == 'DRAFT' ? 'Product unpublished' : 'Changes saved'));
      if (mounted) context.go('/business/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _busy = false;
      });
    }
  }

  Future<void> _remove() async {
    if (!await confirmAction(context, 'Remove "${widget.product.name}" from your catalog?')) return;
    try {
      await ref.read(apiProvider).delete<dynamic>('/products/${widget.product.id}');
      invalidateQueries(ref);
      ref.read(toastProvider.notifier).show('Product removed');
      if (mounted) context.go('/business/dashboard');
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final published = p.status == 'PUBLISHED';
    final canvases = p.canvasCount > 0 ? ' · on ${p.canvasCount} canvas${p.canvasCount == 1 ? '' : 'es'}' : '';
    final dark = context.isDark;

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BackLink(href: '/business/dashboard'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Product', style: businessTitle(context)),
                    const SizedBox(height: 8),
                    Text(
                      '${published ? 'Published · visible in the catalog' : 'Draft · only you can see it'}$canvases',
                      style: businessSubtitle(context),
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: _remove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Hex.error,
                    side: BorderSide(color: dark ? Hex.error.withValues(alpha: .3) : const Color(0xFFFECACA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Remove product', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ProductForm(
              value: _draft,
              onChanged: () {},
              error: _error,
              onError: (m) => setState(() => _error = m),
              footer: _footer(context, [
                _OutlineAction(label: 'Cancel', onTap: () => context.go('/business/dashboard')),
                _OutlineAction(
                  label: published ? 'Unpublish' : 'Publish',
                  onTap: _busy ? null : () => _save(published ? 'DRAFT' : 'PUBLISHED'),
                ),
                Expanded(
                  child: VolButton(
                    label: _busy ? 'Saving…' : 'Save Changes',
                    variant: ButtonVariant.cta,
                    onPressed: _busy ? null : () => _save(),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
