class DispatchConfig {
  final int initialRadiusM;
  final int offerTtlSeconds;
  final String updatedAt;

  DispatchConfig({
    required this.initialRadiusM,
    required this.offerTtlSeconds,
    required this.updatedAt,
  });

  factory DispatchConfig.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return DispatchConfig(
      initialRadiusM: parseInt(json['initial_radius_m']),
      offerTtlSeconds: parseInt(json['offer_ttl_seconds']),
      updatedAt: json['updated_at'] ?? '',
    );
  }
}
