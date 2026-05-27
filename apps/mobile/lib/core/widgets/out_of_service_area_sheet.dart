import 'package:flutter/material.dart';
import '../theme/theme.dart';
import 'brand_button.dart';

/// Friendly bottom sheet shown when the customer drops a pin outside any
/// active service area. RedTaxi-style copy: "We're Expanding, But Not Here
/// Yet!". Modal + non-dismissable on the action — they must pick a new spot
/// or back out of the screen.
class OutOfServiceAreaSheet extends StatelessWidget {
  final String? nearestCityName;
  final VoidCallback onPickAgain;

  const OutOfServiceAreaSheet({
    Key? key,
    required this.onPickAgain,
    this.nearestCityName,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    String? nearestCityName,
    required VoidCallback onPickAgain,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => OutOfServiceAreaSheet(
        nearestCityName: nearestCityName,
        onPickAgain: onPickAgain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headline = nearestCityName == null
        ? "We're Expanding, But Not Here Yet!"
        : "We're Expanding, But Not Here Yet!";
    final body = nearestCityName == null
        ? "Parsalo is currently live in Thrissur. We'll be in your area very soon — thanks for your patience!"
        : "Parsalo is currently live in $nearestCityName only. We'll be expanding to your area very soon — thanks for your patience!";

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withOpacity(0.10),
              ),
              child: const Icon(
                Icons.location_off_rounded,
                size: 56,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: BrandButton(
                text: 'Pick a different location',
                onPressed: () {
                  Navigator.of(context).pop();
                  onPickAgain();
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
