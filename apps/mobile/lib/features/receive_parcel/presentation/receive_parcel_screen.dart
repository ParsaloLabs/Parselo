import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../../../core/config/service_area_config.dart';
import '../../../core/widgets/brand_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/map_selection_dialog.dart';
import '../../../core/widgets/out_of_service_area_sheet.dart';
import '../../../core/widgets/signature_pad.dart';
import '../../payments/presentation/payment_screen.dart';
import 'receive_parcel_notifier.dart';

class ReceiveParcelScreen extends StatefulWidget {
  final VoidCallback? onOrderPlaced;

  const ReceiveParcelScreen({Key? key, this.onOrderPlaced}) : super(key: key);

  @override
  State<ReceiveParcelScreen> createState() => _ReceiveParcelScreenState();
}

class _ReceiveParcelScreenState extends State<ReceiveParcelScreen> {
  final ReceiveParcelNotifier _notifier = ReceiveParcelNotifier();
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<SignaturePadState> _sigKey = GlobalKey<SignaturePadState>();

  final TextEditingController _deliveryAddressCtrl = TextEditingController();
  final TextEditingController _deliveryPincodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notifier.initData();
  }

  @override
  void dispose() {
    _deliveryAddressCtrl.dispose();
    _deliveryPincodeCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      // Capture signature from signature pad key
      final sigBase64 = await _sigKey.currentState?.toDataURL();
      if (sigBase64 != null) {
        _notifier.setSignature(sigBase64);
      }
      
      final orderId = await _notifier.submitOrder();
      if (orderId != null && mounted) {
        if (widget.onOrderPlaced != null) widget.onOrderPlaced!();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentScreen(orderId: orderId),
          ),
        );
      }
    }
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
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Receive a parcel',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // How this works tip bubble
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      border: Border.all(color: Colors.amber.shade200),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(color: Colors.amber.shade900, fontSize: 12, height: 1.4),
                              children: const [
                                TextSpan(text: 'How this works: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: 'Our agent visits the courier office on your behalf, collects your parcel, and delivers it to your address. You\'ll get an OTP to share with the agent at delivery.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Courier Details Card
                  _SectionTitle(title: 'Where is the parcel?'),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _notifier.courierId.isEmpty ? null : _notifier.courierId,
                          decoration: const InputDecoration(labelText: 'Courier'),
                          hint: const Text('Select courier', style: TextStyle(fontSize: 13)),
                          items: _notifier.couriers
                              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) => _notifier.setCourierId(val ?? ''),
                          validator: (val) => val == null ? 'Select a courier' : null,
                        ),
                        if (_notifier.branches.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _notifier.branchId.isEmpty ? null : _notifier.branchId,
                            decoration: const InputDecoration(labelText: 'Branch (optional)'),
                            hint: const Text('Auto-select nearest', style: TextStyle(fontSize: 13)),
                            items: _notifier.branches
                                .map((b) => DropdownMenuItem(value: b.id, child: Text('${b.name} — ${b.address}', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (val) => _notifier.setBranchId(val ?? ''),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: _notifier.trackingId,
                          onChanged: _notifier.setTrackingId,
                          style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            labelText: 'Tracking / consignment number',
                            hintText: 'e.g. AWB123456789',
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Consignment number is required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Deliver to Address Card
                  _SectionTitle(title: 'Deliver to'),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_notifier.addresses.isNotEmpty) ...[
                          ..._notifier.addresses.map((a) => RadioListTile<String>(
                                value: a.id,
                                groupValue: _notifier.deliveryId,
                                activeColor: AppColors.brand,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) => _notifier.setDeliveryId(val ?? ''),
                                title: Text(a.fullAddress, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                                subtitle: a.pincode != null ? Text('PIN ${a.pincode}', style: const TextStyle(fontSize: 11)) : null,
                              )),
                          RadioListTile<String>(
                            value: '',
                            groupValue: _notifier.deliveryId,
                            activeColor: AppColors.brand,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => _notifier.setDeliveryId(val ?? ''),
                            title: const Text('Use a new address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ),
                        ],
                        
                        if (_notifier.deliveryId.isEmpty) ...[
                          const SizedBox(height: 10),
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
                                if (!ServiceAreaConfig.instance.isServiceable(loc.lat, loc.lng, loc.district)) {
                                  if (!mounted) return;
                                  final nearest = ServiceAreaConfig.instance.nearest(loc.lat, loc.lng);
                                  OutOfServiceAreaSheet.show(
                                    context,
                                    nearestCityName: nearest?.district,
                                    onPickAgain: () {},
                                  );
                                  return;
                                }
                                _notifier.setDeliveryPin(loc);
                                if (_deliveryPincodeCtrl.text.trim().isEmpty && loc.pincode.isNotEmpty) {
                                  _deliveryPincodeCtrl.text = loc.pincode;
                                  _notifier.setNewDeliveryPincode(loc.pincode);
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
                            onChanged: _notifier.setNewDeliveryAddress,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Address line 1',
                              hintText: 'House/flat, street, area — as you want on the courier label',
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Delivery address is required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _deliveryPincodeCtrl,
                            onChanged: _notifier.setNewDeliveryPincode,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(labelText: 'Pincode', counterText: ''),
                            validator: (val) => val == null || val.trim().length < 6 ? 'Enter a valid pincode' : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Speed Card
                  _SectionTitle(title: 'Delivery speed'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Next Day
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _notifier.setSameDay(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: !_notifier.sameDay ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: !_notifier.sameDay ? AppColors.brand : AppColors.border,
                                width: !_notifier.sameDay ? 2 : 1,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Text('Next day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                SizedBox(height: 2),
                                Text('Free', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Same Day
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _notifier.setSameDay(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _notifier.sameDay ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _notifier.sameDay ? AppColors.brand : AppColors.border,
                                width: _notifier.sameDay ? 2 : 1,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Text('Same day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                SizedBox(height: 2),
                                Text('+₹30', style: TextStyle(fontSize: 11, color: AppColors.brand, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Authorization Card (Sign, ID, consent)
                  _SectionTitle(title: 'Authorization'),
                  const SizedBox(height: 4),
                  const Text(
                    'The courier office requires your signature and ID to release the parcel to our agent. We share these only with the courier office, never with the agent.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        SignaturePad(key: _sigKey),
                        const Divider(color: AppColors.border, height: 28),
                        
                        const Text('Government-issued ID (Aadhaar / PAN / Driving licence)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        
                        if (_notifier.idProofDataUrl == null) ...[
                          OutlinedButton.icon(
                            onPressed: _notifier.pickAndCompressIdImage,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppColors.border, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.camera_alt_rounded, color: AppColors.textSecondary, size: 18),
                            label: const Text('Capture ID Photo', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.contact_mail_rounded, color: AppColors.brand, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _notifier.idProofFileName ?? 'id_proof_captured.jpg',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                      ),
                                      const Text('Image compressed successfully', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _notifier.clearIdImage,
                                  icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                                ),
                              ],
                            ),
                          )
                        ],
                        const Divider(color: AppColors.border, height: 28),

                        // Declarations check
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _notifier.agreed,
                              activeColor: AppColors.brand,
                              onChanged: (val) => _notifier.setAgreed(val ?? false),
                            ),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Text(
                                'I confirm the parcel belongs to me and authorize Parsalo and its agent to collect it on my behalf, and I take responsibility for any claims arising from this collection.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bill Card
                  _SectionTitle(title: 'Estimated Payment'),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _BillRow(label: 'Pickup fee', amount: _notifier.pickupFee),
                        if (_notifier.sameDay) ...[
                          const SizedBox(height: 8),
                          _BillRow(label: 'Same-day delivery fee', amount: _notifier.deliveryFee),
                        ],
                        const SizedBox(height: 8),
                        _BillRow(label: 'GST (18% on service)', amount: _notifier.gst),
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
                  BrandButton(
                    text: 'Place Order  —  ₹${(_notifier.totalAmount / 100).toStringAsFixed(0)}',
                    loading: _notifier.loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
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

class _BillRow extends StatelessWidget {
  final String label;
  final int amount;

  const _BillRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text('₹${(amount / 100).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}
