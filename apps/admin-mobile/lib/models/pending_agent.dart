class PendingAgent {
  final String id;
  final String phone;
  final String fullName;
  final String? email;
  final String? vehicleType;
  final String? vehicleNumber;
  final String? dlNumber;
  final String? city;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;
  final String createdAt;

  PendingAgent({
    required this.id,
    required this.phone,
    required this.fullName,
    this.email,
    this.vehicleType,
    this.vehicleNumber,
    this.dlNumber,
    this.city,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
  });

  factory PendingAgent.fromJson(Map<String, dynamic> json) {
    return PendingAgent(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'],
      vehicleType: json['vehicle_type'],
      vehicleNumber: json['vehicle_number'],
      dlNumber: json['dl_number'],
      city: json['city'],
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejection_reason'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ApprovedAgent {
  final String id;
  final String phone;
  final String fullName;
  final String? vehicleType;
  final String? vehicleNumber;
  final bool isOnline;
  final bool isActive;
  final double rating;

  ApprovedAgent({
    required this.id,
    required this.phone,
    required this.fullName,
    this.vehicleType,
    this.vehicleNumber,
    required this.isOnline,
    required this.isActive,
    required this.rating,
  });

  factory ApprovedAgent.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 5.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 5.0;
      return 5.0;
    }

    return ApprovedAgent(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      fullName: json['full_name'] ?? '',
      vehicleType: json['vehicle_type'],
      vehicleNumber: json['vehicle_number'],
      isOnline: json['is_online'] == true,
      isActive: json['is_active'] == true,
      rating: parseDouble(json['rating']),
    );
  }
}
