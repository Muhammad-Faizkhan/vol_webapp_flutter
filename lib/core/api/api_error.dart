import 'package:dio/dio.dart';

class ApiError implements Exception {
  ApiError(this.status, this.message, [this.code]);

  final int status;
  final String message;
  final String? code;

  factory ApiError.fromDio(DioException e) {
    final res = e.response;
    if (res == null) return ApiError(0, "Can't reach the server. Check your connection and try again.");

    final data = res.data;
    var message = res.statusMessage ?? 'Something went wrong';
    String? code;
    if (data is Map) {
      final m = data['message'];
      if (m is List) message = m.join('. ');
      if (m is String) message = m;
      code = data['code'] as String?;
    }
    return ApiError(res.statusCode ?? 0, _capitalize(message), code);
  }

  @override
  String toString() => message;
}

String errorMessage(Object error) => error is ApiError ? error.message : 'Something went wrong. Please try again.';

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
