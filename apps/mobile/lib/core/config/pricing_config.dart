import '../network/api_client.dart';

/// Canonical fee values exposed by `GET /config/pricing`. Cached after the
/// first successful fetch so notifiers can read synchronously. Defaults
/// match the backend's hardcoded fallbacks, so the UI stays usable even
/// before the first fetch completes (or if it fails offline).
class PricingConfig {
  PricingConfig._();
  static final PricingConfig instance = PricingConfig._();

  int sendBaseServiceFeePaise = 4000;
  int sendPerKmFeePaise = 500;
  int sendFreeDistanceKm = 5;
  int receivePickupFeePaise = 9900;
  int sameDayDeliveryFeePaise = 3000;
  double gstRate = 0.18;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final res = await ApiClient.request('/config/pricing', auth: false);
      if (res is Map) {
        sendBaseServiceFeePaise = (res['send_base_service_fee_paise'] as num?)?.toInt() ?? sendBaseServiceFeePaise;
        sendPerKmFeePaise = (res['send_per_km_fee_paise'] as num?)?.toInt() ?? sendPerKmFeePaise;
        sendFreeDistanceKm = (res['send_free_distance_km'] as num?)?.toInt() ?? sendFreeDistanceKm;
        receivePickupFeePaise = (res['receive_pickup_fee_paise'] as num?)?.toInt() ?? receivePickupFeePaise;
        sameDayDeliveryFeePaise = (res['same_day_delivery_fee_paise'] as num?)?.toInt() ?? sameDayDeliveryFeePaise;
        gstRate = (res['gst_rate'] as num?)?.toDouble() ?? gstRate;
        _loaded = true;
      }
    } catch (_) {
      // Stay on defaults; main.dart's fire-and-forget call doesn't block UI.
    }
  }
}
