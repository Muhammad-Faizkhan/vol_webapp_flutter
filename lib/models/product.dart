import 'user.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.currency,
    required this.images,
    required this.status,
    required this.business,
    required this.canvasCount,
    required this.createdAt,
    required this.updatedAt,
    this.brand,
    this.category,
    this.trade,
    this.description,
    this.heightMm,
    this.widthMm,
    this.lengthMm,
    this.weightKg,
    this.price,
    this.size,
    this.isMine = false,
  });

  final String id;
  final String name;
  final String? brand;
  final String? category;
  final String? trade;
  final String? description;
  final num? heightMm;
  final num? widthMm;
  final num? lengthMm;
  final num? weightKg;
  final num? price;
  final String currency;
  final List<String> images;
  final String status;
  final String? size;
  final UserSummary business;
  final int canvasCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isMine;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String?,
    category: json['category'] as String?,
    trade: json['trade'] as String?,
    description: json['description'] as String?,
    heightMm: json['heightMm'] as num?,
    widthMm: json['widthMm'] as num?,
    lengthMm: json['lengthMm'] as num?,
    weightKg: json['weightKg'] as num?,
    price: json['price'] as num?,
    currency: json['currency'] as String? ?? 'USD',
    images: strings(json['images']),
    status: json['status'] as String? ?? 'PUBLISHED',
    size: json['size'] as String?,
    business: UserSummary.fromJson(json['business'] as Map<String, dynamic>),
    canvasCount: json['canvasCount'] as int? ?? 0,
    createdAt: date(json['createdAt']),
    updatedAt: date(json['updatedAt']),
    isMine: json['isMine'] as bool? ?? false,
  );
}

/// Spec rows shown on product cards, from productSpecs() in apps/web/src/lib/format.ts.
List<(String, String)> productSpecs(Product p) {
  final rows = <(String, String)>[];
  if (p.size != null && p.size!.isNotEmpty) rows.add(('True Size', p.size!));
  if (p.heightMm != null) rows.add(('Thickness', '${_num(p.heightMm!)} mm'));
  if (p.weightKg != null && rows.length < 2) rows.add(('Weight', '${_num(p.weightKg!)} kg'));
  if (p.trade != null && rows.length < 2) rows.add(('Trade', p.trade!));
  if (p.status != 'PUBLISHED') rows.add(('Status', 'Draft'));
  return rows.isEmpty ? [('Details', 'Not specified')] : rows;
}

String _num(num n) => n == n.roundToDouble() ? '${n.round()}' : '$n';
