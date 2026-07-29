import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class ContractApi {
  static Future<List<dynamic>> fetchContracts(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createContract(String token, Map<String, dynamic> contractData) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/'),
      headers: BaseApi.getHeaders(token),
      body: jsonEncode(contractData),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateContract(String token, String contractId, Map<String, dynamic> contractData) async {
    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/$contractId'),
      headers: BaseApi.getHeaders(token),
      body: jsonEncode(contractData),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
