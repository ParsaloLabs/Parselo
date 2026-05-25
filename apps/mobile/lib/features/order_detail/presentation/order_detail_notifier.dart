import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

class HistoryEntry {
  final String status;
  final String? notes;
  final String changedByType;
  final String createdAt;

  HistoryEntry({
    required this.status,
    this.notes,
    required this.changedByType,
    required this.createdAt,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      status: json['status'] ?? '',
      notes: json['notes'],
      changedByType: json['changed_by_type'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

double? _parseDouble(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val);
  return null;
}

int? _parseInt(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? double.tryParse(val)?.toInt();
  return null;
}

class AgentInfo {
  final String name;
  final String phone;
  final double? lat;
  final double? lng;

  AgentInfo({
    required this.name,
    required this.phone,
    this.lat,
    this.lng,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      lat: _parseDouble(json['lat']),
      lng: _parseDouble(json['lng']),
    );
  }
}

class DetailedOrder {
  final String id;
  final String orderCode;
  final String orderType;
  final String status;
  
  final String? parcelType;
  final double? parcelWeightKg;
  final String? parcelDescription;
  
  final String? recipientName;
  final String? recipientPhone;
  final String? deliveryAddress;
  final String? sourceTrackingId;

  final int courierCharge;
  final int serviceFee;
  final int gstAmount;
  final int totalAmount;

  final String? deliveryOtp;
  final String paymentStatus;
  final String? failureReason;
  final int? refundAmountPaise;

  final String createdAt;
  final List<HistoryEntry> history;
  final AgentInfo? agent;

  DetailedOrder({
    required this.id,
    required this.orderCode,
    required this.orderType,
    required this.status,
    this.parcelType,
    this.parcelWeightKg,
    this.parcelDescription,
    this.recipientName,
    this.recipientPhone,
    this.deliveryAddress,
    this.sourceTrackingId,
    required this.courierCharge,
    required this.serviceFee,
    required this.gstAmount,
    required this.totalAmount,
    this.deliveryOtp,
    required this.paymentStatus,
    this.failureReason,
    this.refundAmountPaise,
    required this.createdAt,
    required this.history,
    this.agent,
  });

  factory DetailedOrder.fromJson(Map<String, dynamic> json) {
    final list = json['history'] as List? ?? [];
    final hist = list.map((h) => HistoryEntry.fromJson(h)).toList();

    AgentInfo? ag;
    if (json['agent'] != null) {
      ag = AgentInfo.fromJson(json['agent']);
    }

    return DetailedOrder(
      id: json['id'] ?? '',
      orderCode: json['order_code'] ?? '',
      orderType: json['order_type'] ?? '',
      status: json['status'] ?? '',
      parcelType: json['parcel_type'],
      parcelWeightKg: _parseDouble(json['parcel_weight_kg']),
      parcelDescription: json['parcel_description'],
      recipientName: json['recipient_name'],
      recipientPhone: json['recipient_phone'],
      deliveryAddress: json['delivery_address'],
      sourceTrackingId: json['source_tracking_id'],
      courierCharge: _parseInt(json['courier_charge']) ?? 0,
      serviceFee: _parseInt(json['service_fee']) ?? 0,
      gstAmount: _parseInt(json['gst_amount']) ?? 0,
      totalAmount: _parseInt(json['total_amount']) ?? 0,
      deliveryOtp: json['delivery_otp'],
      paymentStatus: json['payment_status'] ?? '',
      failureReason: json['failure_reason'],
      refundAmountPaise: _parseInt(json['refund_amount_paise']),
      createdAt: json['created_at'] ?? '',
      history: hist,
      agent: ag,
    );
  }
}

class OrderDetailNotifier extends ChangeNotifier {
  final String orderId;
  DetailedOrder? _order;
  bool _loading = true;
  String? _error;
  bool _actionBusy = false;
  Timer? _timer;

  DetailedOrder? get order => _order;
  bool get loading => _loading;
  String? get error => _error;
  bool get actionBusy => _actionBusy;

  static const Set<String> terminalStates = {'delivered', 'cancelled', 'failed'};

  OrderDetailNotifier(this.orderId);

  void startPolling() {
    loadDetails(showLoading: true);
    _timer = Timer.periodic(const Duration(seconds: 10), (t) {
      if (_order != null && terminalStates.contains(_order!.status)) {
        t.cancel();
      } else {
        loadDetails(showLoading: false);
      }
    });
  }

  void stopPolling() {
    _timer?.cancel();
  }

  Future<void> loadDetails({bool showLoading = false}) async {
    if (showLoading) {
      _loading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final res = await ApiClient.request('/orders/$orderId');
      _order = DetailedOrder.fromJson(res);
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> retryOrder(String when) async {
    _actionBusy = true;
    notifyListeners();

    try {
      await ApiClient.request(
        '/orders/$orderId/retry',
        method: 'POST',
        body: {'when': when},
      );
      await loadDetails(showLoading: false);
      _actionBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      _actionBusy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestRefund() async {
    _actionBusy = true;
    notifyListeners();

    try {
      await ApiClient.request(
        '/orders/$orderId/request-refund',
        method: 'POST',
      );
      await loadDetails(showLoading: false);
      _actionBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      _actionBusy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelOrder() async {
    _actionBusy = true;
    notifyListeners();

    try {
      await ApiClient.request(
        '/orders/$orderId/cancel',
        method: 'POST',
        body: {'reason': 'user requested'},
      );
      await loadDetails(showLoading: false);
      _actionBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      _actionBusy = false;
      notifyListeners();
      return false;
    }
  }
}
