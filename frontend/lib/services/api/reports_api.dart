import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class ReportsApi {
  static Future<Map<String, dynamic>> reportProduct(String token, String productId, String reason) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/reports/products/$productId/report'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({'reason': reason}),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchAdminReports(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/reports/admin/reports'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> resolveReport(String token, String reportId, String status, {String? feedback}) async {
    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/reports/admin/reports/$reportId/resolve'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({
        'status': status,
        'admin_feedback': feedback,
      }),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
