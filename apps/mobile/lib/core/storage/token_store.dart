import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const String _key = 'pp.mobile.token';
  
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> setToken(String? token) async {
    if (_prefs == null) await init();
    if (token != null) {
      await _prefs!.setString(_key, token);
    } else {
      await _prefs!.remove(_key);
    }
  }

  static String? getToken() {
    return _prefs?.getString(_key);
  }

  static bool hasToken() {
    final t = getToken();
    return t != null && t.isNotEmpty;
  }
}
