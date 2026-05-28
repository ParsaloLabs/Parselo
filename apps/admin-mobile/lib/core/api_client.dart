import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'token_storage.dart';

class Env {
  static const String _envApiUrl = String.fromEnvironment('API_URL');

  static String get apiUrl {
    if (_envApiUrl.isNotEmpty) return _envApiUrl;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:4000/api/v1';
      }
    } catch (_) {}
    return 'http://localhost:4000/api/v1';
  }
}

class ApiClient {
  final Dio dio;
  final TokenStorage _tokens;
  void Function()? onUnauthorized;

  ApiClient(this._tokens)
      : dio = Dio(BaseOptions(
          baseUrl: Env.apiUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokens.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) {
        if (err.response?.statusCode == 401) {
          _tokens.deleteToken();
          onUnauthorized?.call();
        }
        handler.next(err);
      },
    ));
  }
}

String extractErrorCode(Object err) {
  if (err is DioException) {
    final data = err.response?.data;
    if (data is Map) {
      final code = data['error'] ?? data['message'];
      if (code is String && code.isNotEmpty) return code;
    }
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.connectionError) {
      return 'network_unreachable';
    }
    final status = err.response?.statusCode;
    if (status != null) return 'http_$status';
  }
  return 'unexpected_error';
}

String humanizeError(String code) {
  switch (code) {
    case 'invalid_credentials':
      return 'Incorrect email or password.';
    case 'network_unreachable':
      return 'Cannot reach the Parsalo server. Please ensure the backend is running.';
    case 'cannot_assign':
      return 'Cannot assign agent. Order status may have changed.';
    case 'cannot_approve':
      return 'Cannot approve this agent application.';
    case 'cannot_reject':
      return 'Cannot reject this agent application.';
    case 'already_refunded':
      return 'This order has already been refunded.';
    case 'amount_exceeds_total':
      return 'Refund amount cannot exceed order total amount.';
    case 'not_failed':
      return 'Order is not in failed state.';
    case 'http_404':
      return 'Not found.';
    default:
      return 'Something went wrong ($code).';
  }
}
