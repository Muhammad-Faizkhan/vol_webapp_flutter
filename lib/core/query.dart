import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paged.dart';
import 'auth/auth.dart';

/// Cached GET responses keyed by path, the Flutter side of useApiQuery() in apps/web.
/// Screens watch `query('/workspaces')` and parse the JSON they get back.
final query = FutureProvider.autoDispose.family<dynamic, String>((ref, path) {
  return ref.watch(apiProvider).get<dynamic>(path);
});

/// Refetches every query on screen. The web app refetches by path prefix; with one family of
/// providers that is the same as refreshing whatever is currently mounted.
void invalidateQueries(WidgetRef ref) => ref.invalidate(query);

/// Builds "/path?a=1&b=2", skipping empty values and repeating lists (?trade=a&trade=b).
String withQuery(String path, Map<String, Object?> params) {
  final parts = <String>[];
  params.forEach((key, value) {
    if (value == null || value == '') return;
    final values = value is List ? value : [value];
    for (final v in values) {
      parts.add('${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent('$v')}');
    }
  });
  return parts.isEmpty ? path : '$path?${parts.join('&')}';
}

/// Watches a paged list endpoint and parses its items; null while loading.
Paged<T>? pagedOf<T>(WidgetRef ref, String path, T Function(Map<String, dynamic>) item) {
  final json = ref.watch(query(path)).value;
  return json == null ? null : Paged.fromJson(json as Map<String, dynamic>, item);
}

/// Watches an endpoint that returns a JSON array.
List<T>? listOf<T>(WidgetRef ref, String path, T Function(Map<String, dynamic>) item) {
  final json = ref.watch(query(path)).value as List?;
  return json?.map((e) => item(e as Map<String, dynamic>)).toList();
}

/// Watches an endpoint that returns one object.
T? oneOf<T>(WidgetRef ref, String path, T Function(Map<String, dynamic>) parse) {
  final json = ref.watch(query(path)).value;
  return json == null ? null : parse(json as Map<String, dynamic>);
}
