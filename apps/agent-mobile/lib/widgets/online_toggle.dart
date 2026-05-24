import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../services/location_service.dart';
import '../state/providers.dart';

class OnlineToggleCard extends ConsumerWidget {
  const OnlineToggleCard({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool next) async {
    try {
      await ref.read(onlineStatusProvider.notifier).setOnline(next);
    } catch (e) {
      if (!context.mounted) return;
      String msg = 'Could not change status.';
      if (e is LocationPermissionDenied) {
        msg = e.permanently
            ? 'Location permission is permanently denied. Enable it in Settings to go online.'
            : 'Location permission is required to go online.';
      } else if (e is LocationServiceDisabled) {
        msg = 'Turn on Location Services to go online.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineStatusProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BrandColors.brandDark, BrandColors.brand, BrandColors.emerald],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: BrandColors.brand.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DELIVERY PARTNER CONSOLE',
                  style: TextStyle(
                    color: Color(0xFFA7F3D0),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hello, welcome back!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  online ? 'On duty — receiving offers.' : 'Off duty.',
                  style: const TextStyle(
                    color: Color(0xFFE0E7FF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Text(
                  online ? 'ONLINE' : 'OFFLINE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Switch.adaptive(
                  value: online,
                  onChanged: (v) => _toggle(context, ref, v),
                  activeTrackColor: Colors.white,
                  activeThumbColor: BrandColors.emeraldDark,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
