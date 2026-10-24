import 'user.dart';
import 'workspace.dart';

class CanvasCard {
  const CanvasCard({
    required this.id,
    required this.title,
    required this.visibility,
    required this.workspaceId,
    required this.workspaceName,
    required this.collaboratorCount,
    required this.productCount,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.thumbnailUrl,
    this.folderId,
  });

  final String id;
  final String title;
  final String? thumbnailUrl;
  final Access visibility;
  final String? folderId;
  final String workspaceId;
  final String workspaceName;
  final int collaboratorCount;
  final int productCount;
  final UserSummary createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CanvasCard.fromJson(Map<String, dynamic> json) {
    final ws = json['workspace'] as Map<String, dynamic>;
    return CanvasCard(
      id: json['id'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      visibility: parseAccess(json['visibility']),
      folderId: json['folderId'] as String?,
      workspaceId: ws['id'] as String,
      workspaceName: ws['name'] as String,
      collaboratorCount: json['collaboratorCount'] as int? ?? 0,
      productCount: json['productCount'] as int? ?? 0,
      createdBy: UserSummary.fromJson(json['createdBy'] as Map<String, dynamic>),
      createdAt: date(json['createdAt']),
      updatedAt: date(json['updatedAt']),
    );
  }
}

class CanvasRef {
  const CanvasRef({required this.id, required this.title, this.thumbnailUrl});

  final String id;
  final String title;
  final String? thumbnailUrl;

  static CanvasRef? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return CanvasRef(id: json['id'] as String, title: json['title'] as String, thumbnailUrl: json['thumbnailUrl'] as String?);
  }
}

class CanvasProduct {
  const CanvasProduct({required this.id, required this.name, required this.business, this.brand, this.image});

  final String id;
  final String name;
  final String? brand;
  final String? image;
  final UserSummary business;

  factory CanvasProduct.fromJson(Map<String, dynamic> json) => CanvasProduct(
    id: json['id'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String?,
    image: json['image'] as String?,
    business: UserSummary.fromJson(json['business'] as Map<String, dynamic>),
  );
}

class CanvasDetail {
  const CanvasDetail({
    required this.card,
    required this.data,
    required this.canEdit,
    required this.autosaveSeconds,
    required this.products,
    this.myRole,
  });

  final CanvasCard card;
  final Map<String, dynamic> data;
  final WorkspaceRole? myRole;
  final bool canEdit;
  final int autosaveSeconds;
  final List<CanvasProduct> products;

  factory CanvasDetail.fromJson(Map<String, dynamic> json) => CanvasDetail(
    card: CanvasCard.fromJson(json),
    data: (json['data'] as Map<String, dynamic>?) ?? const {'objects': []},
    myRole: json['myRole'] == null ? null : parseRole(json['myRole']),
    canEdit: json['canEdit'] as bool? ?? false,
    autosaveSeconds: json['autosaveSeconds'] as int? ?? 30,
    products: [for (final p in (json['products'] as List? ?? const [])) CanvasProduct.fromJson(p as Map<String, dynamic>)],
  );
}
