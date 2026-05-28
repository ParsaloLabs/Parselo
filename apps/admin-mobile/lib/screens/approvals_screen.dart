import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/pending_agent.dart';
import '../state/providers.dart';

class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> {
  bool _actionBusy = false;
  String? _error;

  Future<void> _approve(String id) async {
    setState(() {
      _actionBusy = true;
      _error = null;
    });
    try {
      await ref.read(pendingAgentsProvider.notifier).approveAgent(id);
    } catch (e) {
      setState(() {
        _error = humanizeError(extractErrorCode(e));
      });
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _reject(String id) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter reason for rejecting this agent application:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Expired driving licence',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: BrandColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || reasonController.text.trim().isEmpty) return;

    setState(() {
      _actionBusy = true;
      _error = null;
    });

    try {
      await ref
          .read(pendingAgentsProvider.notifier)
          .rejectAgent(id, reasonController.text.trim());
    } catch (e) {
      setState(() {
        _error = humanizeError(extractErrorCode(e));
      });
    } finally {
      reasonController.dispose();
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingState = ref.watch(pendingAgentsProvider);

    return Scaffold(
      backgroundColor: BrandColors.creamBg,
      appBar: AppBar(
        title: const Text('Agent Registrations'),
      ),
      body: Column(
        children: [
          if (_error != null) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
              ),
            ),
          ],
          Expanded(
            child: pendingState.when(
              data: (agents) {
                final pendingList = agents.where((a) => a.status == 'pending').toList();
                if (pendingList.isEmpty) {
                  return const Center(
                    child: Text(
                      'No pending applications to review.',
                      style: TextStyle(color: BrandColors.textMuted),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(pendingAgentsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: pendingList.length,
                    itemBuilder: (context, idx) {
                      final agent = pendingList[idx];
                      return _AgentCurationCard(
                        agent: agent,
                        actionBusy: _actionBusy,
                        onApprove: () => _approve(agent.id),
                        onReject: () => _reject(agent.id),
                      );
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
                        'Failed to fetch agents: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: BrandColors.textMuted),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(pendingAgentsProvider),
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

class _AgentCurationCard extends StatelessWidget {
  final PendingAgent agent;
  final bool actionBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _AgentCurationCard({
    required this.agent,
    required this.actionBusy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: BrandColors.creamCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: BrandColors.creamBorder),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              agent.fullName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BrandColors.primary),
            ),
            const SizedBox(height: 4),
            Text(
              'Phone: ${agent.phone} · City: ${agent.city ?? "Thrissur"}',
              style: const TextStyle(fontSize: 13, color: BrandColors.textMuted),
            ),
            const Divider(height: 24, color: BrandColors.creamBorder),
            
            // Details Row
            _CurationRow(label: 'License number', value: agent.dlNumber ?? '—'),
            _CurationRow(label: 'Vehicle plate', value: agent.vehicleNumber ?? '—'),
            _CurationRow(label: 'Vehicle type', value: agent.vehicleType?.toUpperCase() ?? '—'),
            const SizedBox(height: 20),
            
            // Buttons Grid
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: actionBusy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Reject', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: actionBusy ? null : onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BrandColors.accentGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CurationRow extends StatelessWidget {
  final String label;
  final String value;

  const _CurationRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: BrandColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BrandColors.primary)),
        ],
      ),
    );
  }
}
