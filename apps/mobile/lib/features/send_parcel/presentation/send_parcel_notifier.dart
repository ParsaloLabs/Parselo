import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/map_selection_dialog.dart';

class Address {
  final String id;
  final String? label;
  final String fullAddress;
  final String? pincode;
  final bool isDefault;

  Address({
    required this.id,
    this.label,
    required this.fullAddress,
    this.pincode,
    required this.isDefault,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] ?? '',
      label: json['label'],
      fullAddress: json['full_address'] ?? '',
      pincode: json['pincode'],
      isDefault: json['is_default'] ?? false,
    );
  }
}

double? _parseDouble(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val);
  return null;
}

int? _parseInt(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? double.tryParse(val)?.toInt();
  return null;
}

class CourierQuote {
  final String courierId;
  final String courierName;
  final int pricePaise;
  final int etaDays;
  final double rating;

  CourierQuote({
    required this.courierId,
    required this.courierName,
    required this.pricePaise,
    required this.etaDays,
    required this.rating,
  });

  factory CourierQuote.fromJson(Map<String, dynamic> json) {
    return CourierQuote(
      courierId: json['courier_id'] ?? '',
      courierName: json['courier_name'] ?? '',
      pricePaise: _parseInt(json['price_paise']) ?? 0,
      etaDays: _parseInt(json['eta_days']) ?? 0,
      rating: _parseDouble(json['rating']) ?? 0.0,
    );
  }
}

class SendParcelNotifier extends ChangeNotifier {
  int _step = 1;
  bool _loading = false;
  String? _error;

  List<Address> _addresses = [];
  String _pickupId = '';
  
  // New Pickup address state
  String _newPickupAddress = '';
  String _newPickupPincode = '';
  PickedLocation? _pickupPin;

  // Parcel specs
  String _parcelType = 'Documents';
  double _weight = 1.0;
  String _description = '';
  String _declaredValue = '';

  // Recipient details
  String _recipientName = '';
  String _recipientPhone = '+91';
  String _deliveryAddress = '';
  String _deliveryPincode = '';
  PickedLocation? _deliveryPin;

  // Quotes
  List<CourierQuote> _quotes = [];
  CourierQuote? _selectedQuote;

  // Getters
  int get step => _step;
  bool get loading => _loading;
  String? get error => _error;
  List<Address> get addresses => _addresses;
  String get pickupId => _pickupId;
  String get newPickupAddress => _newPickupAddress;
  String get newPickupPincode => _newPickupPincode;
  PickedLocation? get pickupPin => _pickupPin;
  String get parcelType => _parcelType;
  double get weight => _weight;
  String get description => _description;
  String get declaredValue => _declaredValue;
  String get recipientName => _recipientName;
  String get recipientPhone => _recipientPhone;
  String get deliveryAddress => _deliveryAddress;
  String get deliveryPincode => _deliveryPincode;
  PickedLocation? get deliveryPin => _deliveryPin;
  List<CourierQuote> get quotes => _quotes;
  CourierQuote? get selectedQuote => _selectedQuote;

  // Pricing helper
  int get courierCharge => _selectedQuote?.pricePaise ?? 0;
  int get serviceFee => 4900;
  int get gst => (serviceFee * 0.18).round();
  int get totalAmount => courierCharge + serviceFee + gst;

  // Setters
  void setStep(int val) {
    _step = val;
    notifyListeners();
  }

  void setPickupId(String val) {
    _pickupId = val;
    notifyListeners();
  }

  void setNewPickupAddress(String val) {
    _newPickupAddress = val;
    notifyListeners();
  }

  void setNewPickupPincode(String val) {
    _newPickupPincode = val;
    notifyListeners();
  }

  void setPickupPin(PickedLocation? loc) {
    _pickupPin = loc;
    if (loc != null) {
      if (_newPickupAddress.isEmpty) _newPickupAddress = loc.fullAddress;
      if (_newPickupPincode.isEmpty) _newPickupPincode = loc.pincode;
    }
    notifyListeners();
  }

  void setParcelType(String val) {
    _parcelType = val;
    notifyListeners();
  }

  void setWeight(double val) {
    _weight = val;
    notifyListeners();
  }

  void setDescription(String val) {
    _description = val;
    notifyListeners();
  }

  void setDeclaredValue(String val) {
    _declaredValue = val;
    notifyListeners();
  }

