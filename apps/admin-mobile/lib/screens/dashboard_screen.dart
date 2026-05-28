import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../state/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsStream = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: BrandColors.creamBg,
      appBar: AppBar(
        title: const Text('parsalo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: BrandColors.primary),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Do you want to log out from operations?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel', style: TextStyle(color: BrandColors.textMuted)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(authStateProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
      body: statsStream.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Operations Overview',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                // KPI Cards Grid
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.4,
                  children: [
                    _KpiCard(
                      title: "Today's Revenue",
                      value: "₹${(stats.revenueTodayPaise / 100).toStringAsFixed(0)}",
                      color: BrandColors.accentGreen,
                      icon: Icons.currency_rupee_outlined,
                    ),
                    _KpiCard(
                      title: "Today's Orders",
                      value: stats.ordersToday.toString(),
                      color: BrandColors.accentOrange,
                      icon: Icons.shopping_bag_outlined,
                    ),
                    _KpiCard(
                      title: "Active Orders",
                      value: stats.activeOrders.toString(),
                      color: Colors.blue,
                      icon: Icons.local_shipping_outlined,
                    ),
                    _KpiCard(
                      title: "Agents Online",
                      value: stats.agentsOnline.toString(),
                      color: Colors.purple,
                      icon: Icons.people_outline,
                    ),
                    _KpiCard(
                      title: "Failed Jobs",
                      value: stats.failedCount.toString(),
                      color: Colors.red,
                      icon: Icons.error_outline_outlined,
                      highlight: stats.failedCount > 0,
                    ),
                    _KpiCard(
                      title: "Refund Requests",
                      value: stats.refundRequestedCount.toString(),
                      color: Colors.amber.shade700,
                      icon: Icons.replay_outlined,
                      highlight: stats.refundRequestedCount > 0,
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: BrandColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Quick Action Cards
                _ActionCard(
                  title: 'Order Dispatch Center',
                  subtitle: 'View global orders, manage assignments & retry failures',
                  icon: Icons.list_alt_outlined,
                  color: Colors.blue,
                  onTap: () => context.go('/dashboard/orders'),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  title: 'Agent Registrations',
                  subtitle: 'Approve or reject pending delivery agent applications',
                  icon: Icons.verified_user_outlined,
                  color: BrandColors.accentGreen,
                  onTap: () => context.go('/dashboard/approvals'),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  title: 'Dispatch & Settings',
                  subtitle: 'Tune initial search radius and per-offer duration',
                  icon: Icons.settings_outlined,
                  color: BrandColors.accentOrange,
                  onTap: () => context.go('/dashboard/settings'),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 120.0),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(BrandColors.accentOrange),
            ),
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 120.0, left: 24, right: 24),
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Dashboard load failed: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BrandColors.textMuted),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(dashboardStatsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final bool highlight;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandColors.creamCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? Colors.red.shade300 : BrandColors.creamBorder,
          width: highlight ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0E1726),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.textMuted,
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: highlight ? Colors.red.shade900 : BrandColors.primary,
              letterSpacing: -1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BrandColors.creamCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BrandColors.creamBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x050E1726),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: BrandColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: BrandColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: BrandColors.creamBorder),
          ],
        ),
      ),
    );
  }
}
