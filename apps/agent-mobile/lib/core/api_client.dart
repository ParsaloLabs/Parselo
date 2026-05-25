import 'package:dio/dio.dart';

import 'env.dart';
import 'token_storage.dart';

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
        final token = await _tokens.read();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) {
        if (err.response?.statusCode == 401) {
          _tokens.delete();
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
      return 'Phone or password is incorrect.';
    case 'agent_inactive':
      return 'Your account is disabled. Contact admin.';
    case 'network_unreachable':
      return 'Cannot reach server. Check connection.';
    case 'invalid_otp':
      return 'OTP does not match. Try again.';
    case 'transition_not_allowed':
      return 'That status change is not allowed.';
    case 'job_unavailable':
      return 'This offer was just taken by another agent.';
    case 'otp_mismatch':
      return 'OTP does not match. Ask the customer again.';
    case 'failure_reason_required':
      return 'Pick a failure reason first.';
    case 'http_404':
      return 'Not found — this job may have been removed.';
    default:
      return 'Something went wrong ($code).';
  }
}
