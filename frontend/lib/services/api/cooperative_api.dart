import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class CooperativeApi {
  static Future<Map<String, dynamic>> fetchMine(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/cooperatives/mine'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchMembers(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/cooperatives/members'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<List<dynamic>> fetchStockSummary(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/cooperatives/stock-summary'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> inviteMember(String token, String identifier) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/cooperatives/members/invite'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({'identifier': identifier}),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<void> removeMember(String token, String memberId) async {
    final response = await http.delete(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/cooperatives/members/$memberId'),
      headers: BaseApi.getHeaders(token),
    );
    BaseApi.handleResponse(response);
  }

  static Future<List<dynamic>> fetchMyInvitations(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/cooperatives/my-invitations'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> respondToInvitation(String token, String memberId, bool accept) async {
    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/cooperatives/members/$memberId/respond'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({'status': accept ? 'active' : 'rejected'}),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
