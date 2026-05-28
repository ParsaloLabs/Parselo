class ServiceArea {
  final String id;
  final String name;
  final double centerLat;
  final double centerLng;
  final int radiusM;
  final bool isActive;
  final String updatedAt;

  ServiceArea({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radiusM,
    required this.isActive,
    required this.updatedAt,
  });

  factory ServiceArea.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return ServiceArea(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      centerLat: parseDouble(json['center_lat']),
      centerLng: parseDouble(json['center_lng']),
      radiusM: parseInt(json['radius_m']),
      isActive: json['is_active'] == true,
      updatedAt: json['updated_at'] ?? '',
    );
  }
}
