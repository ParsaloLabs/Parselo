import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/dashboard/domain/status_mapper.dart';
import 'package:mobile/features/receive_parcel/presentation/receive_parcel_notifier.dart';

void main() {
  group('Domain Logic & Pricing Tests', () {
    test('StatusMapper maps backend states to customer friendly labels', () {
      expect(StatusMapper.getLabel('pending'), 'Awaiting agent');
      expect(StatusMapper.getLabel('agent_en_route_pickup'), 'Agent on the way');
      expect(StatusMapper.getLabel('parcel_collected'), 'Picked up');
      expect(StatusMapper.getLabel('delivered'), 'Delivered');
      expect(StatusMapper.getLabel('unknown_state'), 'unknown_state');
    });

    test('ApiClient matches backend validation error codes to instructions', () {
      expect(
        ApiClient.getFriendlyError('invalid_phone'),
        'Enter a valid mobile number (10 digits, with or without +91).',
      );
      expect(
        ApiClient.getFriendlyError('otp_invalid_or_expired'),
        'OTP is incorrect or has expired. Resend a new one.',
      );
      expect(
        ApiClient.getFriendlyError('random_error'),
        'random_error',
      );
    });

    test('ReceiveNotifier pricing calculations match corporate formulas', () {
      final notifier = ReceiveParcelNotifier();
      
      // Default: Next Day Speed (no same-day surcharge)
      // Pickup fee: ₹99, Same-day: ₹0, Service: ₹99, GST: 18% of ₹99 = ₹17.82 -> round to 18
      // Total: 99 + 18 = ₹117
      expect(notifier.sameDay, false);
      expect(notifier.pickupFee, 9900);
      expect(notifier.deliveryFee, 0);
      expect(notifier.service, 9900);
      expect(notifier.gst, 1782); // 9900 * 0.18 = 1782 paise
      expect(notifier.totalAmount, 9900 + 1782);

      // Same-day: Surcharge added (+₹30)
      // Pickup: ₹99, Same-day: ₹30, Service: ₹129, GST: 18% of ₹129 = ₹23.22 -> round to 23
      // Total: 129 + 23 = ₹152
      notifier.setSameDay(true);
      expect(notifier.sameDay, true);
      expect(notifier.deliveryFee, 3000);
      expect(notifier.service, 12900);
      expect(notifier.gst, 2322); // 12900 * 0.18 = 2322 paise
      expect(notifier.totalAmount, 12900 + 2322);
    });
  });
}
