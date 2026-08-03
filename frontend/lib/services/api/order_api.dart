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
  static Future<Map<String, dynamic>> createOrder(
    String token, {
    required List<Map<String, dynamic>> items,
    String paymentMethod = 'KHQR',
    String deliveryMethod = 'DELIVERY',
  }) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/orders/'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({
        'items': items,
        'payment_method': paymentMethod,
        'delivery_method': deliveryMethod,
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
  }) {
    return createOrder(
      token,
      items: [
        {'product_id': productId, 'quantity': quantity},
      ],
      paymentMethod: paymentMethod,
      deliveryMethod: deliveryMethod,
    );
  }

  static Future<Map<String, dynamic>> updateOrder(
    String token,
    String orderId, {
    String? paymentStatus,
    String? orderStatus,
  }) async {
    final Map<String, dynamic> body = {};
    if (paymentStatus != null) body['payment_status'] = paymentStatus;
    if (orderStatus != null) body['order_status'] = orderStatus;

    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/orders/$orderId'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode(body),
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
