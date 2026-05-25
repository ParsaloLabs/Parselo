import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/brand_button.dart';
import '../../../core/widgets/glass_card.dart';

int _parseInt(dynamic val) {
  if (val == null) return 0;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? double.tryParse(val)?.toInt() ?? 0;
  return 0;
}

class PaymentScreen extends StatefulWidget {
  final String orderId;

  const PaymentScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  
  // Payment info DTO
  bool _devMode = true;
  int _amount = 0;
  String _orderCode = '';
  String _currency = 'INR';

  @override
  void initState() {
    super.initState();
    _fetchPaymentDetails();
  }

  Future<void> _fetchPaymentDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiClient.request(
        '/payments/orders/${widget.orderId}/create',
        method: 'POST',
      );
      
      if (mounted) {
        setState(() {
          _devMode = res['dev_mode'] ?? true;
          _amount = _parseInt(res['amount']);
          _orderCode = res['order_code'] ?? '';
          _currency = res['currency'] ?? 'INR';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _payDev() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ApiClient.request(
        '/payments/verify',
        method: 'POST',
        body: {'parsalo_order_id': widget.orderId},
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment marked successful!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Go back to Home / order details
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : e.toString();
          _busy = false;
        });
      }
    }
  }

  Future<void> _payRealMock() async {
    setState(() {
      _busy = true;
    });
    
    // Simulate premium Razorpay loading sheet
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.payment_rounded, color: AppColors.brand, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Razorpay Secure',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const Text(
                    'TEST MODE',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(color: AppColors.border, height: 28),
              
              Text(
                _orderCode,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${(_amount / 100).toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 32, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),
              
              const Text('Select Payment Option', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              
              _PayMethodItem(icon: Icons.qr_code_scanner_rounded, title: 'Google Pay / PhonePe UPI'),
              const SizedBox(height: 10),
              _PayMethodItem(icon: Icons.credit_card_rounded, title: 'Card (Visa, MasterCard, RuPay)'),
              const SizedBox(height: 10),
              _PayMethodItem(icon: Icons.account_balance_rounded, title: 'Netbanking'),
              
              const Spacer(),
              BrandButton(
                text: 'Simulate Success',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _payDev();
                },
              ),
            ],
          ),
        ),
      );
      
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                children: [
                  const Text('💳', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text(
                    'Confirm payment',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _orderCode,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  
                  Text(
                    '₹${(_amount / 100).toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 44, color: AppColors.textPrimary),
                  ),
                  const Text('incl. GST', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 32),

                  if (_devMode) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Dev mode — Razorpay not configured. Tapping below marks the order paid for testing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 12, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 20),
                    BrandButton(
                      text: 'Mark paid (dev)',
                      loading: _busy,
                      onPressed: _payDev,
                    ),
                  ] else ...[
                    BrandButton(
                      text: 'Pay with Razorpay',
                      loading: _busy,
                      onPressed: _payRealMock,
                    ),
                  ],
                  
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Pay later →',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayMethodItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _PayMethodItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
