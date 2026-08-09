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
        if (deliveryAddressText != null) 'delivery_address_text': deliveryAddressText,
        if (deliveryLat != null) 'delivery_lat': deliveryLat,
        if (deliveryLng != null) 'delivery_lng': deliveryLng,
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
  /// never settable by the buyer or seller directly, see [PaymentApi] and
  /// [confirmPayment].
  static Future<Map<String, dynamic>> updateOrder(
    String token,
    String orderId, {
    required String orderStatus,
  }) async {
    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/orders/$orderId'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({'order_status': orderStatus}),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  /// Seller-side manual "I received the payment" fallback for when
  /// automatic Bakong verification isn't available. Only the seller of the
  /// order may call this.
  static Future<Map<String, dynamic>> confirmPayment(String token, String orderId) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/orders/$orderId/confirm-payment'),
      headers: BaseApi.getHeaders(token, json: false),
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
}
