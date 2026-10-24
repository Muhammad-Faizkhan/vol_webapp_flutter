import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'me.dart';

// Overridden in main() with a client that has already tried to restore the session.
final apiProvider = Provider<ApiClient>((ref) => throw UnimplementedError());

final authProvider = NotifierProvider<AuthNotifier, Me?>(AuthNotifier.new);

class AuthNotifier extends Notifier<Me?> {
  @override
  Me? build() {
    final api = ref.watch(apiProvider);
    api.onUserChanged = (user) => state = user;
    ref.onDispose(() => api.onUserChanged = null);
    return api.user;
  }
}
