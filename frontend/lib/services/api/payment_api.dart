import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class PaymentApi {
  static Future<Map<String, dynamic>> generateKhqr(String token, List<String> orderIds) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/payments/khqr'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({'order_ids': orderIds}),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> checkKhqrStatus(String token, String md5Hash) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/payments/khqr/$md5Hash/status'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
