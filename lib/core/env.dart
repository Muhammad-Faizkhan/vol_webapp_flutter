import 'package:flutter/foundation.dart';

// Same rule as apps/web: API_URL wins, otherwise release builds talk to Railway.
const _apiUrl = String.fromEnvironment('API_URL');

final String apiUrl = _apiUrl.isNotEmpty
    ? _apiUrl
    : kReleaseMode
    ? 'https://volwebapp-production.up.railway.app'
    : 'http://localhost:4000';
