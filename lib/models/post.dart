import 'canvas.dart';
import 'user.dart';

class Post {
  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.tags,
    required this.visibility,
    required this.author,
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    required this.liked,
    required this.createdAt,
    required this.updatedAt,
    this.category,
    this.imageUrl,
    this.classroomId,
    this.canvas,
  });

  final String id;
  final String title;
  final String body;
  final String? category;
  final List<String> tags;
  final String? imageUrl;
  final Access visibility;
  final String? classroomId;
  final UserSummary author;
  final CanvasRef? canvas;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final bool liked;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String? ?? '',
    category: json['category'] as String?,
    tags: strings(json['tags']),
    imageUrl: json['imageUrl'] as String?,
    visibility: parseAccess(json['visibility']),
    classroomId: json['classroomId'] as String?,
    author: UserSummary.fromJson(json['author'] as Map<String, dynamic>),
    canvas: CanvasRef.fromJson(json['canvas']),
    likeCount: json['likeCount'] as int? ?? 0,
    commentCount: json['commentCount'] as int? ?? 0,
    viewCount: json['viewCount'] as int? ?? 0,
    liked: json['liked'] as bool? ?? false,
    createdAt: date(json['createdAt']),
    updatedAt: date(json['updatedAt']),
  );
}

class Comment {
  const Comment({required this.id, required this.body, required this.author, required this.isMine, required this.createdAt});

  final String id;
  final String body;
  final UserSummary author;
  final bool isMine;
  final DateTime createdAt;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String,
    body: json['body'] as String,
    author: UserSummary.fromJson(json['author'] as Map<String, dynamic>),
    isMine: json['isMine'] as bool? ?? false,
    createdAt: date(json['createdAt']),
  );
}
