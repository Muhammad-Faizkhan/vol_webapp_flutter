import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Values handed from one auth screen to the next. The web app keeps these in sessionStorage;
/// here they live for the tab's lifetime, which is the same thing for a single-page app.
class AuthFlow {
  /// Temporary, while the API returns signup codes (SHOW_SIGNUP_CODE): email -> code.
  final devCodes = <String, String>{};

  String? resetToken;
}

final authFlowProvider = Provider((ref) => AuthFlow());

/// Only same-site relative paths are honoured as ?next= targets.
String? safeNext(String? next) => next != null && next.startsWith('/') && !next.startsWith('//') ? next : null;
