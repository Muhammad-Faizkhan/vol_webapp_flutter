import 'user.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.resolved,
    required this.createdAt,
    this.actor,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, String> data;
  final bool read;
  final bool resolved;
  final DateTime createdAt;
  final UserSummary? actor;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    type: json['type'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    data: (json['data'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
    read: json['read'] as bool? ?? false,
    resolved: json['resolved'] as bool? ?? false,
    createdAt: date(json['createdAt']),
    actor: json['actor'] == null ? null : UserSummary.fromJson(json['actor'] as Map<String, dynamic>),
  );
}
