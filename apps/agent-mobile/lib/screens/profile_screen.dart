import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/agent_profile.dart';
import '../models/order.dart';
import '../state/providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _pageSize = 30;

  final _scroll = ScrollController();
  final List<AgentOrder> _orders = [];
  int _total = 0;
  bool _loadingFirst = true;
  bool _loadingMore = false;
  String? _error;
  String _filter = 'all'; // all | delivered | failed

  @override
  void initState() {
    super.initState();
    _loadFirst();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore) return;
    if (_orders.length >= _total) return;
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    final svc = ref.read(agentServiceProvider);
    setState(() {
      _loadingFirst = true;
      _error = null;
    });
    try {
      final res = await svc.getHistory(limit: _pageSize, offset: 0);
      setState(() {
        _orders
          ..clear()
          ..addAll(res.orders);
        _total = res.total;
      });
    } catch (e) {
      setState(() => _error = humanizeError(e.toString()));
    } finally {
      if (mounted) setState(() => _loadingFirst = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final svc = ref.read(agentServiceProvider);
    try {
      final res = await svc.getHistory(
        limit: _pageSize,
        offset: _orders.length,
      );
      setState(() {
        _orders.addAll(res.orders);
        _total = res.total;
      });
    } catch (_) {
      // Silent — user can pull-to-refresh
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<AgentOrder> get _filtered {
    if (_filter == 'all') return _orders;
    return _orders.where((o) => o.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(agentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout, color: BrandColors.slate600),
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(agentProfileProvider);
          await _loadFirst();
        },
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            profileAsync.when(
              data: (p) => _Header(profile: p),
              loading: () => const _HeaderSkeleton(),
              error: (e, _) => Text('Could not load profile: $e'),
            ),
            const SizedBox(height: 20),
            const Text(
              'JOB HISTORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: BrandColors.slate400,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            _FilterRow(
              value: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 12),
            if (_loadingFirst)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else if (_error != null)
              _ErrorBanner(message: _error!)
            else if (_filtered.isEmpty)
              const _EmptyHistory()
            else
              ..._filtered.map((o) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistoryTile(order: o),
                  )),
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AgentProfile profile;
  const _Header({required this.profile});

  @override
  Widget build(BuildContext context) {
    final initials = profile.fullName.isEmpty
        ? '·'
        : profile.fullName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((s) => s[0].toUpperCase())
            .join();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.slate200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [BrandColors.brandDark, BrandColors.brand],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName.isEmpty
                          ? 'Delivery Partner'
                          : profile.fullName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: BrandColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.phone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: BrandColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(label: 'Deliveries', value: '${profile.totalDeliveries}'),
              const SizedBox(width: 8),
              _Stat(label: 'Rating', value: profile.rating.toStringAsFixed(1)),
              const SizedBox(width: 8),
              _Stat(
                label: 'Vehicle',
                value: profile.vehicleType ?? '—',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: BrandColors.slate50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: BrandColors.slate900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: BrandColors.slate400,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.slate200),
      ),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(strokeWidth: 2.5),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _FilterRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      ('all', 'All'),
      ('delivered', 'Delivered'),
      ('failed', 'Failed'),
      ('cancelled', 'Cancelled'),
    ];
    return Wrap(
      spacing: 8,
      children: [
        for (final (key, label) in tabs)
          ChoiceChip(
            label: Text(label),
            selected: value == key,
            onSelected: (_) => onChanged(key),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: value == key ? Colors.white : BrandColors.slate700,
            ),
            selectedColor: BrandColors.brand,
            backgroundColor: BrandColors.slate100,
            side: BorderSide.none,
            showCheckmark: false,
          ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final AgentOrder order;
  const _HistoryTile({required this.order});

  Color _statusColor() {
    switch (order.status) {
      case 'delivered':
        return BrandColors.emeraldDark;
      case 'failed':
        return BrandColors.rose600;
      case 'cancelled':
        return BrandColors.slate500;
      default:
        return BrandColors.brand;
    }
  }

  Color _statusBg() {
    switch (order.status) {
      case 'delivered':
        return BrandColors.emerald.withValues(alpha: 0.1);
      case 'failed':
        return BrandColors.rose50;
      case 'cancelled':
        return BrandColors.slate100;
      default:
        return BrandColors.brand.withValues(alpha: 0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderCode,
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusBg(),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  kStatusLabel[order.status] ?? order.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _statusColor(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                order.orderType == OrderType.send
                    ? Icons.upload
                    : Icons.download,
                size: 14,
                color: BrandColors.slate400,
              ),
              const SizedBox(width: 4),
              Text(
                order.orderType == OrderType.send ? 'Send' : 'Receive',
                style: const TextStyle(
                  fontSize: 11,
                  color: BrandColors.slate500,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '₹${(order.totalAmount / 100).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: BrandColors.slate900,
                ),
              ),
              const Spacer(),
              if (order.updatedAt != null)
                Text(
                  _formatDate(order.updatedAt!),
                  style: const TextStyle(
                    fontSize: 11,
                    color: BrandColors.slate400,
                  ),
                ),
            ],
          ),
          if (order.failureReason != null) ...[
            const SizedBox(height: 6),
            Text(
              order.failureReason!,
              style: const TextStyle(
                fontSize: 11,
                color: BrandColors.rose600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
      decoration: BoxDecoration(
        color: BrandColors.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.slate200),
      ),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Text('📭', style: TextStyle(fontSize: 28)),
          SizedBox(height: 6),
          Text(
            'No past jobs yet.',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: BrandColors.slate700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Completed and cancelled jobs will show up here.',
            style: TextStyle(
              fontSize: 11,
              color: BrandColors.slate500,
            ),
          ),
        ],
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
