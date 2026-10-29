import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String loginEndpoint = '/api/auth/login';

  static String get resolvedBaseUrl {
    if (baseUrl.isNotEmpty) {
      return baseUrl;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }
}
