import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/service_area.dart';
import '../state/providers.dart';

class ServiceAreasScreen extends ConsumerStatefulWidget {
  const ServiceAreasScreen({super.key});

  @override
  ConsumerState<ServiceAreasScreen> createState() => _ServiceAreasScreenState();
}

class _ServiceAreasScreenState extends ConsumerState<ServiceAreasScreen> {
  @override
  Widget build(BuildContext context) {
    final areasAsync = ref.watch(serviceAreasProvider);

    return Scaffold(
      backgroundColor: BrandColors.creamBg,
      appBar: AppBar(
        title: const Text('Service Areas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: BrandColors.primary),
            onPressed: () => _showAreaForm(context, null),
          ),
        ],
      ),
      body: areasAsync.when(
        data: (areas) {
          if (areas.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map_outlined, size: 64, color: BrandColors.textMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'No Service Areas Defined',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BrandColors.primary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create service zones to establish where Parsalo delivery agents operate.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: BrandColors.textMuted),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAreaForm(context, null),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Add Service Area'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 48),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(serviceAreasProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: areas.length,
              itemBuilder: (context, index) {
                final area = areas[index];
                return _AreaCard(
                  area: area,
                  onEdit: () => _showAreaForm(context, area),
                  onDelete: () => _confirmDelete(context, area),
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
                const SizedBox(height: 16),
                Text(
                  'Failed to load service areas: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BrandColors.textMuted),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(serviceAreasProvider),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(120, 40)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAreaForm(BuildContext context, ServiceArea? area) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AreaFormSheet(area: area),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ServiceArea area) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Zone'),
        content: Text('Are you sure you want to delete the service zone "${area.name}"? orders created inside this region will no longer be accepted.'),
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
        await ref.read(serviceAreasProvider.notifier).deleteArea(area.id);
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Service area deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Failed to delete area: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class _AreaCard extends StatelessWidget {
  final ServiceArea area;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AreaCard({
    required this.area,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    area.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: BrandColors.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: area.isActive
                        ? BrandColors.accentGreen.withValues(alpha: 0.1)
                        : BrandColors.textMuted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    area.isActive ? 'Active' : 'Disabled',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: area.isActive ? BrandColors.accentGreen : BrandColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: BrandColors.creamBorder, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.circle_outlined, size: 16, color: BrandColors.accentOrange),
                const SizedBox(width: 8),
                const Text(
                  'Radius: ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: BrandColors.primary),
                ),
                Text(
                  '${(area.radiusM / 1000).toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 14, color: BrandColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: BrandColors.textMuted),
                const SizedBox(width: 8),
                const Text(
                  'Center: ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: BrandColors.primary),
                ),
                Text(
                  '${area.centerLat.toStringAsFixed(5)}, ${area.centerLng.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 14, fontFamily: 'monospace', color: BrandColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16, color: BrandColors.accentOrange),
                  label: const Text('Edit', style: TextStyle(color: BrandColors.accentOrange)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaFormSheet extends ConsumerStatefulWidget {
  final ServiceArea? area;

  const _AreaFormSheet({this.area});

  @override
  ConsumerState<_AreaFormSheet> createState() => _AreaFormSheetState();
}

class _AreaFormSheetState extends ConsumerState<_AreaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _radiusController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late bool _isActive;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.area?.name ?? '');
    _radiusController = TextEditingController(
      text: widget.area != null ? (widget.area!.radiusM / 1000).toString() : '15.0',
    );
    _latController = TextEditingController(text: widget.area?.centerLat.toString() ?? '');
    _lngController = TextEditingController(text: widget.area?.centerLng.toString() ?? '');
    _isActive = widget.area?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    widget.area == null ? 'Add Service Area' : 'Edit Service Area',
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Zone Name',
                  hintText: 'e.g. Thrissur City, Ernakulam West',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Please enter a zone name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _radiusController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Radius (km)',
                  hintText: 'e.g. 15.0',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter radius';
                  final num = double.tryParse(val);
                  if (num == null || num <= 0.0) return 'Please enter a valid radius > 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Center Latitude',
                        hintText: 'e.g. 10.1234',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final num = double.tryParse(val);
                        if (num == null || num < -90 || num > 90) return 'Invalid lat (-90 to 90)';
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
                        labelText: 'Center Longitude',
                        hintText: 'e.g. 76.5678',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final num = double.tryParse(val);
                        if (num == null || num < -180 || num > 180) return 'Invalid lng (-180 to 180)';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: BrandColors.accentOrange,
                title: const Text(
                  'Active Zone',
                  style: TextStyle(fontWeight: FontWeight.bold, color: BrandColors.primary),
                ),
                subtitle: const Text('Allow order matching and agent signups in this zone.'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
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
                    : Text(widget.area == null ? 'Add Service Area' : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();
      final radiusKm = double.parse(_radiusController.text);
      final centerLat = double.parse(_latController.text);
      final centerLng = double.parse(_lngController.text);
      final radiusM = (radiusKm * 1000).round();

      await ref.read(serviceAreasProvider.notifier).saveArea(
            id: widget.area?.id,
            name: name,
            centerLat: centerLat,
            centerLng: centerLng,
            radiusM: radiusM,
            isActive: _isActive,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.area == null ? 'Service area created.' : 'Service area updated.',
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
