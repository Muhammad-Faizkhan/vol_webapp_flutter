enum AccountType { individual, business }

enum Access { public, private }

Access parseAccess(Object? v) => v == 'PRIVATE' ? Access.private : Access.public;

String accessJson(Access v) => v == Access.private ? 'PRIVATE' : 'PUBLIC';

List<String> strings(Object? list) => (list as List?)?.cast<String>() ?? const [];

DateTime date(Object? v) => DateTime.parse(v as String);

DateTime? dateOrNull(Object? v) => v == null ? null : DateTime.parse(v as String);

class UserSummary {
  const UserSummary({
    required this.id,
    required this.name,
    required this.accountType,
    this.username,
    this.avatarUrl,
    this.specialty,
    this.verified = false,
  });

  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? specialty;
  final AccountType accountType;
  final bool verified;

  bool get isBusiness => accountType == AccountType.business;

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    username: json['username'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    specialty: json['specialty'] as String?,
    accountType: json['accountType'] == 'BUSINESS' ? AccountType.business : AccountType.individual,
    verified: json['verified'] as bool? ?? false,
  );
}

class PublicProfile extends UserSummary {
  const PublicProfile({
    required super.id,
    required super.name,
    required super.accountType,
    super.username,
    super.avatarUrl,
    super.specialty,
    super.verified,
    required this.isSelf,
    required this.isFollowing,
    required this.isPrivate,
    required this.joinedAt,
    required this.stats,
    this.bio,
    this.coverUrl,
    this.interests = const [],
    this.tags = const [],
    this.portfolioUrl,
    this.country,
    this.city,
    this.business,
  });

  final bool isSelf;
  final bool isFollowing;
  final bool isPrivate;
  final DateTime joinedAt;
  final Map<String, int> stats;
  final String? bio;
  final String? coverUrl;
  final List<String> interests;
  final List<String> tags;
  final String? portfolioUrl;
  final String? country;
  final String? city;
  final PublicBusiness? business;

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    final s = UserSummary.fromJson(json);
    final p = json['profile'] as Map<String, dynamic>?;
    final b = json['business'] as Map<String, dynamic>?;
    return PublicProfile(
      id: s.id,
      name: s.name,
      accountType: s.accountType,
      username: s.username,
      avatarUrl: s.avatarUrl,
      specialty: s.specialty,
      verified: s.verified,
      isSelf: json['isSelf'] as bool? ?? false,
      isFollowing: json['isFollowing'] as bool? ?? false,
      isPrivate: json['private'] as bool? ?? false,
      joinedAt: date(json['joinedAt']),
      stats: (json['stats'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt())),
      bio: p?['bio'] as String?,
      coverUrl: p?['coverUrl'] as String?,
      interests: strings(p?['interests']),
      tags: strings(p?['tags']),
      portfolioUrl: p?['portfolioUrl'] as String?,
      country: p?['country'] as String?,
      city: p?['city'] as String?,
      business: b == null ? null : PublicBusiness.fromJson(b),
    );
  }
}

class PublicBusiness {
  const PublicBusiness({
    required this.legalName,
    required this.categoryTags,
    required this.verification,
    this.description,
    this.logoUrl,
    this.coverUrl,
    this.industry,
    this.contactEmail,
    this.phone,
    this.website,
  });

  final String legalName;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final String? industry;
  final List<String> categoryTags;
  final String? contactEmail;
  final String? phone;
  final String? website;
  final String verification;

  factory PublicBusiness.fromJson(Map<String, dynamic> json) => PublicBusiness(
    legalName: json['legalName'] as String,
    description: json['description'] as String?,
    logoUrl: json['logoUrl'] as String?,
    coverUrl: json['coverUrl'] as String?,
    industry: json['industry'] as String?,
    categoryTags: strings(json['categoryTags']),
    contactEmail: json['contactEmail'] as String?,
    phone: json['phone'] as String?,
    website: json['website'] as String?,
    verification: json['verification'] as String? ?? 'UNVERIFIED',
  );
}

class PersonCard extends UserSummary {
  const PersonCard({
    required super.id,
    required super.name,
    required super.accountType,
    super.username,
    super.avatarUrl,
    super.specialty,
    super.verified,
    this.industry,
    this.bio,
    this.coverUrl,
    required this.followerCount,
    required this.productCount,
    required this.classroomCount,
    required this.workspaceCount,
    required this.isFollowing,
  });

  final String? industry;
  final String? bio;
  final String? coverUrl;
  final int followerCount;
  final int productCount;
  final int classroomCount;
  final int workspaceCount;
  final bool isFollowing;

  factory PersonCard.fromJson(Map<String, dynamic> json) {
    final s = UserSummary.fromJson(json);
    return PersonCard(
      id: s.id,
      name: s.name,
      accountType: s.accountType,
      username: s.username,
      avatarUrl: s.avatarUrl,
      specialty: s.specialty,
      verified: s.verified,
      industry: json['industry'] as String?,
      bio: json['bio'] as String?,
      coverUrl: json['coverUrl'] as String?,
      followerCount: json['followerCount'] as int? ?? 0,
      productCount: json['productCount'] as int? ?? 0,
      classroomCount: json['classroomCount'] as int? ?? 0,
      workspaceCount: json['workspaceCount'] as int? ?? 0,
      isFollowing: json['isFollowing'] as bool? ?? false,
    );
  }
}

String profileHref(UserSummary u) => u.isBusiness ? '/business/${u.id}' : '/profile/${u.id}';
