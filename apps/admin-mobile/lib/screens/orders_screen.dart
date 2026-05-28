import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../models/admin_order.dart';
import '../state/providers.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final List<Map<String, String>> _statusFilters = [
    {'label': 'All', 'value': 'all'},
    {'label': 'Pending', 'value': 'pending'},
    {'label': 'Assigned', 'value': 'agent_assigned'},
    {'label': 'Delivered', 'value': 'delivered'},
    {'label': 'Failed', 'value': 'failed'},
    {'label': 'Cancelled', 'value': 'cancelled'},
  ];

  int _selectedFilterIdx = 0;

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(ordersFeedProvider);

    return Scaffold(
      backgroundColor: BrandColors.creamBg,
      appBar: AppBar(
        title: const Text('Order Dispatch Center'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusFilters.length,
              itemBuilder: (context, idx) {
                final filter = _statusFilters[idx];
                final selected = _selectedFilterIdx == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      filter['label']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? Colors.white : BrandColors.primary,
                      ),
                    ),
                    selected: selected,
                    selectedColor: BrandColors.primary,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: BrandColors.creamBorder),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedFilterIdx = idx;
                        });
                        ref
                            .read(ordersFeedProvider.notifier)
                            .fetchOrders(status: filter['value']!);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by Order ID...',
                prefixIcon: const Icon(Icons.search, color: BrandColors.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: feedState.when(
              data: (orders) {
                final filtered = orders
                    .where((o) => o.orderCode.toLowerCase().contains(_searchQuery))
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No orders match this status.'
                            : 'No orders match your search.',
                        style: const TextStyle(color: BrandColors.textMuted),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(ordersFeedProvider.notifier).refresh();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final order = filtered[idx];
                      return _OrderCard(order: order);
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(BrandColors.accentOrange),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to fetch orders: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: BrandColors.textMuted),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(ordersFeedProvider.notifier).refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final AdminOrder order;

  const _OrderCard({required this.order});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return BrandColors.accentOrange;
      case 'agent_assigned':
      case 'agent_en_route_pickup':
      case 'parcel_collected':
      case 'out_for_delivery':
        return Colors.blue;
      case 'delivered':
        return BrandColors.accentGreen;
      case 'failed':
      case 'cancelled':
        return Colors.red;
      default:
        return BrandColors.textMuted;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Awaiting Agent';
      case 'agent_assigned':
        return 'Agent Assigned';
      case 'agent_en_route_pickup':
        return 'Agent En Route';
      case 'parcel_collected':
        return 'Collected';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);
    final statusLabel = _getStatusLabel(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: BrandColors.creamCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: BrandColors.creamBorder),
      ),
      elevation: 0,
      child: InkWell(
        onTap: () {
          context.go('/dashboard/orders/${order.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderCode,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: BrandColors.primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.orderType == 'send' ? '📤 Send Flow' : '📥 Receive Flow',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.accentOrange,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: BrandColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    order.userName ?? 'Customer',
                    style: const TextStyle(fontSize: 13, color: BrandColors.primary),
                  ),
                  const Spacer(),
                  Text(
                    '₹${(order.totalAmount / 100).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: BrandColors.primary,
                    ),
                  ),
                ],
              ),
              if (order.agentName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.directions_bike_outlined, size: 14, color: BrandColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Agent: ${order.agentName}',
                      style: const TextStyle(fontSize: 12, color: BrandColors.textMuted),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
