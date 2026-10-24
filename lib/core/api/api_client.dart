import 'package:dio/dio.dart';

import '../auth/me.dart';
import 'api_error.dart';
import 'credentials.dart';

/// Talks to apps/api the same way packages/api-client does for the Next.js app: the access token
/// lives in memory and is renewed through the refresh cookie when it is missing or expired.
class ApiClient {
  ApiClient(String baseUrl) : _dio = Dio(BaseOptions(baseUrl: baseUrl.replaceAll(RegExp(r'/$'), ''))) {
    sendCookies(_dio);
  }

  final Dio _dio;
  String? _token;
  Me? _user;
  Future<Me?>? _refreshing;

  void Function(Me? user)? onUserChanged;

  Me? get user => _user;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);
  Future<T> post<T>(String path, [Object? body]) => _send('POST', path, body: body ?? const {});
  Future<T> put<T>(String path, Object? body) => _send('PUT', path, body: body);
  Future<T> patch<T>(String path, Object? body) => _send('PATCH', path, body: body);
  Future<T> delete<T>(String path) => _send('DELETE', path);

  /// Call with the body of any response that started a session (login, verify, signup).
  Me setSession(Map<String, dynamic> session) {
    _token = session['accessToken'] as String;
    final user = Me.fromJson(session['user'] as Map<String, dynamic>);
    _setUser(user);
    return user;
  }

  /// Re-broadcasts the user after a profile change.
  void updateUser(Me user) => _setUser(user);

  /// Concurrent callers share one request, otherwise the API would rotate the cookie twice.
  Future<Me?> refresh() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> logout() async {
    try {
      await _dio.post<void>('/auth/logout');
    } on DioException {
      // Signed out locally either way.
    } finally {
      _token = null;
      _setUser(null);
    }
  }

  Future<Me?> _refresh() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/auth/refresh');
      return setSession(res.data!);
    } on DioException catch (e) {
      // Offline: keep what we have and let the next request try again.
      if (e.response == null) return null;
      _token = null;
      _setUser(null);
      return null;
    }
  }

  Future<T> _send<T>(String method, String path, {Object? body, Map<String, dynamic>? query, bool retried = false}) async {
    if (_token == null && !retried) await refresh();
    try {
      final res = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: {if (_token != null) 'authorization': 'Bearer $_token'}),
      );
      return res.data as T;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && !retried && !path.startsWith('/auth/')) {
        if (await refresh() != null) {
          return _send(method, path, body: body, query: query, retried: true);
        }
      }
      throw ApiError.fromDio(e);
    }
  }

  void _setUser(Me? user) {
    _user = user;
    onUserChanged?.call(user);
  }
}
