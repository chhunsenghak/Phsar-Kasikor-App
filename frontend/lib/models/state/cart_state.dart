import 'base_app_state.dart';

/// Formats an amount using the convention for the given currency.
String formatCurrencyAmount(double amount, String currency) {
  if (currency == 'KHR') {
    final String val = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$val ៛';
  }
  return '\$${amount.toStringAsFixed(2)}';
}

/// Flat delivery fee charged once per order (i.e. once per seller/currency group).
double deliveryFeeFor(String currency) => currency == 'KHR' ? 8000.0 : 2.0;

/// Resolves the currency a raw order record (as returned by [OrderApi]) is
/// denominated in.
///
/// Prefers the backend's own `currency` field. Falls back to looking up the
/// first line item's product for orders placed before that field existed —
/// without this, every historical order silently reads as USD regardless of
/// what it was actually priced in.
String resolveOrderCurrency(
  Map<String, dynamic> order,
  List<MarketProduct> knownProducts,
) {
  final String? explicit = order['currency']?.toString();
  if (explicit != null && explicit.isNotEmpty) return explicit;

  final items = order['items'] as List<dynamic>? ?? [];
  if (items.isNotEmpty) {
    final firstProductId = items.first['product_id'];
    for (final product in knownProducts) {
      if (product.id == firstProductId) return product.currency;
    }
  }
  return 'USD';
}

class CartItem {
  final MarketProduct product;
  double quantity;

  CartItem({
    required this.product,
    required this.quantity,
  });

  double get itemTotal => product.price * quantity;

  String get formattedItemTotal => formatCurrencyAmount(itemTotal, product.currency);

  /// Identifies the seller. Falls back to the farmer name when the backend did
  /// not supply a seller id, so grouping still works on locally seeded data.
  String get sellerKey => product.sellerId ?? 'name:${product.farmerName}';

  /// The backend rejects an order that spans multiple sellers, and an Order row
  /// stores a single untagged total, so a currency change must also split.
  String get groupKey => '$sellerKey|${product.currency}';
}

/// One checkout group == one backend order.
class CartGroup {
  final String groupKey;
  final String sellerKey;
  final String sellerName;
  final String currency;
  final List<CartItem> items;

  CartGroup({
    required this.groupKey,
    required this.sellerKey,
    required this.sellerName,
    required this.currency,
    required this.items,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.itemTotal);

  double deliveryFee(String deliveryMethod) =>
      deliveryMethod == 'PICKUP' ? 0.0 : deliveryFeeFor(currency);

  double total(String deliveryMethod) => subtotal + deliveryFee(deliveryMethod);

  List<Map<String, dynamic>> toOrderItems() => items
      .map((item) => {
            'product_id': item.product.id,
            'quantity': item.quantity,
          })
      .toList();
}

/// A [CartGroup] that has been accepted by the backend as a real order.
class PlacedOrder {
  final String orderId;
  final CartGroup group;
  final String deliveryMethod;

  /// Total as recorded by the backend. Set only when settling an order that was
  /// created earlier, where the fee charged at the time is not recoverable —
  /// the orders table stores a goods total with no delivery component.
  final double? recordedTotal;

  PlacedOrder({
    required this.orderId,
    required this.group,
    required this.deliveryMethod,
  }) : recordedTotal = null;

  /// For paying an order that already exists server-side.
  PlacedOrder.existing({
    required this.orderId,
    required this.group,
    required double totalAmount,
    this.deliveryMethod = 'DELIVERY',
  }) : recordedTotal = totalAmount;

  /// False when the delivery fee is unknown, so the UI can omit the row rather
  /// than invent a number.
  bool get hasDeliveryFee => recordedTotal == null;

