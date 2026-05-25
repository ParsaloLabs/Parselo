import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/profits.dart';

class ProfitsCard extends StatefulWidget {
  final Profits profits;
  const ProfitsCard({super.key, required this.profits});

  @override
  State<ProfitsCard> createState() => _ProfitsCardState();
}

class _ProfitsCardState extends State<ProfitsCard> {
  bool _expanded = false;
  late DateTime _monthAnchor;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthAnchor = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final inr = NumberFormat.decimalPattern('en_IN');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BrandColors.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: BrandColors.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        '₹',
                        style: TextStyle(
                          color: BrandColors.emeraldDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL PROFITS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: BrandColors.slate400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${inr.format(widget.profits.totalProfits)}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: BrandColors.slate900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: BrandColors.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _expanded ? 'Hide' : 'Calendar',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: BrandColors.brand,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                          color: BrandColors.brand,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: BrandColors.slate100),
                const SizedBox(height: 16),
                _calendar(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _calendar() {
    final year = _monthAnchor.year;
    final month = _monthAnchor.month;
    final firstWeekday = DateTime(year, month, 1).weekday % 7; // 0 = Sun
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final months = const [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Earnings · ${months[month - 1]} $year',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: BrandColors.slate800,
                ),
              ),
            ),
            _arrowButton(
              icon: Icons.chevron_left,
              onTap: () => setState(() {
                _monthAnchor = DateTime(year, month - 1, 1);
              }),
            ),
            const SizedBox(width: 6),
            _arrowButton(
              icon: Icons.chevron_right,
              onTap: () => setState(() {
                _monthAnchor = DateTime(year, month + 1, 1);
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            _DayLabel('Sun'), _DayLabel('Mon'), _DayLabel('Tue'),
            _DayLabel('Wed'), _DayLabel('Thu'), _DayLabel('Fri'),
            _DayLabel('Sat'),
          ],
        ),
        const SizedBox(height: 6),
        _grid(year, month, firstWeekday, daysInMonth),
      ],
    );
  }

  Widget _arrowButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: BrandColors.slate100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: BrandColors.slate700),
        ),
      ),
    );
  }

  Widget _grid(int year, int month, int firstWeekday, int daysInMonth) {
    final cells = <Widget>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const _EmptyCell());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final key =
          '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final amt = widget.profits.dailyProfits[key] ?? 0;
      cells.add(_DayCell(day: d, amount: amt));
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: cells,
    );
  }
}

class _DayLabel extends StatelessWidget {
  final String text;
  const _DayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: BrandColors.slate400,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BrandColors.slate50,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final int amount;
  const _DayCell({required this.day, required this.amount});

  @override
  Widget build(BuildContext context) {
    final hasProfit = amount > 0;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: hasProfit
            ? BrandColors.emerald.withValues(alpha: 0.10)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasProfit
              ? BrandColors.emerald.withValues(alpha: 0.35)
              : BrandColors.slate100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color:
                  hasProfit ? BrandColors.emeraldDark : BrandColors.slate400,
            ),
          ),
          if (hasProfit)
            const Spacer()
          else
            const SizedBox.shrink(),
          if (hasProfit)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomCenter,
              child: Text(
                '₹$amount',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: BrandColors.emeraldDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
