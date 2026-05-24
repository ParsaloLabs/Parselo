import 'package:flutter/foundation.dart';

class Env {
  static const String _envApiUrl = String.fromEnvironment('API_URL');

  static String get apiUrl {
    if (_envApiUrl.isNotEmpty) return _envApiUrl;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api/v1';
    }
    return 'http://localhost:4000/api/v1';
  }
}
