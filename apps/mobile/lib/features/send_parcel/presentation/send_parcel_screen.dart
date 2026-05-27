import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../../../core/config/service_area_config.dart';
import '../../../core/widgets/brand_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/map_selection_dialog.dart';
import '../../../core/widgets/out_of_service_area_sheet.dart';
import '../../payments/presentation/payment_screen.dart';
import 'send_parcel_notifier.dart';

class SendParcelScreen extends StatefulWidget {
  final VoidCallback? onOrderPlaced;

  const SendParcelScreen({Key? key, this.onOrderPlaced}) : super(key: key);

  @override
  State<SendParcelScreen> createState() => _SendParcelScreenState();
}

class _SendParcelScreenState extends State<SendParcelScreen> {
  final SendParcelNotifier _notifier = SendParcelNotifier();
  final _formKey1 = GlobalKey<FormState>();

  final TextEditingController _pickupAddressCtrl = TextEditingController();
  final TextEditingController _pickupPincodeCtrl = TextEditingController();
  final TextEditingController _deliveryAddressCtrl = TextEditingController();
  final TextEditingController _deliveryPincodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notifier.fetchSavedAddresses();
  }

  @override
  void dispose() {
    _pickupAddressCtrl.dispose();
    _pickupPincodeCtrl.dispose();
    _deliveryAddressCtrl.dispose();
    _deliveryPincodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              onPressed: () {
                if (_notifier.step > 1) {
                  _notifier.setStep(_notifier.step - 1);
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
            title: const Text(
              'Send a parcel',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          body: Column(
            children: [
              // Wizard Stepper Indicator
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    _StepCircle(n: 1, current: _notifier.step, label: 'Details'),
                    _StepLine(active: _notifier.step > 1),
                    _StepCircle(n: 2, current: _notifier.step, label: 'Courier'),
                    _StepLine(active: _notifier.step > 2),
                    _StepCircle(n: 3, current: _notifier.step, label: 'Review'),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildStepContent(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepContent() {
    if (_notifier.step == 1) {
      return Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pickup Address section
            _SectionTitle(title: 'Pickup address'),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_notifier.addresses.isNotEmpty) ...[
                    ..._notifier.addresses.map((a) => RadioListTile<String>(
                          value: a.id,
                          groupValue: _notifier.pickupId,
                          activeColor: AppColors.brand,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => _notifier.setPickupId(val ?? ''),
                          title: Text(a.fullAddress, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                          subtitle: a.pincode != null ? Text('PIN ${a.pincode}', style: const TextStyle(fontSize: 11)) : null,
                        )),
                    RadioListTile<String>(
                      value: '',
                      groupValue: _notifier.pickupId,
                      activeColor: AppColors.brand,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => _notifier.setPickupId(val ?? ''),
                      title: const Text('Use a new address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ),
                  ],
                  
                  if (_notifier.pickupId.isEmpty) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final loc = await showDialog<PickedLocation>(
                          context: context,
                          builder: (context) => MapSelectionDialog(
                            title: 'Pin Pickup Spot',
                            initialLocation: _notifier.pickupPin,
                          ),
                        );
                        if (loc != null) {
                          if (!ServiceAreaConfig.instance.isInside(loc.lat, loc.lng)) {
                            if (!mounted) return;
                            final nearest = ServiceAreaConfig.instance.nearest(loc.lat, loc.lng);
                            OutOfServiceAreaSheet.show(
                              context,
                              nearestCityName: nearest?.district,
                              onPickAgain: () {},
                            );
                            return;
                          }
                          _notifier.setPickupPin(loc);
                          if (_pickupPincodeCtrl.text.trim().isEmpty && loc.pincode.isNotEmpty) {
                            _pickupPincodeCtrl.text = loc.pincode;
                            _notifier.setNewPickupPincode(loc.pincode);
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.brand, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.map_rounded, color: AppColors.brand, size: 18),
                      label: Text(
                        _notifier.pickupPin == null ? 'Pin location on Google Maps' : 'Re-pin location on Google Maps',
                        style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    if (_notifier.pickupPin != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppColors.brand, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _notifier.pickupPin!.fullAddress,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _pickupAddressCtrl,
                      onChanged: _notifier.setNewPickupAddress,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address line 1',
                        hintText: 'House/flat, street, area — as you want on the courier label',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Pickup address is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pickupPincodeCtrl,
                      onChanged: _notifier.setNewPickupPincode,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Pincode',
                        hintText: '680001',
                        counterText: '',
                      ),
                      validator: (val) => val == null || val.trim().length < 6 ? 'Enter a valid 6-digit pincode' : null,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Parcel Specs section
            _SectionTitle(title: 'Parcel details'),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _notifier.parcelType,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: ['Documents', 'Electronics', 'Clothing', 'Food', 'Fragile', 'Other']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) => _notifier.setParcelType(val ?? 'Documents'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: _notifier.weight.toString(),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Weight (kg)', hintText: '1.0'),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Enter weight';
                            final w = double.tryParse(val);
                            if (w == null || w <= 0) return 'Invalid weight';
                            return null;
                          },
                          onChanged: (val) {
                            final w = double.tryParse(val);
                            if (w != null) _notifier.setWeight(w);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _notifier.description,
                    decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'e.g. 2 books, clothing items'),
                    onChanged: _notifier.setDescription,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _notifier.declaredValue,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Declared value (₹, optional)', hintText: 'e.g. 2000'),
                    onChanged: _notifier.setDeclaredValue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recipient Details section
            _SectionTitle(title: 'Recipient details'),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _notifier.recipientName,
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          onChanged: _notifier.setRecipientName,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: _notifier.recipientPhone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Mobile'),
                          validator: (val) => val == null || val.length < 10 ? 'Required' : null,
                          onChanged: _notifier.setRecipientPhone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final loc = await showDialog<PickedLocation>(
                        context: context,
                        builder: (context) => MapSelectionDialog(
                          title: 'Pin Delivery Spot',
                          initialLocation: _notifier.deliveryPin,
                        ),
                      );
                      if (loc != null) {
                        _notifier.setDeliveryPin(loc);
                        if (_deliveryPincodeCtrl.text.trim().isEmpty && loc.pincode.isNotEmpty) {
                          _deliveryPincodeCtrl.text = loc.pincode;
                          _notifier.setDeliveryPincode(loc.pincode);
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.accent, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.map_rounded, color: AppColors.accent, size: 18),
                    label: Text(
                      _notifier.deliveryPin == null ? 'Pin location on Google Maps' : 'Re-pin location on Google Maps',
                      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  if (_notifier.deliveryPin != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_rounded, color: AppColors.accent, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _notifier.deliveryPin!.fullAddress,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _deliveryAddressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Address line 1',
                      hintText: 'House/flat, street, area — as you want on the courier label',
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Address details are required' : null,
                    onChanged: _notifier.setDeliveryAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _deliveryPincodeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: 'Delivery pincode', counterText: ''),
                    validator: (val) => val == null || val.trim().length < 6 ? 'Enter a valid pincode' : null,
                    onChanged: _notifier.setDeliveryPincode,
                  ),
                ],
              ),
            ),
            
            if (_notifier.error != null) ...[
              const SizedBox(height: 16),
              Text(
                _notifier.error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
            
            const SizedBox(height: 28),
            BrandButton(
              text: 'Get Courier Quotes →',
              loading: _notifier.loading,
              onPressed: () {
                if (_formKey1.currentState!.validate()) {
                  _notifier.getQuotes();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
    }
    
    if (_notifier.step == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(title: 'Choose a courier'),
          const SizedBox(height: 10),
          if (_notifier.quotes.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text('No active courier quotes available for this route.', textAlign: TextAlign.center),
            )
          ] else ...[
            ..._notifier.quotes.map((q) {
              final isSel = _notifier.selectedQuote?.courierId == q.courierId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => _notifier.selectQuote(q),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSel ? AppColors.brand : AppColors.border,
                        width: isSel ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: q.courierId,
                          groupValue: _notifier.selectedQuote?.courierId,
                          activeColor: AppColors.brand,
                          onChanged: (_) => _notifier.selectQuote(q),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q.courierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                  const SizedBox(width: 2),
                                  Text(q.rating.toString(), style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                                  const SizedBox(width: 6),
                                  Text('·   ${q.etaDays}-day delivery', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text('₹${(q.pricePaise / 100).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: BrandButton(
                  text: 'Back',
                  isSecondary: true,
                  onPressed: () => _notifier.setStep(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BrandButton(
                  text: 'Continue',
                  onPressed: _notifier.selectedQuote == null ? null : () => _notifier.setStep(3),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    // Step 3: Review
    final q = _notifier.selectedQuote;
    if (q == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: 'Review & confirm'),
        const SizedBox(height: 10),
        
        // Summary Card
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _SummaryRow(
                label: 'Pickup',
                content: _notifier.addresses.firstWhere((a) => a.id == _notifier.pickupId, orElse: () => Address(id: '', fullAddress: _notifier.newPickupAddress, isDefault: false)).fullAddress,
              ),
              const _SummaryDivider(),
              _SummaryRow(
                label: 'Parcel',
                content: '${_notifier.parcelType}   ·   ${_notifier.weight} kg${_notifier.description.isNotEmpty ? '   ·   ${_notifier.description}' : ''}',
              ),
              const _SummaryDivider(),
              _SummaryRow(
                label: 'Recipient',
                content: '${_notifier.recipientName}  (${_notifier.recipientPhone})',
              ),
              const _SummaryDivider(),
              _SummaryRow(
                label: 'Delivery',
                content: '${_notifier.deliveryAddress},   PIN ${_notifier.deliveryPincode}',
              ),
              const _SummaryDivider(),
              _SummaryRow(
                label: 'Courier',
                content: '${q.courierName}   ·   ${q.etaDays}d',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Pricing Card
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _PriceBreakdownRow(label: 'Courier charge', paise: _notifier.courierCharge),
              const SizedBox(height: 8),
              _PriceBreakdownRow(label: 'Service fee', paise: _notifier.serviceFee),
              const SizedBox(height: 8),
              _PriceBreakdownRow(label: 'GST (18% on service)', paise: _notifier.gst),
              const Divider(color: AppColors.border, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                  Text('₹${(_notifier.totalAmount / 100).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.brand)),
                ],
              ),
            ],
          ),
        ),
        
        if (_notifier.error != null) ...[
          const SizedBox(height: 16),
          Text(
            _notifier.error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],

        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: BrandButton(
                text: 'Back',
                isSecondary: true,
                onPressed: () => _notifier.setStep(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BrandButton(
                text: 'Place Order',
                loading: _notifier.loading,
                onPressed: () async {
                  final orderId = await _notifier.placeOrder();
                  if (orderId != null && mounted) {
                    if (widget.onOrderPlaced != null) widget.onOrderPlaced!();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => PaymentScreen(orderId: orderId),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int n;
  final int current;
  final String label;

  const _StepCircle({required this.n, required this.current, required this.label});

  @override
  Widget build(BuildContext context) {
    final done = current >= n;
    final active = current == n;

    return Row(
      children: [
        Container(
          height: 26,
          width: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? AppColors.brand : const Color(0xFFE2E8F0),
            shape: BoxShape.circle,
          ),
          child: Text(
            n.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: done ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: active ? AppColors.brand : const Color(0xFFE2E8F0),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String content;

  const _SummaryRow({required this.label, required this.content});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            content,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(color: Color(0xFFF1F5F9), height: 16);
  }
}

class _PriceBreakdownRow extends StatelessWidget {
  final String label;
  final int paise;

  const _PriceBreakdownRow({required this.label, required this.paise});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          '₹${(paise / 100).toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
