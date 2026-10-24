import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/query.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/card_box.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/states.dart';
import '../../ui/user_image.dart';
import '../shared/canvas_picker.dart';
import '../shared/report_button.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _image = 0;

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(query('/products/${widget.productId}'));
    if (result.hasError) return ErrorState(error: result.error!);
    final json = result.value as Map<String, dynamic>?;
    if (json == null) return const SizedBox.shrink();
    final p = Product.fromJson(json);

    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;
    final border = dark ? Dak.border : Light.border;
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    String mm(num? v, [String unit = 'mm']) => v == null ? '—' : '${v == v.roundToDouble() ? v.round() : v} $unit';
    final specs = [
      ('True Size', p.size ?? '—'),
      ('Height / Thickness', mm(p.heightMm)),
      ('Width', mm(p.widthMm)),
      ('Length', mm(p.lengthMm)),
      ('Weight', mm(p.weightKg, 'kg')),
      ('Category', p.category ?? '—'),
      ('Trade', p.trade ?? '—'),
    ];

    final gallery = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: dark ? Dak.surface : Auth.navy,
              child: p.images.isNotEmpty
                  ? UserImage(src: p.images[_image.clamp(0, p.images.length - 1)])
                  : const Center(child: AssetIcon('illustrations/auth-placeholder.svg', width: 56, height: 56)),
            ),
          ),
        ),
        if (p.images.length > 1) ...[
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (i, src) in p.images.indexed)
                GestureDetector(
                  onTap: () => setState(() => _image = i),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: i == _image ? Dak.cta : Colors.transparent, width: 2),
                      ),
                      child: UserImage(src: src),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.brand != null) ...[
          Text(p.brand!.toUpperCase(), style: TextStyle(fontSize: 12, letterSpacing: .6, color: dark ? Dak.muted : Hex.text)),
          const SizedBox(height: 8),
        ],
        Text(
          p.name,
          style: TextStyle(fontSize: context.isSm ? 32 : 24, fontWeight: FontWeight.w700, color: navy),
        ),
        if (p.status != 'PUBLISHED') ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFBBC05).withValues(alpha: .2), borderRadius: BorderRadius.circular(4)),
              child: const Text(
                'Draft',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFA07800)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        LinkBox(
          href: '/business/${p.business.id}',
          child: Row(
            children: [
              Avatar(src: p.business.avatarUrl, name: p.business.name),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.business.name,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                  ),
                  Text('View business profile', style: TextStyle(fontSize: 12, color: grey)),
                ],
              ),
            ],
          ),
        ),
        if (p.description != null) ...[
          const SizedBox(height: 20),
          Text(p.description!, style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.slate)),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: dark ? Dak.surface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              for (final (i, (label, value)) in specs.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: i == 0
                      ? null
                      : BoxDecoration(
                          border: Border(top: BorderSide(color: border)),
                        ),
                  child: Row(
                    children: [
                      Text(label, style: TextStyle(fontSize: 14, color: context.body)),
                      const Spacer(),
                      Text(
                        value,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.ink),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Material(
              color: Dak.cta,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  if (p.isMine) return context.go('/business/products/${p.id}/edit');
                  final canvas = await pickCanvas(context, 'Place on which canvas?');
                  if (canvas != null && context.mounted) context.go('/canvas/${canvas.id}?addProduct=${p.id}');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    p.isMine ? 'Edit product' : 'Add to a canvas',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('Used on ${p.canvasCount} canvas${p.canvasCount == 1 ? '' : 'es'}', style: TextStyle(fontSize: 14, color: grey)),
            const Spacer(),
            if (!p.isMine)
              ReportButton(
                targetType: 'PRODUCT',
                targetId: p.id,
                style: TextStyle(fontSize: 14, color: grey),
              ),
          ],
        ),
      ],
    );

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => context.canPop() ? context.pop() : context.go('/products'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.flip(
                      flipX: true,
                      child: AssetIcon('icons/arrow-narrow-right.svg', width: 20, height: 20, color: dark ? Colors.white : null),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Back',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navy),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (context.isLg)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: gallery),
                  const SizedBox(width: 32),
                  Expanded(child: info),
                ],
              )
            else ...[
              gallery,
              const SizedBox(height: 32),
              info,
            ],
          ],
        ),
      ),
    );
  }
}
