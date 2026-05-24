import 'package:flutter/material.dart';

import '../core/theme.dart';

const List<String> kFailureReasons = [
  'Customer not reachable / no-show',
  'Wrong address',
  'Parcel rejected by courier office',
  'Parcel damaged or unsafe to handle',
  'Other',
];

/// Bottom-sheet that asks why a delivery failed. Returns the formatted reason
/// string on submit, or null on cancel. Mirrors the agent-web FAILURE_REASONS
/// list verbatim.
Future<String?> showFailureSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _FailureSheet(),
  );
}

class _FailureSheet extends StatefulWidget {
  @override
  State<_FailureSheet> createState() => _FailureSheetState();
}

class _FailureSheetState extends State<_FailureSheet> {
  String? _reason;
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_reason == null) return false;
    if (_reason == 'Other' && _notes.text.trim().isEmpty) return false;
    return !_busy;
  }

  String _formatted() {
    final notes = _notes.text.trim();
    if (_reason == 'Other') return notes.isEmpty ? 'Other' : notes;
    return notes.isEmpty ? _reason! : '${_reason!} — $notes';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: BrandColors.slate200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Why did this fail?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: BrandColors.slate800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Admin will review failed orders.',
                    style: TextStyle(
                      fontSize: 12,
                      color: BrandColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                children: [
                  for (final r in kFailureReasons) _option(r),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: _reason == 'Other'
                          ? 'Required: describe what happened'
                          : 'Optional details',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: BrandColors.slate200),
                        foregroundColor: BrandColors.slate700,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSubmit
                          ? () {
                              setState(() => _busy = true);
                              Navigator.pop(context, _formatted());
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.rose600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        disabledBackgroundColor: BrandColors.slate200,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_busy ? 'Submitting…' : 'Mark failed'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(String r) {
    final selected = _reason == r;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _reason = r),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? BrandColors.rose50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFDA4AF)
                  : BrandColors.slate200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? BrandColors.rose600 : BrandColors.slate400,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? BrandColors.rose600
                        : BrandColors.slate700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
