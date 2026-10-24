import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth.dart';
import 'core/auth/me.dart';
import 'features/auth/auth_flow.dart';
import 'features/business/business_dashboard_page.dart';
import 'features/canvas/canvas_page.dart';
import 'features/classrooms/classroom_page.dart';
import 'features/classrooms/classrooms_pages.dart';
import 'features/classrooms/create_classroom_pages.dart';
import 'features/business/business_home_page.dart';
import 'features/business/business_profile_page.dart';
import 'features/business/product_pages.dart';
import 'features/auth/forgot_password_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/otp_page.dart';
import 'features/auth/reset_password_page.dart';
import 'features/auth/signup_page.dart';
import 'features/auth/welcome_page.dart';
import 'features/discover/create_post_pages.dart';
import 'features/discover/discover_page.dart';
import 'features/discover/post_page.dart';
import 'features/explore/explore_page.dart';
import 'features/home/home_page.dart';
import 'features/onboarding/create_profile_page.dart';
import 'features/onboarding/network_visibility_page.dart';
import 'features/products/product_detail_page.dart';
import 'features/profile/profile_edit_pages.dart';
import 'features/profile/profile_overview.dart';
import 'features/products/products_page.dart';
import 'features/settings/policy_page.dart';
import 'features/settings/settings_page.dart';
import 'features/shell/app_shell.dart';
import 'features/workspaces/create_workspace_page.dart';
import 'features/workspaces/invite_link_page.dart';
import 'features/workspaces/invite_members_page.dart';
import 'features/workspaces/workspace_detail_page.dart';
import 'features/workspaces/workspaces_page.dart';

// Mirrors RedirectIfSignedIn, OnboardingGuard and RequireAuth in apps/web.
const _signedOutOnly = {'/', '/login', '/signup'};
const _open = {'/otp-verification', '/forgot-password', '/reset-password', '/terms', '/privacy'};
const _onboarding = {'/join-network', '/create-profile', '/network-visibility'};

String? redirectFor(Me? user, Uri uri) {
  final path = uri.path;
  if (_open.contains(path)) return null;

  if (user == null) {
    if (_signedOutOnly.contains(path)) return null;
    if (_onboarding.contains(path)) return '/login';
    return Uri(path: '/login', queryParameters: {'next': uri.toString()}).toString();
  }

  if (_signedOutOnly.contains(path)) return homeFor(user);
  if (_onboarding.contains(path)) return user.onboarded ? homeFor(user) : null;
  if (!user.onboarded) return homeFor(user);
  return null;
}

typedef _Params = Map<String, String>;

GoRoute _page(String path, Widget Function(_Params params, _Params query) build) => GoRoute(
  path: path,
  pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: build(state.pathParameters, state.uri.queryParameters)),
);

final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ValueNotifier<Me?>(ref.read(authProvider));
  ref.listen(authProvider, (_, user) => signedIn.value = user);
  ref.onDispose(signedIn.dispose);

  return GoRouter(
    refreshListenable: signedIn,
    redirect: (_, state) => redirectFor(ref.read(authProvider), state.uri),
    routes: [
      _page('/', (_, _) => const WelcomePage()),
      _page('/login', (_, q) => LoginPage(next: safeNext(q['next']), persona: q['persona'], reset: q.containsKey('reset'))),
      _page('/signup', (_, q) => SignupPage(persona: q['persona'])),
      _page(
        '/otp-verification',
        (_, q) => OtpPage(
          email: q['email'] ?? '',
          mode: OtpMode.values.asNameMap()[q['mode']] ?? OtpMode.verify,
          next: safeNext(q['next']),
          persona: q['persona'],
        ),
      ),
      _page('/forgot-password', (_, _) => const ForgotPasswordPage()),
      _page('/reset-password', (_, _) => const ResetPasswordPage()),
      _page('/join-network', (_, _) => const WelcomePage(joinNetwork: true)),
      _page('/create-profile', (_, q) => CreateProfilePage(persona: q['persona'])),
      _page('/network-visibility', (_, _) => const NetworkVisibilityPage()),
      _page('/terms', (_, _) => const PolicyPage(type: 'terms', title: 'Terms & Conditions')),
      _page('/privacy', (_, _) => const PolicyPage(type: 'privacy', title: 'Privacy Policy')),
      _page('/canvas/:canvasId', (p, q) => CanvasPage(canvasId: p['canvasId']!, addProduct: q['addProduct'])),
      _page('/discover-canvas/:postId', (p, _) => DiscoverCanvasPage(postId: p['postId']!)),
      ShellRoute(
        builder: (_, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          _page('/home', (_, _) => const HomePage()),
          _page('/business/home', (_, _) => const BusinessHomePage()),
          _page('/business/dashboard', (_, _) => const BusinessDashboardPage()),
          _page('/business/products/add', (_, _) => const AddProductPage()),
          _page('/business/products/add/review', (_, _) => const ReviewProductPage()),
          _page('/business/products/:productId/edit', (p, _) => EditProductPage(productId: p['productId']!)),
          _page('/business/:id', (p, _) => BusinessProfilePage(id: p['id']!)),
          _page('/discover', (_, _) => const DiscoverPage()),
          _page('/discover/create-post', (_, _) => const CreatePostPage()),
          _page('/discover/select-canvas', (_, _) => const SelectCanvasPage()),
          _page('/discover/post/:postId', (p, _) => PostPage(postId: p['postId']!)),
          _page('/explore', (_, q) => ExplorePage(tab: q['tab'], q: q['q'] ?? '')),
          _page('/products', (_, _) => const ProductsPage()),
          _page('/products/:productId', (p, _) => ProductDetailPage(productId: p['productId']!)),
          _page('/profile', (_, _) => const ProfileOverview()),
          _page('/profile/edit', (_, _) => const EditPersonalProfilePage()),
          _page('/profile/edit-business', (_, _) => const EditBusinessProfilePage()),
          _page('/profile/:id', (p, _) => ProfileOverview(userId: p['id'])),
          _page('/settings', (_, _) => const SettingsPage()),
          _page('/workspaces', (_, _) => const WorkspacesPage()),
          _page('/workspaces/create', (_, _) => const CreateWorkspacePage()),
          GoRoute(path: '/workspaces/:id', redirect: (_, state) => '/workspaces/${state.pathParameters['id']}/canvases'),
          for (final tab in const ['canvases', 'files', 'members'])
            _page('/workspaces/:id/$tab', (p, _) => WorkspaceDetailPage(id: p['id']!, tab: tab)),
          _page('/workspaces/:id/invite', (p, _) => InviteMembersPage(id: p['id']!)),
          _page('/classrooms', (_, _) => const ClassroomsPage()),
          _page('/classrooms/create', (_, q) => CreateClassroomPage(id: q['id'])),
          _page('/classrooms/create/curriculum', (_, q) => CurriculumBuilderPage(id: q['id'])),
          _page('/classrooms/create/module', (_, q) => CreateModulePage(id: q['id'])),
          _page('/classrooms/create/review', (_, q) => ReviewClassroomPage(id: q['id'])),
          _page('/classrooms/join', (_, _) => const JoinClassroomPage()),
          _page('/classrooms/manage', (_, _) => const ManageClassroomsPage()),
          _page('/classrooms/:classroomId', (p, q) => ClassroomPage(classroomId: p['classroomId']!, tab: q['tab'])),
          _page('/invite/:token', (p, _) => InviteLinkPage(token: p['token']!)),
        ],
      ),
    ],
  );
});
