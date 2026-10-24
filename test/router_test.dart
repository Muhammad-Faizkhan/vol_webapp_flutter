import 'package:flutter_test/flutter_test.dart';
import 'package:vol_web/core/auth/me.dart';
import 'package:vol_web/models/user.dart';
import 'package:vol_web/router.dart';

Me user({bool onboarded = true, bool business = false, bool hasDetails = true}) => Me(
  id: 'u1',
  displayId: 'VOL-1',
  email: 'a@b.co',
  name: 'Ana',
  accountType: business ? AccountType.business : AccountType.individual,
  role: 'USER',
  emailVerified: true,
  onboarded: onboarded,
  createdAt: DateTime(2026),
  profile: !business && hasDetails
      ? const MyProfile(fullName: 'Ana', interests: [], tags: [], visibility: Access.public, searchIndexing: true, emailNotifications: true)
      : null,
  business: business && hasDetails ? const MyBusiness(legalName: 'Acme', categoryTags: [], verification: 'UNVERIFIED') : null,
);

String? go(Me? me, String location) => redirectFor(me, Uri.parse(location));

void main() {
  test('signed-out visitors are sent to login and brought back', () {
    expect(go(null, '/workspaces'), '/login?next=%2Fworkspaces');
    expect(go(null, '/login'), isNull);
    expect(go(null, '/create-profile'), '/login');
  });

  test('signed-in users skip the landing and login screens', () {
    expect(go(user(), '/login'), '/home');
    expect(go(user(business: true), '/'), '/business/home');
  });

  test('unfinished onboarding always leads to the next step', () {
    expect(go(user(onboarded: false, hasDetails: false), '/home'), '/create-profile');
    expect(go(user(onboarded: false, business: true), '/home'), '/network-visibility?persona=business');
    expect(go(user(onboarded: false), '/network-visibility'), isNull);
    expect(go(user(), '/create-profile'), '/home');
  });

  test('policy pages open for everyone, invites need an account', () {
    expect(go(null, '/invite/abc'), '/login?next=%2Finvite%2Fabc');
    expect(go(user(onboarded: false), '/terms'), isNull);
  });
}
