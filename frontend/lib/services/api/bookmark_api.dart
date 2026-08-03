import 'package:http/http.dart' as http;
import 'base_api.dart';

class BookmarkApi {
  static Future<List<dynamic>> fetchBookmarks(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/bookmarks/'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> addBookmark(String token, String productId) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/bookmarks/$productId'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<void> removeBookmark(String token, String productId) async {
    final response = await http.delete(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/bookmarks/$productId'),
      headers: BaseApi.getHeaders(token),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      BaseApi.handleResponse(response);
    }
  }
}
