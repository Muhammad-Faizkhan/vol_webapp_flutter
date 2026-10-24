import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/api/upload.dart';
import '../../core/auth/auth.dart';
import '../../core/query.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/drop_zone.dart';
import '../../ui/layout.dart';
import '../../ui/pale_input.dart';
import '../../ui/text_field.dart';
import '../../ui/user_image.dart';

const productCategories = ['Tiling', 'Flooring', 'Fasteners', 'Membranes', 'Adhesives', 'HVAC', 'Electrical', 'Plumbing', 'Structural'];
const productTrades = ['Tiling & Flooring', 'HVAC Systems', 'Electrical', 'Structural', 'Plumbing', 'Carpentry'];
const _maxImages = 4;

class ProductDraft {
  ProductDraft({
    this.name = '',
    this.brand = '',
    this.category = '',
    this.trade = '',
    this.description = '',
    this.heightMm = '',
    this.widthMm = '',
    this.lengthMm = '',
    this.weightKg = '',
    List<String>? images,
  }) : images = images ?? [];

  String name;
  String brand;
  String category;
  String trade;
  String description;
  String heightMm;
  String widthMm;
  String lengthMm;
  String weightKg;
  List<String> images;

  factory ProductDraft.fromProduct(Product p) {
    String n(num? v) => v == null ? '' : '$v';
    return ProductDraft(
      name: p.name,
      brand: p.brand ?? '',
      category: p.category ?? '',
      trade: p.trade ?? '',
      description: p.description ?? '',
      heightMm: n(p.heightMm),
      widthMm: n(p.widthMm),
      lengthMm: n(p.lengthMm),
      weightKg: n(p.weightKg),
      images: [...p.images],
    );
  }

  bool get hasNegativeDimension => [heightMm, widthMm, lengthMm, weightKg].any((v) => v.isNotEmpty && (num.tryParse(v) ?? 0) < 0);

  /// Request body for POST/PATCH /products. Empty fields are sent as "not set".
  Map<String, dynamic> toBody() {
    num? number(String v) => v.trim().isEmpty ? null : num.tryParse(v);
    String? text(String v) => v.trim().isEmpty ? null : v.trim();
    return {
      'name': name.trim(),
      'brand': ?text(brand),
      'category': ?text(category),
      'trade': ?text(trade),
      'description': ?text(description),
      'heightMm': number(heightMm),
      'widthMm': number(widthMm),
      'lengthMm': number(lengthMm),
      'weightKg': number(weightKg),
      'images': images,
    };
  }
}

/// The draft carried from "Add New Product" to "Review & Publish" (sessionStorage in apps/web).
final productDraftProvider = Provider((ref) => DraftSlot());

class DraftSlot {
  ProductDraft? draft;
}

/// Port of components/products/ProductForm.tsx. Edits [value] in place and calls [onChanged].
class ProductForm extends ConsumerStatefulWidget {
  const ProductForm({
    super.key,
    required this.value,
    required this.onChanged,
    required this.error,
    required this.onError,
    required this.footer,
  });

  final ProductDraft value;
  final VoidCallback onChanged;
  final String? error;
  final ValueChanged<String> onError;
  final Widget footer;

