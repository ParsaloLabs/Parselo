import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/order.dart';

class IncomingOfferCard extends StatelessWidget {
  final AgentOrder order;
  final bool isTop;
  final int timeLeftSeconds;
  final int totalSeconds;
  final VoidCallback onAccept;
  final VoidCallback onSkip;

  const IncomingOfferCard({
    super.key,
    required this.order,
    required this.isTop,
    required this.timeLeftSeconds,
    required this.totalSeconds,
    required this.onAccept,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isSend = order.orderType == OrderType.send;
    final payoutRupees = (order.totalAmount / 100).round();
    final fromLabel = isSend
        ? 'Customer Address'
        : (order.sourceTrackingId != null && order.sourceTrackingId!.isNotEmpty
            ? 'Courier branch'
            : 'Sender Address');
    final toLabel =
        (order.deliveryAddress?.isNotEmpty ?? false) ? order.deliveryAddress! : 'Destination';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BrandColors.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CountdownBar(
              visible: isTop,
              timeLeft: timeLeftSeconds,
              total: totalSeconds,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _TypeBadge(isSend: isSend),
                                if (order.offerDistanceM != null) ...[
                                  const SizedBox(width: 6),
                                  _DistanceBadge(meters: order.offerDistanceM!),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              order.orderCode,
                              style: const TextStyle(
                                fontFamily: 'Menlo',
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: BrandColors.slate800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Item: ${order.parcelDescription ?? 'Package'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: BrandColors.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹$payoutRupees',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: BrandColors.emeraldDark,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'PAYOUT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: BrandColors.slate400,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: BrandColors.slate50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _AddrRow(
                          label: 'From',
                          color: BrandColors.emeraldDark,
                          text: fromLabel,
                        ),
                        const SizedBox(height: 6),
                        _AddrRow(
                          label: 'To',
                          color: BrandColors.rose600,
                          text: toLabel,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircleButton(
                        icon: Icons.close,
                        background: const Color(0xFFFEF2F2),
                        border: const Color(0xFFFECACA),
                        iconColor: BrandColors.rose600,
                        onPressed: onSkip,
                        tooltip: 'Reject offer',
                      ),
                      if (isTop)
                        _AutoSkipBadge(timeLeft: timeLeftSeconds.clamp(0, 999))
                      else
                        const SizedBox.shrink(),
                      _CircleButton(
                        icon: Icons.check,
                        background: BrandColors.emerald,
                        border: BrandColors.emeraldDark,
                        iconColor: Colors.white,
                        onPressed: onAccept,
                        tooltip: 'Accept offer',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownBar extends StatelessWidget {
  final bool visible;
  final int timeLeft;
  final int total;
  const _CountdownBar({
    required this.visible,
    required this.timeLeft,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(height: 3);
    final denom = total > 0 ? total : 30;
    final ratio = (timeLeft / denom).clamp(0.0, 1.0);
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (context, c) {
          return Stack(
            children: [
              Container(color: BrandColors.slate100),
              AnimatedContainer(
                duration: const Duration(milliseconds: 950),
                curve: Curves.linear,
                width: c.maxWidth * ratio,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [BrandColors.brand, BrandColors.emerald],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final bool isSend;
  const _TypeBadge({required this.isSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BrandColors.brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSend ? Icons.upload_rounded : Icons.download_rounded,
            size: 12,
            color: BrandColors.brand,
          ),
          const SizedBox(width: 4),
          Text(
            isSend ? 'Dispatch Send' : 'Partner Collect',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: BrandColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  final int meters;
  const _DistanceBadge({required this.meters});

  String _format() {
    if (meters < 1000) return '$meters m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BrandColors.slate50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me_rounded, size: 12, color: BrandColors.slate500),
          const SizedBox(width: 4),
          Text(
            '${_format()} away',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: BrandColors.slate700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddrRow extends StatelessWidget {
  final String label;
  final Color color;
  final String text;
  const _AddrRow({required this.label, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BrandColors.slate700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color border;
  final Color iconColor;
  final VoidCallback onPressed;
  final String tooltip;
  const _CircleButton({
    required this.icon,
    required this.background,
    required this.border,
    required this.iconColor,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: CircleBorder(side: BorderSide(color: border, width: 1)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}

class _AutoSkipBadge extends StatelessWidget {
  final int timeLeft;
  const _AutoSkipBadge({required this.timeLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: BrandColors.slate50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.slate100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: BrandColors.brand,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Auto-skip in ${timeLeft}s',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: BrandColors.slate500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
