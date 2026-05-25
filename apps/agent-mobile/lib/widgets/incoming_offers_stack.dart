import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/chime.dart';
import '../core/theme.dart';
import '../models/order.dart';
import '../state/providers.dart';
import 'incoming_offer_card.dart';

class IncomingOffersStack extends ConsumerStatefulWidget {
  final List<AgentOrder> offered;
  const IncomingOffersStack({super.key, required this.offered});

  @override
  ConsumerState<IncomingOffersStack> createState() =>
      _IncomingOffersStackState();
}

class _IncomingOffersStackState extends ConsumerState<IncomingOffersStack> {
  // Server contract: dispatcher mints offers with a 30s TTL.
  static const int _defaultTotalSeconds = 30;
  static const Duration _swipeDuration = Duration(milliseconds: 320);

  final Set<String> _seen = <String>{};
  Timer? _ticker;
  int _timeLeft = _defaultTotalSeconds;
  int _totalSeconds = _defaultTotalSeconds;
  String? _trackedTopId;

  /// While an accept/skip animation is running we hide the card.
  ({String id, _SwipeDirection direction})? _swiping;

  @override
  void initState() {
    super.initState();
    _bootstrapSeen(widget.offered);
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant IncomingOffersStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeChime(widget.offered);
    _syncTimer();
    // Drop dismissed entries that the server no longer returns.
    final ids = widget.offered.map((o) => o.id).toSet();
    ref.read(dismissedOffersProvider.notifier).prune(ids);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _bootstrapSeen(List<AgentOrder> offers) {
    // On first render don't fire chime for already-present offers.
    for (final o in offers) {
      _seen.add(o.id);
    }
  }

  void _maybeChime(List<AgentOrder> offers) {
    final dismissed = ref.read(dismissedOffersProvider);
    var fresh = false;
    for (final o in offers) {
      if (dismissed.contains(o.id)) continue;
      if (_seen.add(o.id)) fresh = true;
    }
    if (fresh) {
      OfferChime().play();
    }
  }

  List<AgentOrder> get _visible {
    final dismissed = ref.watch(dismissedOffersProvider);
    return widget.offered
        .where((o) => !dismissed.contains(o.id) && _swiping?.id != o.id)
        .toList(growable: false);
  }

  void _syncTimer() {
    final visible = widget.offered
        .where((o) => !ref.read(dismissedOffersProvider).contains(o.id))
        .toList();
    final top = visible.isNotEmpty ? visible.first : null;
    final topId = top?.id;
    if (topId == _trackedTopId) return;
    _trackedTopId = topId;
    _ticker?.cancel();
    if (topId == null) {
      setState(() => _timeLeft = _defaultTotalSeconds);
      return;
    }
    final expires = top!.offerExpiresAt;
    final initial = expires != null
        ? expires.difference(DateTime.now()).inSeconds.clamp(0, 600)
        : _defaultTotalSeconds;
    setState(() {
      // Use the larger of remaining vs default for the progress denominator so
      // a stale-cached offer doesn't render as already-full.
      _totalSeconds = initial > _defaultTotalSeconds ? initial : _defaultTotalSeconds;
      _timeLeft = initial;
    });
    if (initial <= 0) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeLeft -= 1);
      if (_timeLeft <= 0) {
        _ticker?.cancel();
        // Server will auto-expire on its sweep; locally just hide the card.
        ref.read(dismissedOffersProvider.notifier).dismiss(topId);
      }
    });
  }

  Future<void> _accept(String id) async {
    if (_swiping != null) return;
    setState(() => _swiping = (id: id, direction: _SwipeDirection.right));
    await Future.delayed(_swipeDuration);
    try {
      await ref.read(agentServiceProvider).acceptJob(id);
      // Refresh dashboard so this lands in "assigned" immediately.
      ref.invalidate(dashboardFeedProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(humanizeError(e is String ? e : 'unexpected_error')),
            backgroundColor: BrandColors.rose600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _swiping = null);
    }
  }

  Future<void> _skip(String id) async {
    if (_swiping != null && _swiping!.id != id) return;
    setState(() => _swiping = (id: id, direction: _SwipeDirection.left));
    // Fire decline server-side so the dispatcher can re-offer to another agent.
    // Hide locally regardless so the UI feels immediate.
    Future<void> serverDecline() async {
      try {
        await ref.read(agentServiceProvider).declineJob(id);
      } catch (_) {
        // Best-effort: TTL sweep will reclaim if the call fails.
      }
    }

    unawaited(serverDecline());
    Future.delayed(_swipeDuration, () {
      if (!mounted) return;
      ref.read(dismissedOffersProvider.notifier).dismiss(id);
      setState(() => _swiping = null);
      ref.invalidate(dashboardFeedProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    if (visible.isEmpty && _swiping == null) {
      return const _EmptyState(
        icon: Icons.radar,
        title: 'Scanning Thrissur…',
        subtitle: 'New jobs will appear here automatically.',
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final stackHeight = 320.0;
        return SizedBox(
          height: stackHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final entry in _layered(visible).reversed) entry,
              if (_swiping != null) _swipingCard(),
            ],
          ),
        );
      },
    );
  }

  /// Build cards back-to-front. We paint reversed so the top card draws last.
  List<Widget> _layered(List<AgentOrder> visible) {
    final out = <Widget>[];
    final maxShown = visible.length.clamp(0, 3);
    for (var i = 0; i < maxShown; i++) {
      final order = visible[i];
      final isTop = i == 0;
      final scale = 1.0 - (i * 0.04);
      final yOffset = i * 12.0;
      out.add(
        Positioned(
          key: ValueKey('offer-${order.id}'),
          top: yOffset,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !isTop,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: 1.0 - (i * 0.18),
                child: IncomingOfferCard(
                  order: order,
                  isTop: isTop,
                  timeLeftSeconds: _timeLeft,
                  totalSeconds: _totalSeconds,
                  onAccept: () => _accept(order.id),
                  onSkip: () => _skip(order.id),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return out;
  }

  Widget _swipingCard() {
    final s = _swiping!;
    final order = widget.offered.firstWhere(
      (o) => o.id == s.id,
      orElse: () => widget.offered.first,
    );
    final dx = s.direction == _SwipeDirection.left ? -1.4 : 1.4;
    final rotation = s.direction == _SwipeDirection.left ? -0.25 : 0.25;
    return Positioned.fill(
      child: AnimatedSlide(
        duration: _swipeDuration,
        curve: Curves.easeInQuad,
        offset: Offset(dx, 0.05),
        child: AnimatedRotation(
          duration: _swipeDuration,
          curve: Curves.easeInQuad,
          turns: rotation,
          child: AnimatedOpacity(
            duration: _swipeDuration,
            opacity: 0,
            child: IncomingOfferCard(
              order: order,
              isTop: true,
              timeLeftSeconds: _timeLeft,
              totalSeconds: _totalSeconds,
              onAccept: () {},
              onSkip: () {},
            ),
          ),
        ),
      ),
    );
  }
}

enum _SwipeDirection { left, right }

class _EmptyState extends StatelessWidget {
  final IconData icon;
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
          Icon(icon, size: 28, color: BrandColors.slate400),
          const SizedBox(height: 8),
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
