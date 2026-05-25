import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/brand_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../dashboard/domain/status_mapper.dart';
import '../../payments/presentation/payment_screen.dart';
import 'order_detail_notifier.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final VoidCallback? onBack;

  const OrderDetailScreen({Key? key, required this.orderId, this.onBack}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late OrderDetailNotifier _notifier;

  static const List<String> STEPS = [
    'pending',
    'agent_assigned',
    'agent_en_route_pickup',
    'parcel_collected',
    'out_for_delivery',
    'delivered'
  ];

  static const Set<String> TRACKING_STATES = {
    'agent_assigned',
    'agent_en_route_pickup',
    'parcel_collected',
    'out_for_delivery'
  };

  @override
  void initState() {
    super.initState();
    _notifier = OrderDetailNotifier(widget.orderId);
    _notifier.startPolling();
  }

  @override
  void dispose() {
    _notifier.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final order = _notifier.order;

        if (_notifier.loading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            ),
          );
        }

        if (_notifier.error != null && order == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_notifier.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  BrandButton(text: 'Retry', onPressed: () => _notifier.loadDetails(showLoading: true)),
                ],
              ),
            ),
          );
        }

        if (order == null) return const Scaffold();

        final isCancelled = order.status == 'cancelled';
        final isFailed = order.status == 'failed';
        final isDelivered = order.status == 'delivered';
        final isTerminal = OrderDetailNotifier.terminalStates.contains(order.status);
        final currentStepIdx = STEPS.indexOf(order.status);

        // Show Map if en route or collected
        final showMap = TRACKING_STATES.contains(order.status) &&
            order.agent?.lat != null &&
            order.agent?.lng != null;

        // OTP Display logic:
        // Send: until collected. Receive: only when out for delivery.
        bool showOtp = false;
        if (order.deliveryOtp != null) {
          if (order.orderType == 'send') {
            showOtp = !['parcel_collected', 'out_for_delivery', 'delivered'].contains(order.status);
          } else {
            showOtp = order.status == 'out_for_delivery';
          }
        }

        return WillPopScope(
          onWillPop: () async {
            if (widget.onBack != null) widget.onBack!();
            return true;
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: () {
                  if (widget.onBack != null) widget.onBack!();
                  Navigator.of(context).pop();
                },
              ),
              title: const Text(
                'Order Details',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title / Status Card
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.orderCode,
                                style: const TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${order.orderType == 'send' ? '📤 Send' : '📥 Receive'} · Booked ${DateTime.parse(order.createdAt).toLocal().toString().substring(0, 16)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCancelled || isFailed
                                ? Colors.red.shade50
                                : (isDelivered ? Colors.green.shade50 : AppColors.brand.withOpacity(0.08)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            StatusMapper.getLabel(order.status),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCancelled || isFailed
                                  ? Colors.red.shade700
                                  : (isDelivered ? Colors.green.shade700 : AppColors.brand),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Failed state options
                  if (isFailed) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Order couldn\'t be completed',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 14),
                          ),
                          if (order.failureReason != null) ...[
                            const SizedBox(height: 4),
                            Text('Reason: ${order.failureReason}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                          
                          if (order.paymentStatus == 'paid') ...[
                            const SizedBox(height: 12),
                            const Text('What would you like to do?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 10),
                            BrandButton(
                              text: 'Retry today',
                              height: 40,
                              loading: _notifier.actionBusy,
                              onPressed: () => _notifier.retryOrder('today'),
                            ),
                            const SizedBox(height: 8),
                            BrandButton(
                              text: 'Retry tomorrow',
                              height: 40,
                              loading: _notifier.actionBusy,
                              onPressed: () => _notifier.retryOrder('tomorrow'),
                            ),
                            const SizedBox(height: 8),
                            BrandButton(
                              text: 'Request refund',
                              height: 40,
                              isSecondary: true,
                              color: Colors.red.shade100,
                              textColor: Colors.red.shade800,
                              onPressed: () => _notifier.requestRefund(),
                            ),
                          ],
                          
                          if (order.paymentStatus == 'refund_requested') ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text('Refund requested — our team is reviewing and will process it shortly.', style: TextStyle(color: Colors.amber.shade900, fontSize: 12)),
                            ),
                          ],
                          
                          if (order.paymentStatus == 'refunded') ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text('Refunded ₹${((order.refundAmountPaise ?? 0) / 100).toStringAsFixed(0)} to your original payment method.', style: TextStyle(color: Colors.green.shade900, fontSize: 12)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Live Tracker Map
                  if (showMap) ...[
                    _SectionHeader(title: 'Live Tracking'),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(order.agent!.lat!, order.agent!.lng!),
                          zoom: 14,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('agent'),
                            position: LatLng(order.agent!.lat!, order.agent!.lng!),
                            infoWindow: InfoWindow(title: 'Agent ${order.agent!.name}'),
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                          )
                        },
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Payment Pending alert
                  if (!isCancelled && order.paymentStatus != 'paid') ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PaymentScreen(orderId: order.id),
                          ),
                        ).then((_) => _notifier.loadDetails(showLoading: false));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment pending',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Click here to complete payment and dispatch this booking',
                                    style: TextStyle(color: Color(0xFFDBEAFE), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.8), size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Stepper Tracker Card
                  if (!isTerminal) ...[
                    _SectionHeader(title: 'Progress'),
                    const SizedBox(height: 8),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: STEPS.map((s) {
                          final idx = STEPS.indexOf(s);
                          final isDone = idx <= currentStepIdx;
                          final isActive = idx == currentStepIdx;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  height: 24,
                                  width: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isDone ? AppColors.brand : const Color(0xFFE2E8F0),
                                    shape: BoxShape.circle,
                                    border: isActive ? Border.all(color: Colors.blue.shade100, width: 4) : null,
                                  ),
                                  child: isDone
                                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                                      : Text((idx + 1).toString(), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  StatusMapper.getLabel(s),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                    color: isDone ? AppColors.textPrimary : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // OTP Handover display
                  if (showOtp) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade200),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text('Handover OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          Text(
                            order.deliveryOtp!,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                              color: AppColors.brand,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            order.orderType == 'send'
                                ? 'Read this code to the agent at pickup to confirm handover.'
                                : 'Read this code to the agent at delivery to confirm handover.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Specs Details Card
                  _SectionHeader(title: 'Details'),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (order.orderType == 'send') ...[
                          _DetailFieldRow(label: 'Parcel', val: '${order.parcelType}  ·  ${order.parcelWeightKg} kg${order.parcelDescription != null ? '  ·  ${order.parcelDescription}' : ''}'),
                          const Divider(color: AppColors.border, height: 20),
                          _DetailFieldRow(label: 'Recipient', val: '${order.recipientName}  (${order.recipientPhone})'),
                          const Divider(color: AppColors.border, height: 20),
                          _DetailFieldRow(label: 'Delivery', val: order.deliveryAddress ?? ''),
                        ] else ...[
                          _DetailFieldRow(label: 'Tracking ID', val: order.sourceTrackingId ?? ''),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Downloading authorization letter (PDF)...'),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.file_copy_rounded, color: AppColors.textSecondary, size: 18),
                            label: const Text('📄 Download authorization PDF', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pricing/Payment status Card
                  _SectionHeader(title: 'Payment breakdown'),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (order.courierCharge > 0) ...[
                          _DetailPriceRow(label: 'Courier charge', paise: order.courierCharge),
                          const SizedBox(height: 8),
                        ],
                        _DetailPriceRow(label: 'Service fee', paise: order.serviceFee),
                        const SizedBox(height: 8),
                        _DetailPriceRow(label: 'GST', paise: order.gstAmount),
                        const Divider(color: AppColors.border, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                            Text('₹${(order.totalAmount / 100).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Payment status: ${order.paymentStatus}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Activity Logs Card
                  if (order.history.isNotEmpty) ...[
                    _SectionHeader(title: 'Activity logs'),
                    const SizedBox(height: 8),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: order.history.reversed.map((h) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateTime.parse(h.createdAt).toLocal().toString().substring(11, 16),
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(StatusMapper.getLabel(h.status), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                    if (h.notes != null) ...[
                                      const SizedBox(height: 2),
                                      Text(h.notes!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Cancellation button
                  if (!isTerminal) ...[
                    BrandButton(
                      text: 'Cancel Order',
                      isSecondary: true,
                      color: Colors.red.shade50,
                      textColor: Colors.red,
                      loading: _notifier.actionBusy,
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Cancel Order'),
                            content: const Text('Are you sure you want to cancel this order?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
                              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          _notifier.cancelOrder();
                        }
                      },
                    ),
                    const SizedBox(height: 30),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
      ),
    );
  }
}

class _DetailFieldRow extends StatelessWidget {
  final String label;
  final String val;

  const _DetailFieldRow({required this.label, required this.val});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(val, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _DetailPriceRow extends StatelessWidget {
  final String label;
  final int paise;

  const _DetailPriceRow({required this.label, required this.paise});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text('₹${(paise / 100).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}
