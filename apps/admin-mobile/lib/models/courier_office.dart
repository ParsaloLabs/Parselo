class Courier {
  final String id;
  final String name;

  Courier({
    required this.id,
    required this.name,
  });

  factory Courier.fromJson(Map<String, dynamic> json) {
    return Courier(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class CourierOffice {
  final String id;
  final String courierId;
  final String courierName;
  final String? name;
  final String? district;
  final String fullAddress;
  final double? latitude;
  final double? longitude;
  final String? pincode;
  final String? phone;
  final String? openingHours;

  CourierOffice({
    required this.id,
    required this.courierId,
    required this.courierName,
    this.name,
    this.district,
    required this.fullAddress,
    this.latitude,
    this.longitude,
    this.pincode,
    this.phone,
    this.openingHours,
  });

  factory CourierOffice.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return CourierOffice(
      id: json['id'] ?? '',
      courierId: json['courier_id'] ?? '',
      courierName: json['courier_name'] ?? '',
      name: json['name'],
      district: json['district'],
      fullAddress: json['full_address'] ?? '',
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      pincode: json['pincode'],
      phone: json['phone'],
      openingHours: json['opening_hours'],
    );
  }
}
