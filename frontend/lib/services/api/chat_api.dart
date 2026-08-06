import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class ChatApi {
  static Future<List<dynamic>> fetchConversations(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/chat/conversations'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<List<dynamic>> fetchChatHistory(String token, String otherUserId) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/chat/$otherUserId'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> sendChatMessage(String token, String receiverId, String text) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/chat/'),
      headers: BaseApi.getHeaders(token),
      body: jsonEncode({
        'receiver_id': receiverId,
        'message_text': text,
      }),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
