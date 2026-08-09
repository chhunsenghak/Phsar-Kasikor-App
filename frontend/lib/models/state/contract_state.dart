import 'package:flutter/material.dart';
import '../../services/api/contract_api.dart';
import '../../utils/api_error.dart';
import 'base_app_state.dart';

/// Maps a raw backend error code (from `app/core/errors.py`) returned by a
/// contract action to a translated, user-facing message. Without this,
/// failures surface as a bare enum string like
/// "ONLY_SELLER_CAN_ACTIVATE_CONTRACT". Falls back to the shared API error
/// map (see `utils/api_error.dart`) for codes with no contract-specific
/// wording, so nothing here ever surfaces the raw code.
String friendlyContractErrorMessage(BaseAppState state, String rawMessage) {
  switch (rawMessage) {
    case 'ONLY_SELLER_CAN_ACTIVATE_CONTRACT':
      return state.translate('error_only_seller_can_activate');
    case 'CANNOT_MODIFY_ITEMS_AFTER_DRAFT':
      return state.translate('error_cannot_modify_after_draft');
    case 'CONTRACT_ALREADY_RESOLVED':
      return state.translate('error_contract_already_resolved');
    case 'CONTRACT_PRODUCT_OWNER_MISMATCH':
      return state.translate('error_contract_product_owner_mismatch');
    default:
      return translateErrorCode(state, rawMessage);
  }
}

