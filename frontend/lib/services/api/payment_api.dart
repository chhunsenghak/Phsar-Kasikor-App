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

  /// Re-verifies this KHQR against Bakong and, only on a real "paid" result,
  /// flips every order linked to it. Returns `{'status': 'paid'|'unpaid'|'unavailable',
  /// 'confirmed_order_ids': [...]}` — never trusts the caller, so a buyer
  /// tapping this repeatedly cannot mark their own order paid.
  static Future<Map<String, dynamic>> confirmKhqrPayment(String token, String md5Hash) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/payments/khqr/$md5Hash/confirm'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
