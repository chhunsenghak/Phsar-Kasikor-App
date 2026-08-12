import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class OrderApi {
  static Future<Map<String, dynamic>> cancelOrder(String token, String orderId) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/orders/$orderId/cancel'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchOrders(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/orders/'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  /// Creates one order containing [items], each `{'product_id': ..., 'quantity': ...}`.
  ///
  /// All items must belong to the same seller — the backend rejects a mixed
  /// order with `MULTIPLE_SELLERS_IN_ORDER`. Split per seller before calling.
  ///
  /// [deliveryLat]/[deliveryLng] are required by the backend whenever
  /// [deliveryMethod] is `DELIVERY` — it's the buyer's chosen drop-off point.
  static Future<Map<String, dynamic>> createOrder(
    String token, {
    required List<Map<String, dynamic>> items,
    String paymentMethod = 'KHQR',
    String deliveryMethod = 'DELIVERY',
    String? deliveryAddressText,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/orders/'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({
        'items': items,
        'payment_method': paymentMethod,
        'delivery_method': deliveryMethod,
        'delivery_address_text': ?deliveryAddressText,
        'delivery_lat': ?deliveryLat,
        'delivery_lng': ?deliveryLng,
      }),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  /// Convenience wrapper for the single-crop "Buy Now" path.
  static Future<Map<String, dynamic>> createSingleItemOrder(
    String token, {
    required String productId,
    required double quantity,
    String paymentMethod = 'KHQR',
    String deliveryMethod = 'DELIVERY',
    String? deliveryAddressText,
    double? deliveryLat,
    double? deliveryLng,
  }) {
    return createOrder(
      token,
      items: [
        {'product_id': productId, 'quantity': quantity},
      ],
      paymentMethod: paymentMethod,
      deliveryMethod: deliveryMethod,
      deliveryAddressText: deliveryAddressText,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
    );
  }

  /// Advances the order's fulfillment stage. Seller-only on the backend —
  /// there is no `paymentStatus` parameter here anymore: payment_status is
  /// never settable by the buyer or seller directly, see [PaymentApi].
  ///
  /// [contactPhone]/[deliveryNotes]/[actualDeliveryCost] are only stored
  /// when [orderStatus] is `SHIPPED` — the backend ignores them otherwise.
  /// [actualDeliveryCost] is a private record of what the farmer paid a
  /// transporter; it's never shown to the buyer or added to the order total.
  static Future<Map<String, dynamic>> updateOrder(
    String token,
    String orderId, {
    required String orderStatus,
    String? contactPhone,
    String? deliveryNotes,
    double? actualDeliveryCost,
  }) async {
    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/orders/$orderId'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({
        'order_status': orderStatus,
        'contact_phone': ?contactPhone,
        'delivery_notes': ?deliveryNotes,
        'actual_delivery_cost': ?actualDeliveryCost,
      }),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchOrderDetails(String token, String orderId) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/orders/$orderId'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  /// Admin-only. Every KHQR order still awaiting payment confirmation — the
  /// queue for the manual-confirm fallback used when automatic Bakong
  /// verification can't run (e.g. the daily call cap is exhausted).
  static Future<List<dynamic>> fetchPendingKhqrPayments(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/orders/admin/pending-payments'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  /// Admin-only manual override marking a KHQR order as paid. This is a
  /// fallback for when automatic Bakong verification isn't available —
  /// never call this off a buyer's or seller's own say-so.
  static Future<Map<String, dynamic>> confirmPaymentAsAdmin(String token, String orderId) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/orders/$orderId/confirm-payment'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