mixin ContractStateMixin on BaseAppState {
  // Abstract properties implemented by ProductStateMixin sibling
  List<MarketProduct> get products;
  String mapUnitToBackendHelper(String unit);
  String mapUnitToFrontendHelper(String? unitType);

  final List<BidOffer> _negotiations = [];
  List<BidOffer> get negotiations => _negotiations;

  // --- Farmer Verification Queue (Admin) ---
  final List<FarmerVerification> _verifications = [
    FarmerVerification(
      id: 'v_1',
      name: 'Keo Sarath',
      farmName: 'Battambang Rice Farms',
      location: 'Battambang',
      cropTypes: 'Jasmine Rice, Brown Rice',
      docUrl: 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?q=80&w=600',
      certType: 'organic',
      status: 'pending',
    ),
    FarmerVerification(
      id: 'v_2',
      name: 'Nguon Srey',
      farmName: 'Srey Mango Plantation',
      location: 'Kampong Cham',
      cropTypes: 'Keo Romeat Mango',
      docUrl: 'https://images.unsplash.com/photo-1601597111158-2fceff270190?q=80&w=600',
      certType: 'gap',
      status: 'pending',
    ),
  ];
  List<FarmerVerification> get verifications => _verifications;

  String getFarmerCertType(String farmerName) {
    final cleanName = farmerName.replaceAll(RegExp(r'\s*\(Farmer\)\s*'), '').trim().toLowerCase();
    for (var v in _verifications) {
      final cleanVName = v.name.replaceAll(RegExp(r'\s*\(Farmer\)\s*'), '').trim().toLowerCase();
      final cleanVFarm = v.farmName.toLowerCase();
      if ((cleanVName == cleanName || cleanVFarm == cleanName || cleanVName.contains(cleanName)) && v.status == 'approved') {
        return v.certType;
      }
    }
    if (cleanName == 'chan sopheap' || cleanName == 'chan sopheap (farmer)') {
      return 'organic';
    }
    return 'none';
  }

  void addVerification(FarmerVerification verification) {
    _verifications.add(verification);
    notifyListeners();
  }

  void approveFarmer(String verificationId) {
    final idx = _verifications.indexWhere((v) => v.id == verificationId);
    if (idx != -1) {
      _verifications[idx].status = 'approved';
      final name = _verifications[idx].name;
      addNotification('Farmer Verified', '$name\'s farm has been approved.');
      notifyListeners();
    }
  }

  void rejectFarmer(String verificationId) {
    final idx = _verifications.indexWhere((v) => v.id == verificationId);
    if (idx != -1) {
      _verifications[idx].status = 'rejected';
      notifyListeners();
    }
  }

  Future<void> refreshContracts() async {
    if (token == null) return;
    try {
      final List<dynamic> backendContracts = await ContractApi.fetchContracts(token!);
      final List<BidOffer> loaded = [];
      for (var json in backendContracts) {
        final List<dynamic> items = json['items'] ?? [];
        if (items.isEmpty) continue;
        final item = items[0];
        final String prodId = item['product_id'] ?? '';
        
        MarketProduct prod = products.firstWhere(
          (p) => p.id == prodId,
          orElse: () => MarketProduct(
            id: prodId,
            name: 'Crop Product',
            category: 'Grains',
            price: (item['agreed_price'] as num?)?.toDouble() ?? 0.0,
            unit: mapUnitToFrontendHelper(item['unit_type']),
            currency: 'USD',
            quantity: (item['agreed_quantity'] as num?)?.toDouble() ?? 0.0,
            farmerName: 'Farmer',
            location: 'Cambodia',
            description: '',
            imageUrl: 'https://images.unsplash.com/photo-1592982537447-7440770cbfc9?w=600',
          ),
        );
        
        String uiStatus = 'pending';
        if (json['contract_status'] == 'ACTIVE') {
          uiStatus = 'accepted';
        } else if (json['contract_status'] == 'TERMINATED') {
          uiStatus = 'rejected';
        }
        
        loaded.add(BidOffer(
          id: json['id'] ?? '',
          product: prod,
          buyerName: json['buyer_name'] ?? 'Buyer',
          buyerId: json['buyer_id']?.toString(),
          sellerId: json['seller_id']?.toString(),
          offeredPrice: (item['agreed_price'] as num?)?.toDouble() ?? 0.0,
          quantity: (item['agreed_quantity'] as num?)?.toDouble() ?? 0.0,
          status: uiStatus,
          chatMessages: ['System: Negotiation started.'],
          startDate: DateTime.tryParse(json['start_date']?.toString() ?? ''),
          endDate: DateTime.tryParse(json['end_date']?.toString() ?? ''),
        ));
      }
      _negotiations.clear();
      _negotiations.addAll(loaded);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh contracts: $e');
    }
  }

  void _placeBidMock(MarketProduct product, double price, double qty) {
    final myId = userProfile?['id']?.toString();
    final existingIndex = _negotiations.indexWhere((n) => n.product.id == product.id && n.buyerId == myId);
    if (existingIndex != -1) {
      _negotiations[existingIndex].offeredPrice = price;
      _negotiations[existingIndex].quantity = qty;
      _negotiations[existingIndex].status = 'pending';
      _negotiations[existingIndex].chatMessages.add('Buyer: Offered \$$price / $qty units');
    } else {
      _negotiations.add(
        BidOffer(
          id: 'b_${DateTime.now().millisecondsSinceEpoch}',
          product: product,
          buyerName: userName,
          buyerId: myId,
          sellerId: product.sellerId,
          offeredPrice: price,
          quantity: qty,
          chatMessages: [
            'System: Negotiation started.',
            'Buyer: I would like to offer \$$price per ${product.unit} for $qty ${product.unit}s.'
          ],
        ),
      );
    }
    addNotification('Bid Placed', 'You offered \$$price/$qty for ${product.name}.');
    notifyListeners();
  }

  /// Returns null on success, or a raw backend error code (see `errors.py`)
  /// on failure — callers are responsible for translating that into a
  /// user-facing message rather than swallowing it silently.
  Future<String?> placeBid(MarketProduct product, double price, double qty) async {
    if (token == null) {
      _placeBidMock(product, price, qty);
      return null;
    }
    try {
      await ContractApi.createContract(token!, {
        'seller_id': product.sellerId ?? '',
        'buyer_id': userProfile?['id'] ?? '',
        'terms_description': 'Negotiation for ${product.name}',
        'start_date': DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String(),
        'end_date': DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String(),
        'contract_status': 'DRAFT',
        'items': [
          {
            'product_id': product.id,
            'agreed_price': price,
            'agreed_quantity': qty,
            'unit_type': mapUnitToBackendHelper(product.unit),
          }
        ]
      });
      await refreshContracts();
      addNotification('Bid Placed', 'You offered \$$price/$qty for ${product.name}.');
      return null;
    } catch (e) {
      debugPrint('Failed to place bid: $e');
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> counterOffer(String bidId, double newPrice) async {
    if (token == null) {
      final index = _negotiations.indexWhere((n) => n.id == bidId);
      if (index != -1) {
        _negotiations[index].offeredPrice = newPrice;
        _negotiations[index].status = 'counter_offered';
        _negotiations[index].chatMessages.add('Farmer: Counter-offered at \$$newPrice');
        notifyListeners();
      }
      return null;
    }
    try {
      final bid = _negotiations.firstWhere((n) => n.id == bidId);
      await ContractApi.updateContract(token!, bidId, {
        'items': [
          {
            'product_id': bid.product.id,
            'agreed_price': newPrice,
            'agreed_quantity': bid.quantity,
            'unit_type': mapUnitToBackendHelper(bid.product.unit),
          }
        ]
      });
      await refreshContracts();
      return null;
    } catch (e) {
      debugPrint('Failed to submit counter offer: $e');
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Accepting/activating a contract is the seller's (farmer's) call, not
  /// the buyer's — the backend now enforces that too, so a buyer calling
  /// this on their own proposal will get a translatable error back.
  Future<String?> acceptBid(String bidId) async {
    if (token == null) {
      final index = _negotiations.indexWhere((n) => n.id == bidId);
      if (index != -1) {
        _negotiations[index].status = 'accepted';
        _negotiations[index].chatMessages.add('System: Bid accepted by Farmer!');
        addNotification('Bid Accepted!', 'Your bid on ${_negotiations[index].product.name} was accepted!');
        notifyListeners();
      }
      return null;
    }
    try {
      await ContractApi.updateContract(token!, bidId, {
        'contract_status': 'ACTIVE',
      });
      await refreshContracts();
      return null;
    } catch (e) {
      debugPrint('Failed to accept bid: $e');
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> rejectBid(String bidId) async {
    if (token == null) {
      final index = _negotiations.indexWhere((n) => n.id == bidId);
      if (index != -1) {
        _negotiations[index].status = 'rejected';
        _negotiations[index].chatMessages.add('System: Offer declined.');
        notifyListeners();
      }
      return null;
    }
    try {
      await ContractApi.updateContract(token!, bidId, {
        'contract_status': 'TERMINATED',
      });
      await refreshContracts();
      return null;
    } catch (e) {
      debugPrint('Failed to reject bid: $e');
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}
