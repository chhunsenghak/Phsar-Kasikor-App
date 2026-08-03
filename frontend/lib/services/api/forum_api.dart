import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class ForumApi {
  static Future<List<dynamic>> fetchPosts(String token, {String? category}) async {
    String url = '${BaseApi.baseUrl}/api/${BaseApi.version}/forum/posts';
    if (category != null && category != 'All') {
      url += '?category=${Uri.encodeComponent(category)}';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createPost(
    String token, {
    required String title,
    required String content,
    String category = 'General',
  }) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/forum/posts'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({
        'title': title,
        'content': content,
        'category': category,
      }),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchPostDetail(String token, String postId) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/forum/posts/$postId'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> addComment(String token, String postId, String content) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/forum/posts/$postId/comments'),
      headers: BaseApi.getHeaders(token, json: true),
      body: jsonEncode({'content': content}),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> likePost(String token, String postId) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/forum/posts/$postId/like'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
