import 'package:flutter/foundation.dart';

class Env {
  static const String _envApiUrl = String.fromEnvironment('API_URL');

  /// Google API key used for the Directions API call on the job-detail map.
  /// Same key configured for the Maps SDK (Android: android/local.properties,
  /// iOS: ios/Flutter/Maps.xcconfig). Pass at run time:
  /// `flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza…`.
  /// Empty string means routing is disabled; the map still shows markers.
  static const String googleApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static String get apiUrl {
    if (_envApiUrl.isNotEmpty) return _envApiUrl;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api/v1';
    }
    return 'http://localhost:4000/api/v1';
  }
}
