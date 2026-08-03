import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class UserApi {
  static Future<Map<String, dynamic>> updateProfileLocation(
    String token, {
    required String province,
    required String district,
    required String commune,
    required String village,
    required String streetAddress,
  }) async {
    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/users/me'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({
        'province': province,
        'district': district,
        'commune': commune,
        'village': village,
        'street_address': streetAddress,
      }),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchAddressRequests(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/address-requests/'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> submitAddressRequest(
    String token, {
    required String province,
    required String district,
    required String commune,
    required String village,
    required String streetAddress,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/address-requests/'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({
        'province': province,
        'district': district,
        'commune': commune,
        'village': village,
        'street_address': streetAddress,
        'role': role,
      }),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> approveAddressRequest(String token, String requestId) async {
    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/address-requests/$requestId/approve'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> rejectAddressRequest(String token, String requestId) async {
    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/address-requests/$requestId/reject'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateProfileInfo(
    String token, {
    required String username,
    required String phoneNumber,
    required String email,
  }) async {
    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/users/me'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({
        'username': username,
        'phoneNumber': phoneNumber,
        'email': email,
      }),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
