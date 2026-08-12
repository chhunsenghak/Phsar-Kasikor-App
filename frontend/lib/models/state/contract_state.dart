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
    case 'MULTIPLE_CURRENCIES_IN_CONTRACT':
      return state.translate('error_multiple_currencies_in_contract');
    case 'NO_ITEMS_IN_CONTRACT':
      return state.translate('error_no_items_in_contract');
    case 'DEPOSIT_PERCENTAGE_REQUIRED':
      return state.translate('error_deposit_percentage_required');
    case 'CONTRACT_ACTIVATION_REQUIRES_DEPOSIT':
      return state.translate('error_contract_activation_requires_deposit');
    case 'CONTRACT_DEPOSIT_ALREADY_PAID':
      return state.translate('error_contract_deposit_already_paid');
    case 'CONTRACT_DEPOSIT_NOT_SET':
      return state.translate('error_contract_deposit_not_set');
    case 'INVALID_CONTRACT_STATUS_TRANSITION':
      return state.translate('error_invalid_contract_status_transition');
    case 'ONLY_SELLER_CAN_REQUEST_FINAL_PAYMENT':
      return state.translate('error_only_seller_can_request_final_payment');
    case 'DELIVERY_METHOD_REQUIRED':
      return state.translate('error_delivery_method_required');
    case 'DELIVERY_FEE_REQUIRED':
      return state.translate('error_delivery_fee_required');
    case 'CONTRACT_COMPLETION_REQUIRES_FINAL_PAYMENT':
      return state.translate('error_contract_completion_requires_final_payment');
    case 'CONTRACT_FINAL_PAYMENT_ALREADY_PAID':
      return state.translate('error_contract_final_payment_already_paid');
    case 'CONTRACT_FINAL_PAYMENT_NOT_SET':
      return state.translate('error_contract_final_payment_not_set');
    case 'CONTRACT_FULFILLMENT_NOT_MANUAL':
      return state.translate('error_contract_fulfillment_not_manual');
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
        final List<dynamic> rawItems = json['items'] ?? [];
        if (rawItems.isEmpty) continue;

        final List<ContractLineItem> items = rawItems.map((item) {
          final String prodId = item['product_id'] ?? '';
          final MarketProduct prod = products.firstWhere(
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
          return ContractLineItem(
            product: prod,
            agreedPrice: (item['agreed_price'] as num?)?.toDouble() ?? 0.0,
            agreedQuantity: (item['agreed_quantity'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();

        final String backendStatus = json['contract_status']?.toString() ?? 'DRAFT';
        String uiStatus = switch (backendStatus) {
          'PENDING_DEPOSIT' => 'pending_deposit',
          'ACTIVE' => 'accepted',
          'PENDING_FINAL_PAYMENT' => 'pending_final_payment',
          'IN_FULFILLMENT' => 'in_fulfillment',
          'COMPLETED' => 'completed',
          'TERMINATED' => 'rejected',
          _ => 'pending',
        };

        loaded.add(BidOffer(
          id: json['id'] ?? '',
          items: items,
          buyerName: json['buyer_name'] ?? 'Buyer',
          sellerName: json['seller_name'] ?? 'Farmer',
          buyerId: json['buyer_id']?.toString(),
          sellerId: json['seller_id']?.toString(),
          contractStatus: backendStatus,
          status: uiStatus,
          chatMessages: ['System: Negotiation started.'],
          startDate: DateTime.tryParse(json['start_date']?.toString() ?? ''),
          endDate: DateTime.tryParse(json['end_date']?.toString() ?? ''),
          depositPercentage: (json['deposit_percentage'] as num?)?.toDouble(),
          depositAmount: (json['deposit_amount'] as num?)?.toDouble(),
          depositCurrency: json['deposit_currency']?.toString(),
          depositStatus: json['deposit_status']?.toString(),
          deliveryMethod: json['delivery_method']?.toString(),
          deliveryFee: (json['delivery_fee'] as num?)?.toDouble(),
          finalAmount: (json['final_amount'] as num?)?.toDouble(),
          finalPaymentStatus: json['final_payment_status']?.toString(),
          fulfillmentOrderId: json['fulfillment_order_id']?.toString(),
        ));
      }
      _negotiations.clear();
      _negotiations.addAll(loaded);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh contracts: $e');
    }
  }

  /// Guest/logged-out browsing only — a local-only single-item placeholder
  /// that never reaches a real backend, so multi-item/deposit support adds
  /// no value here.
  void _placeBidMock(MarketProduct product, double price, double qty) {
    final myId = userProfile?['id']?.toString();
    final existingIndex = _negotiations.indexWhere((n) => n.product.id == product.id && n.buyerId == myId);
    if (existingIndex != -1) {
      _negotiations[existingIndex].items = [ContractLineItem(product: product, agreedPrice: price, agreedQuantity: qty)];
      _negotiations[existingIndex].status = 'pending';
      _negotiations[existingIndex].chatMessages.add('Buyer: Offered \$$price / $qty units');
    } else {
      _negotiations.add(
        BidOffer(
          id: 'b_${DateTime.now().millisecondsSinceEpoch}',
          items: [ContractLineItem(product: product, agreedPrice: price, agreedQuantity: qty)],
          buyerName: userName,
          sellerName: product.farmerName,
          buyerId: myId,
          sellerId: product.sellerId,
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

  /// Proposes (or, when logged out, mocks) a multi-product contract with
  /// [sellerId]. Returns null on success, or a raw backend error code (see
  /// `errors.py`) on failure — callers translate that via
  /// [friendlyContractErrorMessage] rather than it being swallowed silently.
  Future<String?> placeBid(
    String sellerId,
    List<ContractLineItem> items, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (items.isEmpty) return 'NO_ITEMS_IN_CONTRACT';
    if (token == null) {
      _placeBidMock(items.first.product, items.first.agreedPrice, items.first.agreedQuantity);
      return null;
    }
    try {
      await ContractApi.createContract(token!, {
        'seller_id': sellerId,
        'buyer_id': userProfile?['id'] ?? '',
        'terms_description': 'Wholesale contract proposal',
        'start_date': startDate.toUtc().toIso8601String(),
        'end_date': endDate.toUtc().toIso8601String(),
        'contract_status': 'DRAFT',
        'items': items
            .map((i) => {
                  'product_id': i.product.id,
                  'agreed_price': i.agreedPrice,
                  'agreed_quantity': i.agreedQuantity,
                  'unit_type': mapUnitToBackendHelper(i.product.unit),
                })
            .toList(),
      });
      await refreshContracts();
      addNotification('Contract Proposed', 'You proposed a contract with ${items.length} item(s).');
      return null;
    } catch (e) {
      debugPrint('Failed to place bid: $e');
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Replaces every line item on a still-DRAFT contract — used for a
  /// counter-offer, reusing the same multi-item builder UI as a fresh
  /// proposal rather than a separate single-price edit dialog.
  Future<String?> counterOffer(
    String bidId,
    List<ContractLineItem> items, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (items.isEmpty) return 'NO_ITEMS_IN_CONTRACT';
    if (token == null) {
      final index = _negotiations.indexWhere((n) => n.id == bidId);
      if (index != -1) {
        _negotiations[index].items = items;
        _negotiations[index].status = 'counter_offered';
        _negotiations[index].chatMessages.add('Farmer: Counter-offered at \$${items.first.agreedPrice}');
        notifyListeners();
      }
      return null;
    }
    try {
      await ContractApi.updateContract(token!, bidId, {
        'items': items
            .map((i) => {
                  'product_id': i.product.id,
                  'agreed_price': i.agreedPrice,
                  'agreed_quantity': i.agreedQuantity,
                  'unit_type': mapUnitToBackendHelper(i.product.unit),
                })
            .toList(),
        'start_date': startDate.toUtc().toIso8601String(),
        'end_date': endDate.toUtc().toIso8601String(),
      });
      await refreshContracts();
      return null;
    } catch (e) {
      debugPrint('Failed to submit counter offer: $e');
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Accepting a proposal is the seller's (farmer's) call, not the buyer's —
  /// the backend enforces that too. Accepting now requires a deposit
  /// percentage: the contract moves to PENDING_DEPOSIT, not straight to
  /// ACTIVE — it only becomes ACTIVE once the buyer's deposit is verified
  /// paid (see ContractDepositCheckoutScreen).
  Future<String?> acceptBid(String bidId, double depositPercentage) async {
    if (token == null) {
      final index = _negotiations.indexWhere((n) => n.id == bidId);
      if (index != -1) {
        _negotiations[index].contractStatus = 'PENDING_DEPOSIT';
        _negotiations[index].status = 'pending_deposit';
        _negotiations[index].depositPercentage = depositPercentage;
        _negotiations[index].depositAmount = _negotiations[index].totalValue * depositPercentage / 100;
        _negotiations[index].chatMessages.add('System: Accepted by Farmer — deposit required.');
        notifyListeners();
      }
      return null;
    }
    try {
      await ContractApi.updateContract(token!, bidId, {
        'contract_status': 'PENDING_DEPOSIT',
        'deposit_percentage': depositPercentage,
      });
      await refreshContracts();
      return null;
    } catch (e) {
      debugPrint('Failed to accept bid: $e');
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Generates (or idempotently re-fetches) the buyer's booking-deposit
  /// KHQR for an accepted contract. Returns the raw
  /// `{qr_string, md5, qr_image_base64}` map, or throws on failure.
  Future<Map<String, dynamic>> generateContractDepositQr(String contractId) async {
    return ContractApi.generateDepositKhqr(token!, contractId);
  }

  /// Re-checks the deposit KHQR against Bakong; returns 'paid'/'unpaid'/
  /// 'unavailable'. On 'paid', refreshes contracts so the caller's ACTIVE
  /// status shows up immediately.
  Future<String> confirmContractDeposit(String contractId, String md5Hash) async {
    final res = await ContractApi.confirmDepositKhqr(token!, contractId, md5Hash);
    final status = res['status']?.toString() ?? 'unavailable';
    if (status == 'paid') await refreshContracts();
    return status;
  }

  /// Requesting the final payment is the seller's call, once ACTIVE — the
  /// backend enforces that too. Unlike accepting with a deposit, this can
  /// resolve straight to COMPLETED with no further payment step if the
  /// deposit already covered everything (a pickup with no remaining
  /// balance) — refreshContracts() picks up whichever status results.
  Future<String?> requestFinalPayment(
    String bidId, {
    required String deliveryMethod,
    double? deliveryFee,
  }) async {
    if (token == null) return null;
    try {
      await ContractApi.updateContract(token!, bidId, {
        'contract_status': 'PENDING_FINAL_PAYMENT',
        'delivery_method': deliveryMethod,
        if (deliveryMethod == 'DELIVERY') 'delivery_fee': deliveryFee,
      });
      await refreshContracts();
      return null;
    } catch (e) {
      debugPrint('Failed to request final payment: $e');
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Generates (or idempotently re-fetches) the buyer's final-balance KHQR
  /// once the seller has requested it. Returns the raw
  /// `{qr_string, md5, qr_image_base64}` map, or throws on failure.
  Future<Map<String, dynamic>> generateContractFinalPaymentQr(String contractId) async {
    return ContractApi.generateFinalPaymentKhqr(token!, contractId);
  }

  /// Re-checks the final-payment KHQR against Bakong; returns
  /// 'paid'/'unpaid'/'unavailable'. On 'paid', refreshes contracts so the
  /// caller's COMPLETED status shows up immediately.
  Future<String> confirmContractFinalPayment(String contractId, String md5Hash) async {
    final res = await ContractApi.confirmFinalPaymentKhqr(token!, contractId, md5Hash);
    final status = res['status']?.toString() ?? 'unavailable';
    if (status == 'paid') await refreshContracts();
    return status;
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