  @override
  ConsumerState<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductForm> {
  late final _name = TextEditingController(text: widget.value.name);
  late final _brand = TextEditingController(text: widget.value.brand);
  late final _description = TextEditingController(text: widget.value.description);
  late final _dims = {
    'heightMm': TextEditingController(text: widget.value.heightMm),
    'widthMm': TextEditingController(text: widget.value.widthMm),
    'lengthMm': TextEditingController(text: widget.value.lengthMm),
    'weightKg': TextEditingController(text: widget.value.weightKg),
  };
  bool _uploading = false;
  bool _dimError = false;

  @override
  void dispose() {
    for (final c in [_name, _brand, _description, ..._dims.values]) {
      c.dispose();
    }
    super.dispose();
  }

  ProductDraft get _d => widget.value;

  void _set(void Function(ProductDraft d) change) {
    setState(() => change(_d));
    widget.onChanged();
  }

  Future<void> _addFiles(List<PickedFile> files) async {
    final api = ref.read(apiProvider);
    final room = _maxImages - _d.images.length;
    setState(() => _uploading = true);
    final urls = <String>[];
    for (final file in files.take(room)) {
      try {
        urls.add(await uploadFile(api, file));
      } catch (e) {
        widget.onError(errorMessage(e));
      }
    }
    if (mounted) setState(() => _uploading = false);
    if (urls.isNotEmpty) _set((d) => d.images = [...d.images, ...urls]);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    final border = dark ? Dak.border : Light.border;
    final brands =
        ((ref.watch(query('/products/facets')).value as Map<String, dynamic>?)?['brands'] as List?)
            ?.map((b) => (b as Map)['value'] as String)
            .toList() ??
        const <String>[];

    final label = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy);
    Widget field(String text, Widget input) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text, style: label),
        const SizedBox(height: 8),
        input,
      ],
    );

    final category = field(
      'Product Category',
      _Select(
        value: _d.category,
        placeholder: 'Select Category',
        options: productCategories,
        onChanged: (v) => _set((d) => d.category = v),
      ),
    );
    final brand = field(
      'Brand / Manufacturer',
      Autocomplete<String>(
        optionsBuilder: (v) => brands.where((b) => b.toLowerCase().contains(v.text.toLowerCase())),
        fieldViewBuilder: (context, controller, focus, _) {
          if (controller.text.isEmpty && _brand.text.isNotEmpty) controller.text = _brand.text;
          return PaleInput(
            controller: controller,
            focusNode: focus,
            hint: 'Select or type a manufacturer',
            onChanged: (v) => _set((d) => d.brand = v),
          );
        },
        onSelected: (v) => _set((d) => d.brand = v),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_d.images.length < _maxImages) ...[
          DropZone(
            onTap: () async => _addFiles(await pickFiles(UploadKind.image, multiple: true)),
            onFile: (f) => _addFiles([f]),
            decoration: BoxDecoration(
              color: dark ? Dak.surface : const Color(0xFFDCDCDC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border, width: 2),
            ),
            child: SizedBox(
              height: 130,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AssetIcon('icons/new-canvas.svg', width: 24, height: 24, color: dark ? Colors.white : null),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 14, color: navy),
                      children: [
                        TextSpan(
                          text: _uploading ? 'Uploading…' : 'Upload image',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: ' or drag and drop',
                          style: TextStyle(color: grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('PNG, JPG up to 10MB · ${_d.images.length}/$_maxImages', style: TextStyle(fontSize: 12, color: grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (_d.images.isNotEmpty) ...[
          GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (i, src) in _d.images.indexed)
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      UserImage(src: src),
                      if (i == 0)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .6), borderRadius: BorderRadius.circular(4)),
                            child: const Text('Cover', style: TextStyle(fontSize: 10, color: Colors.white)),
                          ),
                        ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Tooltip(
                          message: 'Remove image',
                          child: InkWell(
                            onTap: () => _set((d) => d.images = d.images.where((x) => x != src).toList()),
                            child: Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: .6), shape: BoxShape.circle),
                              child: const Text('✕', style: TextStyle(fontSize: 14, color: Colors.white)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        field(
          'Product Name',
          PaleInput(controller: _name, hint: 'e.g. High-Capacity Chiller Unit TX-500', onChanged: (v) => _set((d) => d.name = v)),
        ),
        const SizedBox(height: 24),
        if (context.isSm)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: brand),
              const SizedBox(width: 16),
              Expanded(child: category),
            ],
          )
        else ...[
          brand,
          const SizedBox(height: 16),
          category,
        ],
        const SizedBox(height: 24),
        field(
          'Trade Specialization',
          _Select(
            value: _d.trade,
            placeholder: 'Select the trade this product serves',
            options: productTrades,
            onChanged: (v) => _set((d) => d.trade = v),
          ),
        ),
        const SizedBox(height: 24),
        field(
          'Short Description',
          PaleInput(
            controller: _description,
            hint: "Provide a brief overview of the product's primary function and application within the project context...",
            lines: 3,
            onChanged: (v) => _set((d) => d.description = v),
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
              Container(
                padding: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Text(
                  'Dimensions',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: navy),
                ),
              ),
              const SizedBox(height: 16),
              GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 76,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final (key, text, unit) in const [
                    ('heightMm', 'Overall Height', 'mm'),
                    ('widthMm', 'Overall Width', 'mm'),
                    ('lengthMm', 'Overall Length', 'mm'),
                    ('weightKg', 'Total Weight', 'kg'),
                  ])
                    field(
                      text,
                      PaleInput(
                        controller: _dims[key]!,
                        hint: '0.00',
                        height: 48,
                        suffix: unit,
                        number: true,
                        onChanged: (v) {
                          setState(() => _dimError = (num.tryParse(v) ?? 0) < 0);
                          _set((d) {
                            switch (key) {
                              case 'heightMm':
                                d.heightMm = v;
                              case 'widthMm':
                                d.widthMm = v;
                              case 'lengthMm':
                                d.lengthMm = v;
                              default:
                                d.weightKg = v;
                            }
                          });
                        },
                      ),
                    ),
                ],
              ),
              if (_dimError) ...[
                const SizedBox(height: 16),
                const Text("Dimensions can't be negative.", style: TextStyle(fontSize: 14, color: Hex.error)),
              ],
            ],
          ),
        ),
        if (widget.error != null) ...[const SizedBox(height: 24), ErrorText(widget.error!)],
        const SizedBox(height: 24),
        widget.footer,
      ],
    );
  }
}

class _Select extends StatelessWidget {
  const _Select({required this.value, required this.placeholder, required this.options, required this.onChanged});

  final String value;
  final String placeholder;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final all = value.isNotEmpty && !options.contains(value) ? [value, ...options] : options;
    final active = dark ? Dak.heading : Auth.navy;
    final grey = dark ? Dak.muted : const Color(0xFF929292);

    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 16, right: 16),
      decoration: BoxDecoration(
        color: dark ? Colors.transparent : const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dark ? Dak.border : Light.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: AssetIcon('icons/dropdown-arrow.svg', width: 20, height: 20, color: dark ? Colors.white : null),
          dropdownColor: dark ? Dak.surface : Colors.white,
          style: TextStyle(fontSize: 16, color: active),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(placeholder, style: TextStyle(color: grey)),
            ),
            for (final o in all) DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) => onChanged(v ?? ''),
        ),
      ),
    );
  }
}
