class Paged<T> {
  const Paged({required this.items, required this.total, required this.page, required this.limit, required this.pages});

  final List<T> items;
  final int total;
  final int page;
  final int limit;
  final int pages;

  factory Paged.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) item) => Paged(
    items: (json['items'] as List).map((e) => item(e as Map<String, dynamic>)).toList(),
    total: json['total'] as int? ?? 0,
    page: json['page'] as int? ?? 1,
    limit: json['limit'] as int? ?? 0,
    pages: json['pages'] as int? ?? 1,
  );
}