  String get currency => group.currency;
  double get subtotal => recordedTotal ?? group.subtotal;
  double get deliveryFee =>
      recordedTotal == null ? group.deliveryFee(deliveryMethod) : 0.0;
  double get total => recordedTotal ?? group.total(deliveryMethod);
}

/// Groups [items] into one bucket per seller+currency — each bucket becomes one
/// backend order. Group order is stable: a group appears where its first item
/// did, so the checkout list does not reshuffle between rebuilds.
List<CartGroup> groupCartItems(List<CartItem> items) {
  final Map<String, CartGroup> groups = {};
  for (final item in items) {
    groups
        .putIfAbsent(
          item.groupKey,
          () => CartGroup(
            groupKey: item.groupKey,
            sellerKey: item.sellerKey,
            sellerName: item.product.farmerName,
            currency: item.product.currency,
            items: [],
          ),
        )
        .items
        .add(item);
  }
  return groups.values.toList();
}

/// Outcome of a mutation so the UI can tell the buyer what actually happened.
class CartMutationResult {
  /// Quantity in the cart after the mutation.
  final double resultingQuantity;

  /// True when the request was reduced to fit the seller's available stock.
  final bool cappedToStock;

  const CartMutationResult({
    required this.resultingQuantity,
    this.cappedToStock = false,
  });
}

mixin CartStateMixin on BaseAppState {
  final List<CartItem> _cartItems = [];
  List<CartItem> get cartItems => List.unmodifiable(_cartItems);

  bool get isCartEmpty => _cartItems.isEmpty;

  /// Number of distinct crops in the cart (what the badge shows).
  int get cartItemCount => _cartItems.length;

  double get cartTotalQuantity =>
      _cartItems.fold(0.0, (sum, item) => sum + item.quantity);

  double quantityInCart(String productId) {
    final index = _cartItems.indexWhere((item) => item.product.id == productId);
    return index >= 0 ? _cartItems[index].quantity : 0.0;
  }

  /// One bucket per seller+currency, i.e. one backend order per group.
  List<CartGroup> get cartGroups => groupCartItems(_cartItems);

  /// Subtotals keyed by currency — the cart may legitimately hold both.
  Map<String, double> get cartSubtotalsByCurrency {
    final Map<String, double> totals = {};
    for (final item in _cartItems) {
      totals[item.product.currency] =
          (totals[item.product.currency] ?? 0.0) + item.itemTotal;
    }
    return totals;
  }

  /// Adds [quantity] on top of whatever is already in the cart for [product],
  /// clamped to the stock the farmer has listed.
  CartMutationResult addToCart(MarketProduct product, double quantity) {
    final double maxStock = product.quantity;
    final index = _cartItems.indexWhere((item) => item.product.id == product.id);
    final double existing = index >= 0 ? _cartItems[index].quantity : 0.0;

    final double requested = existing + quantity;
    final double clamped = requested > maxStock ? maxStock : requested;

    if (clamped <= 0) {
      if (index >= 0) _cartItems.removeAt(index);
      notifyListeners();
      return const CartMutationResult(resultingQuantity: 0, cappedToStock: true);
    }

    if (index >= 0) {
      _cartItems[index].quantity = clamped;
    } else {
      _cartItems.add(CartItem(product: product, quantity: clamped));
    }
    notifyListeners();
    return CartMutationResult(
      resultingQuantity: clamped,
      cappedToStock: clamped < requested,
    );
  }

  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  /// Sets an absolute quantity. Removes the line at zero, clamps to stock.
  CartMutationResult updateCartQuantity(String productId, double quantity) {
    final index = _cartItems.indexWhere((item) => item.product.id == productId);
    if (index < 0) {
      return const CartMutationResult(resultingQuantity: 0);
    }

    if (quantity <= 0) {
      _cartItems.removeAt(index);
      notifyListeners();
      return const CartMutationResult(resultingQuantity: 0);
    }

    final double maxStock = _cartItems[index].product.quantity;
    final double clamped = quantity > maxStock ? maxStock : quantity;
    _cartItems[index].quantity = clamped;
    notifyListeners();
    return CartMutationResult(
      resultingQuantity: clamped,
      cappedToStock: clamped < quantity,
    );
  }

  /// Drops only the lines that were successfully ordered, so a partial failure
  /// leaves the unplaced items in the cart for a retry.
  void removeCartItems(Iterable<String> productIds) {
    final ids = productIds.toSet();
    _cartItems.removeWhere((item) => ids.contains(item.product.id));
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }
}
