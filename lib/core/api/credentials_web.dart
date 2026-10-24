import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

// The refresh token is an httpOnly cookie on the API's domain, so every request has to carry it.
void sendCookies(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
}
