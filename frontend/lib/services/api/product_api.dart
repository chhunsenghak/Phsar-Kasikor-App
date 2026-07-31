import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class ProductApi {
  static Future<List<dynamic>> fetchProducts() async {
    final response = await http.get(Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/products/'));
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createProduct(String token, Map<String, dynamic> productData) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/products/'),
      headers: BaseApi.getHeaders(token),
      body: jsonEncode(productData),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<void> deleteProduct(String token, String productId) async {
    final response = await http.delete(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/products/$productId'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    BaseApi.handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateProduct(String token, String productId, Map<String, dynamic> productData) async {
    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/products/$productId'),
      headers: BaseApi.getHeaders(token),
      body: jsonEncode(productData),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchCategories() async {
    final response = await http.get(Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/categories/'));
    return BaseApi.handleResponse(response) as List<dynamic>;
  }
}
