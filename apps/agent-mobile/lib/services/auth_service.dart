import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/token_storage.dart';

class AuthService {
  final ApiClient _api;
  final TokenStorage _tokens;

  AuthService(this._api, this._tokens);

  Future<void> login(String phone, String password) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/agent/login',
        data: {'phone': phone, 'password': password},
      );
      final token = res.data?['token'] as String?;
      if (token == null || token.isEmpty) {
        throw 'invalid_response';
      }
      await _tokens.write(token);
    } on DioException catch (e) {
      throw extractErrorCode(e);
    }
  }

  Future<void> logout() => _tokens.delete();

  Future<bool> hasSession() async {
    final token = await _tokens.read();
    return token != null && token.isNotEmpty;
  }
}
