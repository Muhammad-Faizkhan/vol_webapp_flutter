import 'user.dart';

enum WorkspaceRole { owner, admin, collaborator, viewer }

WorkspaceRole parseRole(Object? v) => WorkspaceRole.values.byName((v as String).toLowerCase());

String roleJson(WorkspaceRole r) => r.name.toUpperCase();

class Member extends UserSummary {
  const Member({
    required super.id,
    required super.name,
    required super.accountType,
    super.username,
    super.avatarUrl,
    super.specialty,
    super.verified,
    required this.role,
  });

  final WorkspaceRole role;

  factory Member.fromJson(Map<String, dynamic> json) {
    final s = UserSummary.fromJson(json);
    return Member(
      id: s.id,
      name: s.name,
      accountType: s.accountType,
      username: s.username,
      avatarUrl: s.avatarUrl,
      specialty: s.specialty,
      verified: s.verified,
      role: parseRole(json['role']),
    );
  }
}

class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.visibility,
    required this.owner,
    required this.isOwner,
    required this.memberCount,
    required this.canvasCount,
    required this.productCount,
    required this.members,
    required this.createdAt,
    required this.lastActivityAt,
    this.description,
    this.industry,
    this.imageUrl,
    this.myRole,
  });

  final String id;
  final String name;
  final String? description;
  final String? industry;
  final String? imageUrl;
  final Access visibility;
  final UserSummary owner;
  final bool isOwner;
  final int memberCount;
  final int canvasCount;
  final int productCount;
  final List<Member> members;
  final DateTime createdAt;
  final DateTime lastActivityAt;
  // Only on the detail endpoint.
  final WorkspaceRole? myRole;

  bool get canManage => myRole == WorkspaceRole.owner || myRole == WorkspaceRole.admin;
  bool get canEdit => canManage || myRole == WorkspaceRole.collaborator;

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    industry: json['industry'] as String?,
    imageUrl: json['imageUrl'] as String?,
    visibility: parseAccess(json['visibility']),
    owner: UserSummary.fromJson(json['owner'] as Map<String, dynamic>),
    isOwner: json['isOwner'] as bool? ?? false,
    memberCount: json['memberCount'] as int? ?? 0,
    canvasCount: json['canvasCount'] as int? ?? 0,
    productCount: json['productCount'] as int? ?? 0,
    members: [for (final m in (json['members'] as List? ?? const [])) Member.fromJson(m as Map<String, dynamic>)],
    createdAt: date(json['createdAt']),
    lastActivityAt: date(json['lastActivityAt']),
    myRole: json['myRole'] == null ? null : parseRole(json['myRole']),
  );
}

class WorkspaceMember extends Member {
  const WorkspaceMember({
    required super.id,
    required super.name,
    required super.accountType,
    super.username,
    super.avatarUrl,
    super.specialty,
    super.verified,
    required super.role,
    required this.isYou,
    required this.joinedAt,
    this.email,
  });

  final String? email;
  final bool isYou;
  final DateTime joinedAt;

  factory WorkspaceMember.fromJson(Map<String, dynamic> json) {
    final m = Member.fromJson(json);
    return WorkspaceMember(
      id: m.id,
      name: m.name,
      accountType: m.accountType,
      username: m.username,
      avatarUrl: m.avatarUrl,
      specialty: m.specialty,
      verified: m.verified,
      role: m.role,
      email: json['email'] as String?,
      isYou: json['isYou'] as bool? ?? false,
      joinedAt: date(json['joinedAt']),
    );
  }
}

class PendingInvite {
  const PendingInvite({required this.id, required this.email, required this.role, required this.createdAt, this.expiresAt});

  final String id;
  final String email;
  final WorkspaceRole role;
  final DateTime createdAt;
  final DateTime? expiresAt;

  factory PendingInvite.fromJson(Map<String, dynamic> json) => PendingInvite(
    id: json['id'] as String,
    email: json['email'] as String,
    role: parseRole(json['role']),
    createdAt: date(json['createdAt']),
    expiresAt: dateOrNull(json['expiresAt']),
  );
}

class JoinRequest {
  const JoinRequest({required this.id, required this.user, required this.createdAt});

  final String id;
  final UserSummary user;
  final DateTime createdAt;

  factory JoinRequest.fromJson(Map<String, dynamic> json) => JoinRequest(
    id: json['id'] as String,
    user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
    createdAt: date(json['createdAt']),
  );
}

class Activity {
  const Activity({required this.id, required this.message, required this.createdAt, this.actor});

  final String id;
  final String message;
  final UserSummary? actor;
  final DateTime createdAt;

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    id: json['id'] as String,
    message: json['message'] as String,
    actor: json['actor'] == null ? null : UserSummary.fromJson(json['actor'] as Map<String, dynamic>),
    createdAt: date(json['createdAt']),
  );
}

class Folder {
  const Folder({required this.id, required this.name, required this.canvasCount});

  final String id;
  final String name;
  final int canvasCount;

  factory Folder.fromJson(Map<String, dynamic> json) =>
      Folder(id: json['id'] as String, name: json['name'] as String, canvasCount: json['canvasCount'] as int? ?? 0);
}
