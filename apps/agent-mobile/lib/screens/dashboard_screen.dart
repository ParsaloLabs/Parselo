import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../state/providers.dart';
import '../widgets/assigned_job_tile.dart';
import '../widgets/incoming_offers_stack.dart';
import '../widgets/online_toggle.dart';
import '../widgets/profits_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(agentProfileProvider);
    final feedAsync = ref.watch(dashboardFeedProvider);
    final online = ref.watch(onlineStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Parsalo Agent',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_outlined,
                color: BrandColors.slate600),
            onPressed: () => context.push('/dashboard/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardFeedProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OnlineToggleCard(),
              const SizedBox(height: 16),
              profileAsync.when(
                data: (_) => const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (e, _) => _ErrorBanner(message: 'Profile: $e'),
              ),
              feedAsync.when(
                loading: () => const _LoadingState(),
                error: (e, _) => _ErrorBanner(message: 'Feed: $e'),
                data: (snap) => _Body(snapshot: snap, online: online),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final DashboardSnapshot snapshot;
  final bool online;
  const _Body({required this.snapshot, required this.online});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfitsCard(profits: snapshot.profits),
        const SizedBox(height: 24),
        _SectionLabel('Assigned tasks (${snapshot.jobs.assigned.length})'),
        const SizedBox(height: 10),
        if (snapshot.jobs.assigned.isEmpty)
          const _EmptyState(
            icon: '📦',
            title: 'No assigned deliveries.',
            subtitle: 'Ready for the next order.',
          )
        else
          Column(
            children: [
              for (final order in snapshot.jobs.assigned) ...[
                AssignedJobTile(
                  order: order,
                  onTap: () {
                    // Job detail comes in Phase 4.
                  },
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        const SizedBox(height: 24),
        _SectionLabel('Incoming offers (${snapshot.jobs.available.length})'),
        const SizedBox(height: 10),
        if (!online)
          const _EmptyState(
            icon: '📴',
            title: 'You are offline.',
            subtitle:
                'Switch on duty to start receiving offers in your area.',
          )
        else
          IncomingOffersStack(available: snapshot.jobs.available),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: BrandColors.slate400,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: BrandColors.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.slate200),
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: BrandColors.slate700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: BrandColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrandColors.rose50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: BrandColors.rose600, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: BrandColors.rose600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
