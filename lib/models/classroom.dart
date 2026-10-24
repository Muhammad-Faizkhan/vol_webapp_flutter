import 'canvas.dart';
import 'user.dart';

class ClassroomCard {
  const ClassroomCard({
    required this.id,
    required this.title,
    required this.visibility,
    required this.status,
    required this.instructor,
    required this.moduleCount,
    required this.enrolledCount,
    required this.lessonCount,
    required this.completedLessons,
    required this.updatedAt,
    this.category,
    this.skillLevel,
    this.imageUrl,
    this.progress,
  });

  final String id;
  final String title;
  final String? category;
  final String? skillLevel;
  final String? imageUrl;
  final Access visibility;
  final String status;
  final UserSummary instructor;
  final int moduleCount;
  final int enrolledCount;
  final int lessonCount;
  final int completedLessons;
  final int? progress;
  final DateTime updatedAt;

  factory ClassroomCard.fromJson(Map<String, dynamic> json) => ClassroomCard(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String?,
    skillLevel: json['skillLevel'] as String?,
    imageUrl: json['imageUrl'] as String?,
    visibility: parseAccess(json['visibility']),
    status: json['status'] as String? ?? 'PUBLISHED',
    instructor: UserSummary.fromJson(json['instructor'] as Map<String, dynamic>),
    moduleCount: json['moduleCount'] as int? ?? 0,
    enrolledCount: json['enrolledCount'] as int? ?? 0,
    lessonCount: json['lessonCount'] as int? ?? 0,
    completedLessons: json['completedLessons'] as int? ?? 0,
    progress: (json['progress'] as num?)?.round(),
    updatedAt: date(json['updatedAt']),
  );
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.kind,
    required this.position,
    required this.completed,
    this.durationMinutes,
    this.body,
    this.resourceUrl,
    this.canvas,
  });

  final String id;
  final String title;
  final String kind;
  final int position;
  final int? durationMinutes;
  final String? body;
  final String? resourceUrl;
  final CanvasRef? canvas;
  final bool completed;

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    title: json['title'] as String,
    kind: json['kind'] as String,
    position: json['position'] as int? ?? 0,
    durationMinutes: json['durationMinutes'] as int?,
    body: json['body'] as String?,
    resourceUrl: json['resourceUrl'] as String?,
    canvas: CanvasRef.fromJson(json['canvas']),
    completed: json['completed'] as bool? ?? false,
  );
}

class ClassroomModule {
  const ClassroomModule({
    required this.id,
    required this.title,
    required this.position,
    required this.lessons,
    this.description,
    this.durationMinutes,
  });

  final String id;
  final String title;
  final String? description;
  final int position;
  final int? durationMinutes;
  final List<Lesson> lessons;

  factory ClassroomModule.fromJson(Map<String, dynamic> json) => ClassroomModule(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    position: json['position'] as int? ?? 0,
    durationMinutes: json['durationMinutes'] as int?,
    lessons: [for (final l in (json['lessons'] as List? ?? const [])) Lesson.fromJson(l as Map<String, dynamic>)],
  );
}

class ClassroomDetail extends ClassroomCard {
  const ClassroomDetail({
    required super.id,
    required super.title,
    required super.visibility,
    required super.status,
    required super.instructor,
    required super.moduleCount,
    required super.enrolledCount,
    required super.lessonCount,
    required super.completedLessons,
    required super.updatedAt,
    super.category,
    super.skillLevel,
    super.imageUrl,
    super.progress,
    required this.isInstructor,
    required this.isEnrolled,
    required this.discussionCount,
    required this.modules,
    this.description,
    this.targetAudience,
    this.durationLabel,
    this.joinCode,
    this.currentModuleId,
  });

  final String? description;
  final String? targetAudience;
  final String? durationLabel;
  final String? joinCode;
  final bool isInstructor;
  final bool isEnrolled;
  final int discussionCount;
  final String? currentModuleId;
  final List<ClassroomModule> modules;

  factory ClassroomDetail.fromJson(Map<String, dynamic> json) {
    final c = ClassroomCard.fromJson(json);
    return ClassroomDetail(
      id: c.id,
      title: c.title,
      visibility: c.visibility,
      status: c.status,
      instructor: c.instructor,
      moduleCount: c.moduleCount,
      enrolledCount: c.enrolledCount,
      lessonCount: c.lessonCount,
      completedLessons: c.completedLessons,
      updatedAt: c.updatedAt,
      category: c.category,
      skillLevel: c.skillLevel,
      imageUrl: c.imageUrl,
      progress: c.progress,
      description: json['description'] as String?,
      targetAudience: json['targetAudience'] as String?,
      durationLabel: json['durationLabel'] as String?,
      joinCode: json['joinCode'] as String?,
      isInstructor: json['isInstructor'] as bool? ?? false,
      isEnrolled: json['isEnrolled'] as bool? ?? false,
      discussionCount: json['discussionCount'] as int? ?? 0,
      currentModuleId: json['currentModuleId'] as String?,
      modules: [for (final m in (json['modules'] as List? ?? const [])) ClassroomModule.fromJson(m as Map<String, dynamic>)],
    );
  }
}

class Student extends UserSummary {
  const Student({
    required super.id,
    required super.name,
    required super.accountType,
    super.username,
    super.avatarUrl,
    super.specialty,
    super.verified,
    required this.status,
    required this.enrolledAt,
    required this.progress,
  });

  final String status;
  final DateTime enrolledAt;
  final int progress;

  factory Student.fromJson(Map<String, dynamic> json) {
    final s = UserSummary.fromJson(json);
    return Student(
      id: s.id,
      name: s.name,
      accountType: s.accountType,
      username: s.username,
      avatarUrl: s.avatarUrl,
      specialty: s.specialty,
      verified: s.verified,
      status: json['status'] as String? ?? 'ACTIVE',
      enrolledAt: date(json['enrolledAt']),
      progress: (json['progress'] as num?)?.round() ?? 0,
    );
  }
}
