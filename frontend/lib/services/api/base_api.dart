import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_api.dart';

class BaseApi {
  static String get baseUrl => AuthApi.baseUrl;
  static String get version => "v1";

  /// Helper to generate auth headers
  static Map<String, String> getHeaders(String? token, {bool json = true}) {
    final Map<String, String> h = {};
    if (json) {
      h['Content-Type'] = 'application/json';
    }
    if (token != null) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  /// Global HTTP response handler
  static dynamic handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      try {
        final err = jsonDecode(response.body);
        final String errMsg = err['message']?.toString() ?? err['detail']?.toString() ?? 'API Error with status code: ${response.statusCode}';
        throw Exception(errMsg);
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('API Server error: ${response.statusCode}');
      }
    }
  }
}
