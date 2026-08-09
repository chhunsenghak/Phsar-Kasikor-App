import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

/// Live tracking for one order's DELIVERY fulfillment — destination lives on
/// the order itself (see [OrderApi.fetchOrderDetails]); this is the
/// transporter's last known position and delivery-stage status.
class DeliveryApi {
  /// Returns null when the order has no delivery record (e.g. it's a PICKUP
  /// order, or the backend hasn't seeded one) rather than throwing, so the
  /// caller can simply omit the tracking UI.
  static Future<Map<String, dynamic>?> fetchForOrder(
    String token,
    String orderId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '${BaseApi.baseUrl}/api/${BaseApi.version}/deliveries/order/$orderId',
      ),
      headers: BaseApi.getHeaders(token),
    );
    if (response.statusCode == 404) return null;
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  /// Seller-only: pushes a live position ping for the order currently being
  /// fulfilled.
  static Future<Map<String, dynamic>> updateLocation(
    String token,
    String orderId, {
    required double lat,
    required double lng,
  }) async {
    final response = await http.put(
      Uri.parse(
        '${BaseApi.baseUrl}/api/${BaseApi.version}/deliveries/order/$orderId/location',
      ),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({
        'current_location_lat': lat,
        'current_location_lng': lng,
      }),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
