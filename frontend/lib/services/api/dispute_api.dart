import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class DisputeApi {
  static Future<Map<String, dynamic>> createDispute(String token, String orderId, String reason) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/disputes/'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({'order_id': orderId, 'reason': reason}),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchMyDisputes(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/disputes/'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<List<dynamic>> fetchAllDisputes(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/disputes/admin/all'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> resolveDispute(
    String token,
    String disputeId, {
    required String status,
    String? resolutionNote,
    double? refundAmount,
  }) async {
    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/disputes/$disputeId/resolve'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({
        'status': status,
        'resolution_note': resolutionNote,
        'refund_amount': refundAmount,
      }),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
