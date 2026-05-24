import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/order.dart';
import '../state/providers.dart';
import '../widgets/failure_sheet.dart';
import '../widgets/job_map.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const JobDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  final _otpCtrl = TextEditingController();
  bool _busy = false;
  String? _localError;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  bool _needsOtp(AgentOrder o) {
    if (o.orderType == OrderType.send) {
      return o.status == 'agent_en_route_pickup';
    }
    return o.status == 'out_for_delivery';
  }

  String? _nextStatus(AgentOrder o) {
    switch (o.status) {
      case 'agent_assigned':
        return 'agent_en_route_pickup';
      case 'agent_en_route_pickup':
        return 'parcel_collected';
      case 'parcel_collected':
        return 'out_for_delivery';
      case 'out_for_delivery':
        return 'delivered';
      default:
        return null;
    }
  }

  String _nextLabel(AgentOrder o) {
    switch (o.status) {
      case 'agent_assigned':
        return 'Start trip to pickup';
      case 'agent_en_route_pickup':
        return 'Parcel collected';
      case 'parcel_collected':
        return 'Start drop trip';
      case 'out_for_delivery':
        return o.orderType == OrderType.send
            ? 'Drop at courier office'
            : 'Hand over to customer';
      default:
        return 'Done';
    }
  }

  Future<void> _advance(AgentOrder o) async {
    final next = _nextStatus(o);
    if (next == null) return;
    if (_needsOtp(o) && _otpCtrl.text.length != 4) {
      setState(() => _localError = 'Enter the 4-digit OTP from the customer.');
      return;
    }
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await ref.read(agentServiceProvider).updateStatus(
            o.id,
            status: next,
            deliveryOtp: _needsOtp(o) ? _otpCtrl.text : null,
          );
      ref.invalidate(dashboardFeedProvider);
      if (next == 'delivered') {
        if (mounted) context.go('/dashboard');
        return;
      }
      _otpCtrl.clear();
    } catch (e) {
      if (mounted) {
        setState(() => _localError =
            humanizeError(e is String ? e : 'unexpected_error'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markFailed(AgentOrder o) async {
    final reason = await showFailureSheet(context);
    if (reason == null) return;
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await ref.read(agentServiceProvider).updateStatus(
            o.id,
            status: 'failed',
            failureReason: reason,
          );
      ref.invalidate(dashboardFeedProvider);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        setState(() => _localError =
            humanizeError(e is String ? e : 'unexpected_error'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadAuthorization(AgentOrder o) async {
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      final bytes =
          await ref.read(agentServiceProvider).downloadAuthorizationPdf(o.id);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/authorization-${o.orderCode}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        setState(() => _localError =
            'Could not open the PDF (${result.message}). It was saved to ${file.path}.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _localError =
            humanizeError(e is String ? e : 'unexpected_error'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(dashboardFeedProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _CenteredMessage(text: 'Failed to load: $e'),
        data: (snap) {
          AgentOrder? order;
          for (final o in snap.jobs.assigned) {
            if (o.id == widget.orderId) {
              order = o;
              break;
            }
          }
          if (order == null) {
            return const _CenteredMessage(
              text: 'This job is no longer in your active list.',
            );
          }
          return _Body(
            order: order,
            busy: _busy,
            localError: _localError,
            otpCtrl: _otpCtrl,
            needsOtp: _needsOtp(order),
            nextLabel: _nextLabel(order),
            canAdvance: _nextStatus(order) != null,
            onAdvance: () => _advance(order!),
            onFail: () => _markFailed(order!),
            onDownloadPdf: () => _downloadAuthorization(order!),
            onCall: _callPhone,
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final AgentOrder order;
  final bool busy;
  final String? localError;
  final TextEditingController otpCtrl;
  final bool needsOtp;
  final String nextLabel;
  final bool canAdvance;
  final VoidCallback onAdvance;
  final VoidCallback onFail;
  final VoidCallback onDownloadPdf;
  final void Function(String) onCall;

  const _Body({
    required this.order,
    required this.busy,
    required this.localError,
    required this.otpCtrl,
    required this.needsOtp,
    required this.nextLabel,
    required this.canAdvance,
    required this.onAdvance,
    required this.onFail,
    required this.onDownloadPdf,
    required this.onCall,
  });

  bool get _isSend => order.orderType == OrderType.send;
  bool get _dropIsActive =>
      order.status == 'parcel_collected' || order.status == 'out_for_delivery';

  LatLng? _ll(double? lat, double? lng) =>
      (lat == null || lng == null) ? null : LatLng(lat, lng);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Header(order: order),
        const SizedBox(height: 16),
        JobMap(
          pickup: _ll(order.pickupLat, order.pickupLng),
          pickupLabel: 'Pickup',
          drop: _ll(order.dropLat, order.dropLng),
          dropLabel: 'Drop',
          dropIsActive: _dropIsActive,
        ),
        const SizedBox(height: 14),
        _PickupCard(order: order),
        const SizedBox(height: 12),
        _DropCard(order: order, onCall: onCall),
        if (order.orderType == OrderType.receive &&
            (order.sourceTrackingId?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 12),
          _AuthorizationCard(
            trackingId: order.sourceTrackingId!,
            busy: busy,
            onDownload: onDownloadPdf,
          ),
        ],
        if (needsOtp) ...[
          const SizedBox(height: 14),
          _OtpInput(
            controller: otpCtrl,
            hint: _isSend
                ? 'Ask the customer for their OTP at pickup — required to confirm the parcel has changed hands.'
                : 'Ask the customer for their OTP at delivery — required to mark the parcel handed over.',
          ),
        ],
        if (localError != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(message: localError!),
        ],
        const SizedBox(height: 20),
        if (canAdvance)
          ElevatedButton(
            onPressed: busy ? null : onAdvance,
            child: Text(busy ? 'Working…' : nextLabel),
          ),
        if (order.status != 'agent_assigned') ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: busy ? null : onFail,
            style: OutlinedButton.styleFrom(
              foregroundColor: BrandColors.rose600,
              side: const BorderSide(color: Color(0xFFFDA4AF)),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Mark failed'),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final AgentOrder order;
  const _Header({required this.order});

  @override
  Widget build(BuildContext context) {
    final isSend = order.orderType == OrderType.send;
    final payout = (order.totalAmount / 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: BrandColors.brand.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSend
                            ? Icons.upload_rounded
                            : Icons.download_rounded,
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
                ),
                const SizedBox(height: 8),
                Text(
                  order.orderCode,
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.slate800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kStatusLabel[order.status] ?? order.status,
                  style: const TextStyle(
                    fontSize: 11,
                    color: BrandColors.slate500,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$payout',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: BrandColors.emeraldDark,
                ),
              ),
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
    );
  }
}

class _PickupCard extends StatelessWidget {
  final AgentOrder order;
  const _PickupCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isSend = order.orderType == OrderType.send;
    final title = isSend ? 'Customer pickup' : 'Courier branch pickup';
    final address =
        order.pickupText?.isNotEmpty == true ? order.pickupText! : 'Address pending';
    return _Card(
      title: title,
      iconColor: BrandColors.emeraldDark,
      icon: Icons.place_outlined,
      children: [
        _AddressLine(address),
        if (!isSend && (order.sourceTrackingId?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 8),
          _KeyValue('Tracking ID', order.sourceTrackingId!),
        ],
        if (order.parcelDescription?.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          _KeyValue('Item', order.parcelDescription!),
        ],
      ],
    );
  }
}

class _DropCard extends StatelessWidget {
  final AgentOrder order;
  final void Function(String) onCall;
  const _DropCard({required this.order, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final isSend = order.orderType == OrderType.send;
    final title = isSend ? 'Courier branch drop' : 'Customer drop';
    final address = order.dropText?.isNotEmpty == true
        ? order.dropText!
        : (order.deliveryAddress ?? 'Address pending');

    return _Card(
      title: title,
      icon: Icons.flag_outlined,
      iconColor: BrandColors.rose600,
      children: [
        if (isSend && (order.selectedCourierName?.isNotEmpty ?? false)) ...[
          _KeyValue('Courier', order.selectedCourierName!),
          const SizedBox(height: 8),
        ],
        if (isSend && (order.dropBranchName?.isNotEmpty ?? false)) ...[
          _KeyValue('Branch', order.dropBranchName!),
          const SizedBox(height: 8),
        ],
        _AddressLine(address),
        if (isSend && (order.dropBranchHours?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 8),
          _KeyValue('Hours', order.dropBranchHours!),
        ],
        if (isSend && (order.dropBranchPhone?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 10),
          _CallChip(
            label: 'Call office',
            phone: order.dropBranchPhone!,
            onCall: onCall,
          ),
        ],
        if (!isSend && (order.recipientPhone?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 10),
          _CallChip(
            label: 'Call recipient',
            phone: order.recipientPhone!,
            onCall: onCall,
          ),
        ],
      ],
    );
  }
}

class _AuthorizationCard extends StatelessWidget {
  final String trackingId;
  final bool busy;
  final VoidCallback onDownload;
  const _AuthorizationCard({
    required this.trackingId,
    required this.busy,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Authorization letter',
      icon: Icons.description_outlined,
      iconColor: BrandColors.brand,
      children: [
        _KeyValue('Tracking ID', trackingId),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : onDownload,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Download authorization letter'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            side: const BorderSide(color: BrandColors.slate200),
            foregroundColor: BrandColors.slate800,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  const _Card({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.slate500,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _AddressLine extends StatelessWidget {
  final String text;
  const _AddressLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: BrandColors.slate800,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;
  const _KeyValue(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: BrandColors.slate400,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BrandColors.slate700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CallChip extends StatelessWidget {
  final String label;
  final String phone;
  final void Function(String) onCall;
  const _CallChip({
    required this.label,
    required this.phone,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onCall(phone),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: BrandColors.brand.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone, size: 14, color: BrandColors.brand),
            const SizedBox(width: 6),
            Text(
              '$label · $phone',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: BrandColors.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _OtpInput({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandColors.amber50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.amber200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '4-DIGIT OTP FROM CUSTOMER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: BrandColors.amber700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              fontFamily: 'Menlo',
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '0000',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: BrandColors.amber200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: BrandColors.amber200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: BrandColors.amber700, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: const TextStyle(
              fontSize: 12,
              color: BrandColors.amber700,
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

class _CenteredMessage extends StatelessWidget {
  final String text;
  const _CenteredMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: BrandColors.slate600,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
