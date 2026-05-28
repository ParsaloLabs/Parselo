import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/courier_office.dart';
import '../state/providers.dart';

class CourierOfficesScreen extends ConsumerStatefulWidget {
  const CourierOfficesScreen({super.key});

  @override
  ConsumerState<CourierOfficesScreen> createState() => _CourierOfficesScreenState();
}

class _CourierOfficesScreenState extends ConsumerState<CourierOfficesScreen> {
  final _radiusController = TextEditingController();
  bool _savingRadius = false;

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final officesAsync = ref.watch(courierOfficesProvider);
    final radiusGateAsync = ref.watch(radiusGateProvider);

    return Scaffold(
      backgroundColor: BrandColors.creamBg,
      appBar: AppBar(
        title: const Text('Courier Offices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: BrandColors.primary),
            onPressed: () => _showOfficeForm(context, null),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Radius Gate Control Panel
          SliverToBoxAdapter(
            child: radiusGateAsync.when(
              data: (gate) {
                // Initialize radius input once
                if (_radiusController.text.isEmpty && !_savingRadius) {
                  _radiusController.text = gate.radiusKm.toString();
                }
                return _buildRadiusGatePanel(context, gate);
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Failed to load gating flags: $err', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),

          // Courier Branches List Header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 8.0),
              child: Text(
                'Physical Offices',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: BrandColors.primary,
                ),
              ),
            ),
          ),

          // Offices Content
          officesAsync.when(
            data: (offices) {
              if (offices.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.storefront_outlined, size: 64, color: BrandColors.textMuted),
                          SizedBox(height: 16),
                          Text(
                            'No Physical Offices Added',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BrandColors.primary),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add drop-off stations where customers can drop parcels off.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: BrandColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final office = offices[index];
                      return _OfficeCard(
                        office: office,
                        onEdit: () => _showOfficeForm(context, office),
                        onDelete: () => _confirmDelete(context, office),
                      );
                    },
                    childCount: offices.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(BrandColors.accentOrange),
                ),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Failed to load offices: $err', style: const TextStyle(color: BrandColors.textMuted)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(courierOfficesProvider),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(120, 40)),
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

  Widget _buildRadiusGatePanel(BuildContext context, RadiusGateState gate) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: BrandColors.creamCard,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: BrandColors.creamBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Radius Gate',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: BrandColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gate.enabled
                            ? 'Restrict drop-offs within radius limits.'
                            : 'Accept drops district-wide by default.',
                        style: const TextStyle(fontSize: 13, color: BrandColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: gate.enabled,
                  activeColor: BrandColors.accentOrange,
                  onChanged: (val) async {
                    try {
                      await ref.read(radiusGateProvider.notifier).toggleRadius(val);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(val ? 'Radius gate enabled.' : 'Radius gate disabled.')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update toggle: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: BrandColors.creamBorder),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Operational Radius Limit',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: BrandColors.primary),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: TextFormField(
                          controller: _radiusController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            hintText: 'e.g. 15.0',
                            suffixText: 'km',
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _savingRadius ? null : _saveRadiusGateDistance,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _savingRadius
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRadiusGateDistance() async {
    final text = _radiusController.text.trim();
    if (text.isEmpty) return;
    final val = double.tryParse(text);
    if (val == null || val <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid radius in km.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _savingRadius = true);
    try {
      await ref.read(radiusGateProvider.notifier).saveRadius(val);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Radius distance limit updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save radius: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _savingRadius = false);
    }
  }

  void _showOfficeForm(BuildContext context, CourierOffice? office) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OfficeFormSheet(office: office),
    );
  }

  Future<void> _confirmDelete(BuildContext context, CourierOffice office) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Station'),
        content: Text('Are you sure you want to delete "${office.courierName} - ${office.name}"? Existing bookings will remain but new order assignments won\'t be matched to it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: BrandColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(courierOfficesProvider.notifier).deleteOffice(office.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Courier physical office deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete office: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class _OfficeCard extends StatelessWidget {
  final CourierOffice office;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OfficeCard({
    required this.office,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: BrandColors.creamCard,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: BrandColors.creamBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        office.courierName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: BrandColors.accentOrange,
                        ),
                      ),
                      if (office.name != null && office.name!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          office.name!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: BrandColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (office.district != null && office.district!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: BrandColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      office.district!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: BrandColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: BrandColors.creamBorder, height: 1),
            const SizedBox(height: 12),
            Text(
              office.fullAddress,
              style: const TextStyle(fontSize: 13, color: BrandColors.primary),
            ),
            if (office.pincode != null && office.pincode!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Pincode: ${office.pincode}',
                style: const TextStyle(fontSize: 12, color: BrandColors.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
            if (office.phone != null && office.phone!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 14, color: BrandColors.textMuted),
                  const SizedBox(width: 6),
                  Text(office.phone!, style: const TextStyle(fontSize: 12, color: BrandColors.textMuted)),
                ],
              ),
            ],
            if (office.openingHours != null && office.openingHours!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: BrandColors.textMuted),
                  const SizedBox(width: 6),
                  Text(office.openingHours!, style: const TextStyle(fontSize: 12, color: BrandColors.textMuted)),
                ],
              ),
            ],
            if (office.latitude != null && office.longitude != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.pin_drop_outlined, size: 14, color: BrandColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    '${office.latitude!.toStringAsFixed(5)}, ${office.longitude!.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: BrandColors.textMuted),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: BrandColors.accentOrange,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text('Delete', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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

class _OfficeFormSheet extends ConsumerStatefulWidget {
  final CourierOffice? office;

  const _OfficeFormSheet({this.office});

  @override
  ConsumerState<_OfficeFormSheet> createState() => _OfficeFormSheetState();
}

class _OfficeFormSheetState extends ConsumerState<_OfficeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCourierId;
  late TextEditingController _nameController;
  late TextEditingController _districtController;
  late TextEditingController _addressController;
  late TextEditingController _pincodeController;
  late TextEditingController _phoneController;
  late TextEditingController _hoursController;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedCourierId = widget.office?.courierId;
    _nameController = TextEditingController(text: widget.office?.name ?? '');
    _districtController = TextEditingController(text: widget.office?.district ?? '');
    _addressController = TextEditingController(text: widget.office?.fullAddress ?? '');
    _pincodeController = TextEditingController(text: widget.office?.pincode ?? '');
    _phoneController = TextEditingController(text: widget.office?.phone ?? '');
    _hoursController = TextEditingController(text: widget.office?.openingHours ?? '');
    _latController = TextEditingController(text: widget.office?.latitude?.toString() ?? '');
    _lngController = TextEditingController(text: widget.office?.longitude?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _hoursController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final couriersAsync = ref.watch(couriersListProvider);

    return Container(
      decoration: const BoxDecoration(
        color: BrandColors.creamBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.office == null ? 'Add Courier Office' : 'Edit Office Details',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: BrandColors.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Courier Selector
              couriersAsync.when(
                data: (couriers) {
                  if (couriers.isEmpty) {
                    return const Text('No couriers configured. Seed DB.', style: TextStyle(color: Colors.red));
                  }
                  if (_selectedCourierId == null && couriers.isNotEmpty) {
                    _selectedCourierId = couriers.first.id;
                  }
                  return DropdownButtonFormField<String>(
                    value: _selectedCourierId,
                    decoration: const InputDecoration(labelText: 'Courier Brand'),
                    items: couriers.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCourierId = val),
                    validator: (val) => val == null ? 'Required' : null,
                  );
                },
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (err, _) => Text('Error loading brands: $err', style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Office Name / Branch',
                  hintText: 'e.g. Round North Main, Patturaikkal Branch',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Please enter branch name' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _districtController,
                      decoration: const InputDecoration(
                        labelText: 'District',
                        hintText: 'e.g. Thrissur',
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Pincode',
                        hintText: 'e.g. 680001',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        if (val.trim().length != 6) return 'Must be 6 digits';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Full Address',
                  hintText: 'Street name, landmark details...',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Office Phone (optional)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _hoursController,
                      decoration: const InputDecoration(
                        labelText: 'Hours (optional)',
                        hintText: 'e.g. 9 am - 6 pm',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Coords Form
              const Text(
                'Geographic Coordinates',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BrandColors.primary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'e.g. 10.1234',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final num = double.tryParse(val);
                        if (num == null || num < -90 || num > 90) return 'Invalid lat';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'e.g. 76.5678',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final num = double.tryParse(val);
                        if (num == null || num < -180 || num > 180) return 'Invalid lng';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _saving ? null : _saveForm,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(widget.office == null ? 'Add Office Station' : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate() || _selectedCourierId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();
      final district = _districtController.text.trim();
      final address = _addressController.text.trim();
      final pincode = _pincodeController.text.trim();
      final phone = _phoneController.text.trim();
      final hours = _hoursController.text.trim();
      final lat = double.parse(_latController.text);
      final lng = double.parse(_lngController.text);

      await ref.read(courierOfficesProvider.notifier).saveOffice(
            id: widget.office?.id,
            courierId: _selectedCourierId!,
            name: name,
            district: district,
            fullAddress: address,
            pincode: pincode,
            phone: phone,
            openingHours: hours,
            latitude: lat,
            longitude: lng,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.office == null ? 'Courier office added.' : 'Courier office details saved.',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }
}
