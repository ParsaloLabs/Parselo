import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

int? _parseInt(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? double.tryParse(val)?.toInt();
  return null;
}

class OrderSummary {
  final String id;
  final String orderCode;
  final String orderType;
  final String status;
  final int totalAmount;
  final String createdAt;
  final String? paymentStatus;

  OrderSummary({
    required this.id,
    required this.orderCode,
    required this.orderType,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    this.paymentStatus,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      id: json['id'] ?? '',
      orderCode: json['order_code'] ?? '',
      orderType: json['order_type'] ?? '',
      status: json['status'] ?? '',
      totalAmount: _parseInt(json['total_amount']) ?? 0,
      createdAt: json['created_at'] ?? '',
      paymentStatus: json['payment_status'],
    );
  }
}

class DashboardNotifier extends ChangeNotifier {
  List<OrderSummary> _orders = [];
  bool _loading = false;
  String? _error;

  List<OrderSummary> get orders => _orders;
  bool get loading => _loading;
  String? get error => _error;

  OrderSummary? get needsActionOrder {
    try {
      return _orders.firstWhere(
        (o) => o.status == 'failed' && o.paymentStatus == 'paid',
      );
    } catch (_) {
      return null;
    }
  }

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> fetchOrders() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.request('/orders?limit=5');
      if (res is List) {
        _orders = res.map((j) => OrderSummary.fromJson(j)).toList();
      }
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      _loading = false;
      notifyListeners();
    }
  }
}
