import '../../models/user.dart';

class MyProfile {
  const MyProfile({
    required this.fullName,
    required this.interests,
    required this.tags,
    required this.visibility,
    required this.searchIndexing,
    required this.emailNotifications,
    this.avatarUrl,
    this.coverUrl,
    this.bio,
    this.specialty,
    this.portfolioUrl,
    this.phone,
    this.country,
    this.city,
  });

  final String fullName;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final String? specialty;
  final List<String> interests;
  final List<String> tags;
  final String? portfolioUrl;
  final String? phone;
  final String? country;
  final String? city;
  final Access visibility;
  final bool searchIndexing;
  final bool emailNotifications;

  factory MyProfile.fromJson(Map<String, dynamic> json) => MyProfile(
    fullName: json['fullName'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    coverUrl: json['coverUrl'] as String?,
    bio: json['bio'] as String?,
    specialty: json['specialty'] as String?,
    interests: strings(json['interests']),
    tags: strings(json['tags']),
    portfolioUrl: json['portfolioUrl'] as String?,
    phone: json['phone'] as String?,
    country: json['country'] as String?,
    city: json['city'] as String?,
    visibility: parseAccess(json['visibility']),
    searchIndexing: json['searchIndexing'] as bool? ?? true,
    emailNotifications: json['emailNotifications'] as bool? ?? true,
  );
}

class MyBusiness {
  const MyBusiness({
    required this.legalName,
    required this.categoryTags,
    required this.verification,
    this.contactEmail,
    this.phone,
    this.website,
    this.description,
    this.logoUrl,
    this.coverUrl,
    this.specialty,
    this.industry,
    this.verificationDocUrl,
  });

  final String legalName;
  final String? contactEmail;
  final String? phone;
  final String? website;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final String? specialty;
  final String? industry;
  final List<String> categoryTags;
  final String verification;
  final String? verificationDocUrl;

  factory MyBusiness.fromJson(Map<String, dynamic> json) => MyBusiness(
    legalName: json['legalName'] as String,
    contactEmail: json['contactEmail'] as String?,
    phone: json['phone'] as String?,
    website: json['website'] as String?,
    description: json['description'] as String?,
    logoUrl: json['logoUrl'] as String?,
    coverUrl: json['coverUrl'] as String?,
    specialty: json['specialty'] as String?,
    industry: json['industry'] as String?,
    categoryTags: strings(json['categoryTags']),
    verification: json['verification'] as String? ?? 'UNVERIFIED',
    verificationDocUrl: json['verificationDocUrl'] as String?,
  );
}

class Me extends UserSummary {
  const Me({
    required super.id,
    required super.name,
    required super.accountType,
    required this.displayId,
    required this.email,
    required this.role,
    required this.emailVerified,
    required this.onboarded,
    required this.createdAt,
    super.username,
    super.avatarUrl,
    super.specialty,
    super.verified,
    this.profile,
    this.business,
  });

  final String displayId;
  final String email;
  final String role;
  final bool emailVerified;
  final bool onboarded;
  final DateTime createdAt;
  final MyProfile? profile;
  final MyBusiness? business;

  bool get hasProfile => profile != null;
  bool get hasBusiness => business != null;

  factory Me.fromJson(Map<String, dynamic> json) {
    final summary = UserSummary.fromJson(json);
    return Me(
      id: summary.id,
      name: summary.name,
      username: summary.username,
      avatarUrl: summary.avatarUrl,
      specialty: summary.specialty,
      verified: summary.verified,
      accountType: summary.accountType,
      displayId: json['displayId'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      emailVerified: json['emailVerified'] as bool,
      onboarded: json['onboarded'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      profile: json['profile'] == null ? null : MyProfile.fromJson(json['profile'] as Map<String, dynamic>),
      business: json['business'] == null ? null : MyBusiness.fromJson(json['business'] as Map<String, dynamic>),
    );
  }
}

/// Where a signed-in user belongs, matching homeFor() in apps/web/src/lib/api.ts.
String homeFor(Me user) {
  final business = user.isBusiness;
  if (!user.onboarded) {
    final hasDetails = business ? user.hasBusiness : user.hasProfile;
    if (!hasDetails) return business ? '/create-profile?persona=business' : '/create-profile';
    return business ? '/network-visibility?persona=business' : '/network-visibility';
  }
  return business ? '/business/home' : '/home';
}
