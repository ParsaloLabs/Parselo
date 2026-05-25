import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';

class AuthNotifier extends ChangeNotifier {
  bool _loading = false;
  String? _error;
  String? _devOtp;
  String _phone = '+91';
  bool _isAuthenticated = false;

  bool get loading => _loading;
  String? get error => _error;
  String? get devOtp => _devOtp;
  String get phone => _phone;
  bool get isAuthenticated => _isAuthenticated;

  AuthNotifier() {
    _isAuthenticated = TokenStore.hasToken();
  }

  void setPhone(String val) {
    _phone = val;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> sendOtp(String mobileNumber) async {
    _loading = true;
    _error = null;
    _devOtp = null;
    _phone = mobileNumber;
    notifyListeners();

    try {
      final res = await ApiClient.request(
        '/auth/send-otp',
        method: 'POST',
        body: {'phone': mobileNumber},
        auth: false,
      );
      
      if (res is Map && res['dev_otp'] != null) {
        _devOtp = res['dev_otp'].toString();
      }
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String otpCode) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.request(
        '/auth/verify-otp',
        method: 'POST',
        body: {
          'phone': _phone,
          'otp': otpCode,
        },
        auth: false,
      );

      final token = res['token'];
      if (token != null) {
        await TokenStore.setToken(token);
        _isAuthenticated = true;
        _loading = false;
        notifyListeners();
        return true;
      } else {
        throw ApiException('Invalid token returned from server');
      }
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await TokenStore.setToken(null);
    _isAuthenticated = false;
    notifyListeners();
  }
}
