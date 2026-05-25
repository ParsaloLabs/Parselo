import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/order.dart';

class AssignedJobTile extends StatelessWidget {
  final AgentOrder order;
  final VoidCallback onTap;
  const AssignedJobTile({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSend = order.orderType == OrderType.send;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BrandColors.slate200),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSend
                      ? const Color(0xFFFFFBEB)
                      : BrandColors.brand.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    isSend ? Icons.upload : Icons.download,
                    size: 20,
                    color: isSend
                        ? const Color(0xFFD97706)
                        : BrandColors.brand,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderCode,
                      style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.slate800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kStatusLabel[order.status] ?? order.status,
                      style: const TextStyle(
                        fontSize: 11,
                        color: BrandColors.slate400,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: BrandColors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Manage',
                      style: TextStyle(
                        color: BrandColors.brand,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward,
                        color: BrandColors.brand, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
