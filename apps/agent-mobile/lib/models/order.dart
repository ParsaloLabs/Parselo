double? _asDouble(dynamic v) {
  if (v == null || v == '') return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int _asInt(dynamic v) {
  if (v == null || v == '') return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String? _asString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

enum OrderType { send, receive }

class AgentOrder {
  final String id;
  final String orderCode;
  final OrderType orderType;
  final String status;
  final int totalAmount; // paise

  final String? recipientName;
  final String? recipientPhone;
  final String? deliveryAddress;
  final String? parcelDescription;
  final String? sourceTrackingId;
  final String? courierTrackingId;

  final double? pickupLat;
  final double? pickupLng;
  final String? pickupText;

  final double? dropLat;
  final double? dropLng;
  final String? dropText;
  final String? dropBranchName;
  final String? dropBranchPhone;
  final String? dropBranchHours;
  final String? selectedCourierName;

  final String? failureReason;
  final DateTime? updatedAt;

  // Dispatch offer metadata — only populated for rows under `offered` in /agent/jobs.
  final String? offerId;
  final int? offerDistanceM;
  final DateTime? offerExpiresAt;
  final int? offerRank;

  const AgentOrder({
    required this.id,
    required this.orderCode,
    required this.orderType,
    required this.status,
    required this.totalAmount,
    this.recipientName,
    this.recipientPhone,
    this.deliveryAddress,
    this.parcelDescription,
    this.sourceTrackingId,
    this.courierTrackingId,
    this.pickupLat,
    this.pickupLng,
    this.pickupText,
    this.dropLat,
    this.dropLng,
    this.dropText,
    this.dropBranchName,
    this.dropBranchPhone,
    this.dropBranchHours,
    this.selectedCourierName,
    this.failureReason,
    this.updatedAt,
    this.offerId,
    this.offerDistanceM,
    this.offerExpiresAt,
    this.offerRank,
  });

  factory AgentOrder.fromJson(Map<String, dynamic> j) {
    return AgentOrder(
      id: j['id'] as String,
      orderCode: j['order_code'] as String,
      orderType: j['order_type'] == 'receive' ? OrderType.receive : OrderType.send,
      status: j['status'] as String,
      totalAmount: _asInt(j['total_amount']),
      recipientName: _asString(j['recipient_name']),
      recipientPhone: _asString(j['recipient_phone']),
      deliveryAddress: _asString(j['delivery_address']),
      parcelDescription: _asString(j['parcel_description']),
      sourceTrackingId: _asString(j['source_tracking_id']),
      courierTrackingId: _asString(j['courier_tracking_id']),
      pickupLat: _asDouble(j['pickup_lat']),
      pickupLng: _asDouble(j['pickup_lng']),
      pickupText: _asString(j['pickup_text']),
      dropLat: _asDouble(j['drop_lat']),
      dropLng: _asDouble(j['drop_lng']),
      dropText: _asString(j['drop_text']),
      dropBranchName: _asString(j['drop_branch_name']),
      dropBranchPhone: _asString(j['drop_branch_phone']),
      dropBranchHours: _asString(j['drop_branch_hours']),
      selectedCourierName: _asString(j['selected_courier_name']),
      failureReason: _asString(j['failure_reason']),
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'] as String)
          : null,
      offerId: _asString(j['offer_id']),
      offerDistanceM: j['offer_distance_m'] != null ? _asInt(j['offer_distance_m']) : null,
      offerExpiresAt: j['offer_expires_at'] != null
          ? DateTime.tryParse(j['offer_expires_at'] as String)
          : null,
      offerRank: j['offer_rank'] != null ? _asInt(j['offer_rank']) : null,
    );
  }
}

const Map<String, String> kStatusLabel = {
  'pending': 'Pending',
  'agent_assigned': 'Assigned',
  'agent_en_route_pickup': 'En route',
  'parcel_collected': 'Collected',
  'at_courier_office': 'At courier',
  'shipped': 'Shipped',
  'out_for_delivery': 'Out for delivery',
  'delivered': 'Delivered',
  'cancelled': 'Cancelled',
  'failed': 'Failed',
};
