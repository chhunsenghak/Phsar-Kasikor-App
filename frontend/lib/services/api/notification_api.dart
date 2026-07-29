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
}
