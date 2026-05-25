import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/map_selection_dialog.dart';
import '../../send_parcel/presentation/send_parcel_notifier.dart' as sp;

class Courier {
  final String id;
  final String name;

  Courier({required this.id, required this.name});

  factory Courier.fromJson(Map<String, dynamic> json) {
    return Courier(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class Branch {
  final String id;
  final String name;
  final String address;

  Branch({required this.id, required this.name, required this.address});

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
    );
  }
}

class ReceiveParcelNotifier extends ChangeNotifier {
  bool _loading = false;
  String? _error;

  List<Courier> _couriers = [];
  List<Branch> _branches = [];
  List<sp.Address> _addresses = [];

  // Form selections
  String _courierId = '';
  String _branchId = '';
  String _trackingId = '';
  
  // Delivery address target
  String _deliveryId = '';
  String _newDeliveryAddress = '';
  String _newDeliveryPincode = '';
  PickedLocation? _deliveryPin;

  // Delivery speed
  bool _sameDay = false;

  // Sign & ID Proof
  String? _signatureDataUrl;
  String? _idProofDataUrl;
  String? _idProofFileName;
  bool _agreed = false;

  // Getters
  bool get loading => _loading;
  String? get error => _error;
  List<Courier> get couriers => _couriers;
  List<Branch> get branches => _branches;
  List<sp.Address> get addresses => _addresses;
  String get courierId => _courierId;
  String get branchId => _branchId;
  String get trackingId => _trackingId;
  String get deliveryId => _deliveryId;
  String get newDeliveryAddress => _newDeliveryAddress;
  String get newDeliveryPincode => _newDeliveryPincode;
  PickedLocation? get deliveryPin => _deliveryPin;
  bool get sameDay => _sameDay;
  String? get signatureDataUrl => _signatureDataUrl;
  String? get idProofDataUrl => _idProofDataUrl;
  String? get idProofFileName => _idProofFileName;
  bool get agreed => _agreed;

  // Pricing math
  int get pickupFee => 9900;
  int get deliveryFee => _sameDay ? 3000 : 0;
  int get service => pickupFee + deliveryFee;
  int get gst => (service * 0.18).round();
  int get totalAmount => service + gst;

  // Setters
  void setCourierId(String val) {
    _courierId = val;
    _branchId = '';
    _branches = [];
    if (val.isNotEmpty) {
      _fetchBranches(val);
    }
    notifyListeners();
  }

  void setBranchId(String val) {
    _branchId = val;
    notifyListeners();
  }

  void setTrackingId(String val) {
    _trackingId = val;
    notifyListeners();
  }

  void setDeliveryId(String val) {
    _deliveryId = val;
    notifyListeners();
  }

  void setNewDeliveryAddress(String val) {
    _newDeliveryAddress = val;
    notifyListeners();
  }

  void setNewDeliveryPincode(String val) {
    _newDeliveryPincode = val;
    notifyListeners();
  }

  void setDeliveryPin(PickedLocation? loc) {
    _deliveryPin = loc;
    if (loc != null) {
      if (_newDeliveryAddress.isEmpty) _newDeliveryAddress = loc.fullAddress;
      if (_newDeliveryPincode.isEmpty) _newDeliveryPincode = loc.pincode;
    }
    notifyListeners();
  }

  void setSameDay(bool val) {
    _sameDay = val;
    notifyListeners();
  }

  void setSignature(String dataUrl) {
    _signatureDataUrl = dataUrl;
    notifyListeners();
  }

  void setAgreed(bool val) {
    _agreed = val;
    notifyListeners();
  }

  Future<void> pickAndCompressIdImage() async {
    _error = null;
    notifyListeners();

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1200);
      if (file != null) {
        final Uint8List bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        _idProofDataUrl = 'data:image/jpeg;base64,$base64String';
        _idProofFileName = file.name;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to capture or read ID image.';
      notifyListeners();
    }
  }

  void clearIdImage() {
    _idProofDataUrl = null;
    _idProofFileName = null;
    notifyListeners();
  }

  Future<void> initData() async {
    try {
      final rowsC = await ApiClient.request('/couriers');
      if (rowsC is List) {
        _couriers = rowsC.map((j) => Courier.fromJson(j)).toList();
      }
      
      final rowsA = await ApiClient.request('/addresses');
      if (rowsA is List) {
        _addresses = rowsA.map((j) => sp.Address.fromJson(j)).toList();
        final def = _addresses.firstWhere((a) => a.isDefault, orElse: () => _addresses.first);
        _deliveryId = def.id;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _fetchBranches(String cId) async {
    try {
      final res = await ApiClient.request('/couriers/$cId/branches');
      if (res is List) {
        _branches = res.map((j) => Branch.fromJson(j)).toList();
      }
    } catch (_) {
      _branches = [];
    }
    notifyListeners();
  }

  Future<String?> submitOrder() async {
    _error = null;
    
    if (_signatureDataUrl == null || _signatureDataUrl!.isEmpty) {
      _error = 'Please sign in the box below to authorize collection';
      notifyListeners();
      return null;
    }
    if (_idProofDataUrl == null || _idProofDataUrl!.isEmpty) {
      _error = 'Please upload a photo of your government-issued ID';
      notifyListeners();
      return null;
    }
    if (!_agreed) {
      _error = 'Please confirm the declaration to proceed';
      notifyListeners();
      return null;
    }

    _loading = true;
    notifyListeners();

    try {
      String delId = _deliveryId;
      if (delId.isEmpty) {
        if (_deliveryPin == null) throw ApiException('Pinpoint the delivery location on the map');
        final fullAddr = _newDeliveryAddress.isNotEmpty ? _newDeliveryAddress : _deliveryPin!.fullAddress;
        if (fullAddr.isEmpty) throw ApiException('Add a delivery address');
        final pin = _newDeliveryPincode.isNotEmpty ? _newDeliveryPincode : _deliveryPin!.pincode;

        final resAddr = await ApiClient.request(
          '/addresses',
          method: 'POST',
          body: {
            'full_address': fullAddr,
            'latitude': _deliveryPin!.lat,
            'longitude': _deliveryPin!.lng,
            'pincode': pin.isNotEmpty ? pin : null,
            'is_default': _addresses.isEmpty,
          },
        );
        final created = sp.Address.fromJson(resAddr);
        _addresses.insert(0, created);
        _deliveryId = created.id;
        delId = created.id;
      }

      final resOrder = await ApiClient.request(
        '/orders',
        method: 'POST',
        body: {
          'order_type': 'receive',
          'source_courier_id': _courierId,
          'source_tracking_id': _trackingId,
          'source_branch_id': _branchId.isNotEmpty ? _branchId : null,
          'delivery_address_id': delId,
          'same_day': _sameDay,
          'user_signature_url': _signatureDataUrl,
          'user_id_proof_url': _idProofDataUrl,
        },
      );

      _loading = false;
      notifyListeners();
      return resOrder['id'];
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      _loading = false;
      notifyListeners();
      return null;
    }
  }
}
