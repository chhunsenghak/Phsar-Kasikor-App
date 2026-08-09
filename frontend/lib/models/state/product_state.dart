import 'package:flutter/material.dart';
import '../../services/api/product_api.dart';
import '../../services/api/market_price_api.dart';
import 'base_app_state.dart';

mixin ProductStateMixin on BaseAppState {
  List<dynamic> _backendCategories = [];
  List<dynamic> get backendCategories => _backendCategories;

  final List<MarketProduct> _products = [];
  List<MarketProduct> get products => _products;

  final List<MarketPrice> _marketPrices = [];
  List<MarketPrice> get marketPrices => _marketPrices;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _selectedCategory = 'All';
  String get selectedCategory => _selectedCategory;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  List<MarketProduct> get filteredProducts {
    return _products.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            p.farmerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            p.location.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || p.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  String _mapUnitToBackend(String unit) {
    switch (unit.toLowerCase()) {
      case 'kg':
        return 'KG';
      case 'bag':
        return 'SACK';
      case 'ton':
        return 'TON';
      case 'hand':
        return 'BUNCH';
      default:
        return 'KG';
    }
  }

  String _mapCategoryToId(String categoryName) {
    final cleanName = categoryName.trim().toLowerCase();
    for (var c in _backendCategories) {
      if (c['name'].toString().trim().toLowerCase() == cleanName) {
        return c['id'].toString();
      }
    }
    switch (cleanName) {
      case 'grains':
        return 'c8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf';
      case 'vegetables':
        return 'v8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf';
      case 'fruits':
        return 'f8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf';
      default:
        return 'c8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf';
    }
  }

  String _mapIdToCategory(String? categoryId) {
    if (categoryId == null) return 'Grains';
    final cleanId = categoryId.toLowerCase();
    for (var c in _backendCategories) {
      if (c['id'].toString().toLowerCase() == cleanId) {
        return c['name']?.toString() ?? 'Grains';
      }
    }
    switch (cleanId) {
      case 'c8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf':
        return 'Grains';
      case 'v8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf':
        return 'Vegetables';
      case 'f8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf':
        return 'Fruits';
      default:
        return 'Grains';
    }
  }

  String _mapUnitToFrontend(String? unitType) {
    if (unitType == null) return 'kg';
    switch (unitType.toUpperCase()) {
      case 'KG':
        return 'kg';
      case 'SACK':
        return 'bag';
      case 'TON':
        return 'ton';
      case 'BUNCH':
        return 'hand';
      default:
        return 'kg';
    }
  }

  Future<void> refreshCategories() async {
    try {
      final List<dynamic> list = await ProductApi.fetchCategories();
      _backendCategories = list;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh categories: $e');
    }
  }

  Future<void> refreshProducts() async {
    try {
      final List<dynamic> backendProds = await ProductApi.fetchProducts();
      final List<MarketProduct> loaded = [];
      for (var json in backendProds) {
        loaded.add(MarketProduct(
          id: json['id'] ?? '',
          name: json['product_name'] ?? '',
          category: _mapIdToCategory(json['category_id']),
          price: (json['price_per_unit'] as num?)?.toDouble() ?? 0.0,
          unit: _mapUnitToFrontend(json['unit_type']),
          currency: json['currency'] ?? 'USD',
          quantity: (json['quantity_available'] as num?)?.toDouble() ?? 0.0,
          farmerName: json['seller_name'] ?? json['seller_username'] ?? 'Farmer',
          location: json['seller_province'] ?? 'Cambodia',
          description: json['quality_certification_metadata'] ?? 'No description.',
          imageUrl: json['image_url'] ?? 'https://images.unsplash.com/photo-1592982537447-7440770cbfc9?w=600',
          isVerifiedFarmer: true,
          sellerId: json['seller_id'],
          weightKgPerUnit: (json['weight_kg_per_unit'] as num?)?.toDouble(),
        ));
      }
      _products.clear();
      _products.addAll(loaded);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh products: $e');
    }
  }

  /// Returns null on success, or the raw backend error code on failure —
  /// same convention as [deleteProduct]. Without a return value here, the
  /// caller has no way to tell the user a create/edit actually failed (a
  /// validation error would otherwise be silently swallowed).
  Future<String?> addProduct(MarketProduct product) async {
    if (token == null) {
      _products.insert(0, product);
      notifyListeners();
      return null;
    }
    try {
      await ProductApi.createProduct(token!, {
        'product_name': product.name,
        'category_id': _mapCategoryToId(product.category),
        'price_per_unit': product.price,
        'unit_type': _mapUnitToBackend(product.unit),
        'currency': product.currency,
        'quantity_available': product.quantity,
        'harvest_date': DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0],
        'quality_certification_metadata': product.description,
        'image_url': product.imageUrl,
        'weight_kg_per_unit': product.weightKgPerUnit,
      });
      await refreshProducts();
      return null;
    } catch (e) {
      final errMsg = e.toString().replaceAll('Exception: ', '');
      debugPrint('Failed to create product: $errMsg');
      return errMsg;
    }
  }

  /// Returns null on success, or the raw backend error code on failure —
  /// see [addProduct].
  Future<String?> updateProduct(String productId, MarketProduct product) async {
    if (token == null) {
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        _products[index] = product;
        notifyListeners();
      }
      return null;
    }
    try {
      await ProductApi.updateProduct(token!, productId, {
        'product_name': product.name,
        'category_id': _mapCategoryToId(product.category),
        'price_per_unit': product.price,
        'unit_type': _mapUnitToBackend(product.unit),
        'currency': product.currency,
        'quantity_available': product.quantity,
        'harvest_date': DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0],
        'quality_certification_metadata': product.description,
        'image_url': product.imageUrl,
        'weight_kg_per_unit': product.weightKgPerUnit,
      });
      await refreshProducts();
      return null;
    } catch (e) {
      final errMsg = e.toString().replaceAll('Exception: ', '');
      debugPrint('Failed to update product: $errMsg');
      return errMsg;
    }
  }

  Future<String?> deleteProduct(String productId) async {
    if (token == null) {
      _products.removeWhere((p) => p.id == productId);
      notifyListeners();
      return null;
    }
    try {
      await ProductApi.deleteProduct(token!, productId);
      await refreshProducts();
      return null;
    } catch (e) {
      final errMsg = e.toString().replaceAll('Exception: ', '');
      debugPrint('Failed to delete product: $errMsg');
      return errMsg;
    }
  }

  Future<void> refreshMarketPrices() async {
    try {
      final List<dynamic> backendPrices = await MarketPriceApi.fetchMarketPrices();
      final List<MarketPrice> loaded = [];
      for (var json in backendPrices) {
        final double avg = (json['average_market_price'] as num?)?.toDouble() ?? 0.0;
        final double low = (json['lowest_price'] as num?)?.toDouble() ?? avg * 0.95;
        final double high = (json['highest_price'] as num?)?.toDouble() ?? avg * 1.05;
        
        String trend = 'stable';
        double change = 0.0;
        if (high > avg) {
          trend = 'up';
          change = ((high - avg) / avg) * 100;
        } else if (low < avg) {
          trend = 'down';
          change = ((low - avg) / avg) * 100;
        }
        
        loaded.add(MarketPrice(
          name: json['commodity_name'] ?? 'Crop',
          currentPrice: avg,
          changePercentage: double.parse(change.toStringAsFixed(1)),
          trend: trend,
        ));
      }
      _marketPrices.clear();
      _marketPrices.addAll(loaded);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh market prices: $e');
    }
  }

  // A helper exposure of unit converter that other mixins might need
  String mapUnitToBackendHelper(String unit) => _mapUnitToBackend(unit);
  String mapUnitToFrontendHelper(String? unitType) => _mapUnitToFrontend(unitType);
}
