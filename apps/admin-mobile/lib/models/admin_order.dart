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

class AdminOrder {
  final String id;
  final String orderCode;
  final String? userId;
  final String? agentId;
  final String orderType;
  final String status;
  final int totalAmount;
  final String paymentStatus;
  final String createdAt;
  final String? parcelType;
  final double? parcelWeightKg;
  final String? parcelDescription;
  final String? recipientName;
  final String? recipientPhone;
  final String? deliveryAddress;
  final String? userPhone;
  final String? userName;
  final String? agentName;
  final String? deliveryOtp;
  final String? failureReason;
  final List<HistoryEntry> history;

  AdminOrder({
    required this.id,
    required this.orderCode,
    this.userId,
    this.agentId,
    required this.orderType,
    required this.status,
    required this.totalAmount,
    required this.paymentStatus,
    required this.createdAt,
    this.parcelType,
    this.parcelWeightKg,
    this.parcelDescription,
    this.recipientName,
    this.recipientPhone,
    this.deliveryAddress,
    this.userPhone,
    this.userName,
    this.agentName,
    this.deliveryOtp,
    this.failureReason,
    this.history = const [],
  });

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    final histRaw = json['history'];
    List<HistoryEntry> hist = [];
    if (histRaw is List) {
      hist = histRaw.map((j) => HistoryEntry.fromJson(j)).toList();
    }

    return AdminOrder(
      id: json['id'] ?? '',
      orderCode: json['order_code'] ?? '',
      userId: json['user_id'],
      agentId: json['agent_id'],
      orderType: json['order_type'] ?? '',
      status: json['status'] ?? '',
      totalAmount: parseInt(json['total_amount']),
      paymentStatus: json['payment_status'] ?? '',
      createdAt: json['created_at'] ?? '',
      parcelType: json['parcel_type'],
      parcelWeightKg: parseDouble(json['parcel_weight_kg']),
      parcelDescription: json['parcel_description'],
      recipientName: json['recipient_name'],
      recipientPhone: json['recipient_phone'],
      deliveryAddress: json['delivery_address'],
      userPhone: json['user_phone'],
      userName: json['user_name'],
      agentName: json['agent_name'],
      deliveryOtp: json['delivery_otp'],
      failureReason: json['failure_reason'],
      history: hist,
    );
  }
}
