import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class NotificationApi {
  static Future<List<dynamic>> fetchNotifications(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/notifications/'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(String token, String notificationId) async {
    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/notifications/$notificationId/read'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createNotification(
    String token, {
    required String userId,
    required String title,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/notifications/'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({
        'user_id': userId,
        'title': title,
        'message': message,
        'is_read': false,
      }),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> deleteNotification(String token, String notificationId) async {
    final response = await http.delete(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/notifications/$notificationId'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
