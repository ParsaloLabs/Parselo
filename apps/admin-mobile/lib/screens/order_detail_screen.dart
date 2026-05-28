import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/admin_order.dart';
import '../models/pending_agent.dart';
import '../state/providers.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _actionBusy = false;
  String? _error;

  Future<void> _load() async {
    ref.invalidate(ordersFeedProvider);
  }

  Future<void> _assignAgent(ApprovedAgent agent) async {
    setState(() {
      _actionBusy = true;
      _error = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      await client.dio.post('/admin/orders/${widget.orderId}/assign-agent', data: {
        'agent_id': agent.id,
      });
      await _load();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = humanizeError(extractErrorCode(e));
      });
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _processRefund() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Refund'),
        content: const Text('Do you want to process a full refund for this failed order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: BrandColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Refund', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _actionBusy = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      await client.dio.post('/admin/orders/${widget.orderId}/refund');
      await _load();
    } catch (e) {
      setState(() {
        _error = humanizeError(extractErrorCode(e));
      });
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _retryOrder(String when) async {
    setState(() {
      _actionBusy = true;
      _error = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      await client.dio.post('/admin/orders/${widget.orderId}/retry', data: {'when': when});
      await _load();
    } catch (e) {
      setState(() {
        _error = humanizeError(extractErrorCode(e));
      });
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _showAssignmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final agentsState = ref.watch(approvedAgentsProvider);
            return agentsState.when(
              data: (agents) {
                final onlineAgents = agents.where((a) => a.isOnline).toList();
                if (onlineAgents.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'No agents are online right now.',
                        style: TextStyle(color: BrandColors.textMuted),
                      ),
                    ),
                  );
                }
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Assign Delivery Agent',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BrandColors.primary),
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: onlineAgents.length,
                          itemBuilder: (context, idx) {
                            final agent = onlineAgents[idx];
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: BrandColors.creamBg,
                                child: Icon(Icons.person, color: BrandColors.primary),
                              ),
                              title: Text(agent.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('⭐ ${agent.rating.toStringAsFixed(1)} · ${agent.vehicleType ?? "bike"}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _actionBusy ? null : () => _assignAgent(agent),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => SizedBox(
                height: 200,
                child: Center(child: Text('Error loading agents: $err')),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(ordersFeedProvider);
    
    // Extract this specific order from the cached list
    AdminOrder? order;
    feedState.whenData((orders) {
      try {
        order = orders.firstWhere((o) => o.id == widget.orderId);
      } catch (_) {}
    });

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: Text('Order not found.')),
      );
    }

    final o = order!;
    final isFailed = o.status == 'failed';
    final isPaid = o.paymentStatus == 'paid';
    final isRefundRequested = o.paymentStatus == 'refund_requested';

    return Scaffold(
      backgroundColor: BrandColors.creamBg,
      appBar: AppBar(
        title: Text(o.orderCode),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],

            // Main Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: BrandColors.creamCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BrandColors.creamBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        o.orderType == 'send' ? '📤 Send Order' : '📥 Receive Order',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: BrandColors.accentOrange),
                      ),
                      Text(
                        '₹${(o.totalAmount / 100).toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: BrandColors.primary),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: BrandColors.creamBorder),
                  _DetailRow(label: 'Customer', value: o.userName ?? '—'),
                  _DetailRow(label: 'Customer Phone', value: o.userPhone ?? '—'),
                  _DetailRow(label: 'Payment Status', value: o.paymentStatus.toUpperCase()),
                  if (o.agentName != null) ...[
                    _DetailRow(label: 'Assigned Agent', value: o.agentName!),
                  ],
                  if (o.deliveryOtp != null) ...[
                    _DetailRow(label: 'Handover OTP', value: o.deliveryOtp!),
                  ],
                  if (o.failureReason != null) ...[
                    const Divider(height: 24, color: BrandColors.creamBorder),
                    Text(
                      'Failure Reason:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      o.failureReason!,
                      style: const TextStyle(fontSize: 13, color: BrandColors.primary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Triggers Gated by order state
            if (o.status == 'pending' && isPaid) ...[
              ElevatedButton(
                onPressed: _actionBusy ? null : _showAssignmentSheet,
                child: const Text('Assign Delivery Agent'),
              ),
              const SizedBox(height: 24),
            ],

            if (isFailed && (isPaid || isRefundRequested)) ...[
              const Text(
                'Operational Recovery Options',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: BrandColors.primary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _actionBusy ? null : () => _retryOrder('today'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: BrandColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Retry Today', style: TextStyle(color: BrandColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _actionBusy ? null : () => _retryOrder('tomorrow'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: BrandColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Retry Tomorrow', style: TextStyle(color: BrandColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _actionBusy ? null : _processRefund,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Process Full Refund'),
              ),
              const SizedBox(height: 24),
            ],

            // Order Flow Addresses
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: BrandColors.creamCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BrandColors.creamBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Routing Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: BrandColors.primary)),
                  const Divider(height: 20, color: BrandColors.creamBorder),
                  if (o.orderType == 'send') ...[
                    _RouteNode(title: 'Pickup Origin (Home/Office)', address: o.deliveryAddress ?? '—'),
                    const SizedBox(height: 16),
                    _RouteNode(title: 'Recipient Handover Context', address: '${o.recipientName} (${o.recipientPhone})'),
                  ] else ...[
                    _RouteNode(title: 'Pickup Origin (Courier Office)', address: o.parcelDescription ?? 'Courier branch drop'),
                    const SizedBox(height: 16),
                    _RouteNode(title: 'Delivery Address (Customer Drop)', address: o.deliveryAddress ?? '—'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // History Log
            if (o.history.isNotEmpty) ...[
              const Text('Activity Timeline', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: BrandColors.primary)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: BrandColors.creamCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BrandColors.creamBorder),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: o.history.length,
                  itemBuilder: (context, idx) {
                    final h = o.history[o.history.length - 1 - idx];
                    final date = DateTime.parse(h.createdAt).toLocal();
                    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: BrandColors.accentGreen),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  h.status.replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BrandColors.primary),
                                ),
                                if (h.notes != null) ...[
                                  const SizedBox(height: 2),
                                  Text(h.notes!, style: const TextStyle(fontSize: 12, color: BrandColors.textMuted)),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  '$formattedDate · ${h.changedByType.toUpperCase()}',
                                  style: const TextStyle(fontSize: 10, color: BrandColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: BrandColors.textMuted)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BrandColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteNode extends StatelessWidget {
  final String title;
  final String address;

  const _RouteNode({required this.title, required this.address});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BrandColors.textMuted)),
        const SizedBox(height: 4),
        Text(address, style: const TextStyle(fontSize: 13, color: BrandColors.primary, height: 1.4)),
      ],
    );
  }
}
