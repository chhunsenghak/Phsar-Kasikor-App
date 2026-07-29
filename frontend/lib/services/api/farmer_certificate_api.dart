import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class FarmerCertificateApi {
  static Future<Map<String, dynamic>> submitCertificate(String token, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/farmer-certificates/'),
      headers: BaseApi.getHeaders(token),
      body: jsonEncode(data),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchCertificates(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/farmer-certificates/'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }
}