  void setRecipientName(String val) {
    _recipientName = val;
    notifyListeners();
  }

  void setRecipientPhone(String val) {
    _recipientPhone = val;
    notifyListeners();
  }

  void setDeliveryAddress(String val) {
    _deliveryAddress = val;
    notifyListeners();
  }

  void setDeliveryPincode(String val) {
    _deliveryPincode = val;
    notifyListeners();
  }

  void setDeliveryPin(PickedLocation? loc) {
    _deliveryPin = loc;
    if (loc != null) {
      if (_deliveryAddress.isEmpty) _deliveryAddress = loc.fullAddress;
      if (_deliveryPincode.isEmpty) _deliveryPincode = loc.pincode;
    }
    notifyListeners();
  }

  void selectQuote(CourierQuote quote) {
    _selectedQuote = quote;
    notifyListeners();
  }

  Future<void> fetchSavedAddresses() async {
    try {
      final res = await ApiClient.request('/addresses');
      if (res is List) {
        _addresses = res.map((j) => Address.fromJson(j)).toList();
        final def = _addresses.firstWhere((a) => a.isDefault, orElse: () => _addresses.first);
        _pickupId = def.id;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> getQuotes() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Create address if using new address
      String effectivePickupId = _pickupId;
      if (_pickupId.isEmpty) {
        if (_pickupPin == null) throw ApiException('Pinpoint the pickup location on the map');
        final fullAddr = _newPickupAddress.isNotEmpty ? _newPickupAddress : _pickupPin!.fullAddress;
        if (fullAddr.isEmpty) throw ApiException('Add a pickup address');
        final pin = _newPickupPincode.isNotEmpty ? _newPickupPincode : _pickupPin!.pincode;
        
        final resAddr = await ApiClient.request(
          '/addresses',
          method: 'POST',
          body: {
            'full_address': fullAddr,
            'latitude': _pickupPin!.lat,
            'longitude': _pickupPin!.lng,
            'pincode': pin.isNotEmpty ? pin : null,
            'is_default': _addresses.isEmpty,
          },
        );
        final created = Address.fromJson(resAddr);
        _addresses.insert(0, created);
        _pickupId = created.id;
        effectivePickupId = created.id;
      }

      final pickup = _addresses.firstWhere((a) => a.id == effectivePickupId);
      if (_deliveryPin == null) throw ApiException('Pinpoint the delivery location on the map');

      final fromPin = pickup.pincode ?? _newPickupPincode ?? '680001';
      final toPin = _deliveryPincode.isNotEmpty ? _deliveryPincode : _deliveryPin!.pincode;

      final resQuotes = await ApiClient.request(
        '/quotes',
        method: 'POST',
        body: {
          'from_pincode': fromPin,
          'to_pincode': toPin,
          'weight_kg': _weight,
          'parcel_type': _parcelType,
        },
      );

      if (resQuotes is Map && resQuotes['quotes'] is List) {
        _quotes = (resQuotes['quotes'] as List).map((q) => CourierQuote.fromJson(q)).toList();
        if (_quotes.isNotEmpty) {
          _selectedQuote = _quotes.first;
        } else {
          _selectedQuote = null;
        }
      }
      
      _step = 2;
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> placeOrder() async {
    if (_selectedQuote == null) return null;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final decVal = _declaredValue.isNotEmpty ? double.tryParse(_declaredValue) : null;
      final decValPaise = decVal != null ? (decVal * 100).round() : null;

      final res = await ApiClient.request(
        '/orders',
        method: 'POST',
        body: {
          'order_type': 'send',
          'parcel_type': _parcelType,
          'parcel_weight_kg': _weight,
          'parcel_description': _description.isNotEmpty ? _description : null,
          'declared_value': decValPaise,
          'pickup_address_id': _pickupId,
          'recipient_name': _recipientName,
          'recipient_phone': _recipientPhone,
          'delivery_address': _deliveryAddress,
          'delivery_lat': _deliveryPin?.lat,
          'delivery_lng': _deliveryPin?.lng,
          'selected_courier_id': _selectedQuote!.courierId,
          'courier_charge_paise': _selectedQuote!.pricePaise,
        },
      );

      _loading = false;
      notifyListeners();
      return res['id'];
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      _loading = false;
      notifyListeners();
      return null;
    }
  }
}
