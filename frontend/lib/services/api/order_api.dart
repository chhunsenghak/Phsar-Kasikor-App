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
}
