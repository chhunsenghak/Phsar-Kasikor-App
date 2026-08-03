import 'package:http/http.dart' as http;
import 'base_api.dart';

class CooperativeApi {
  static Future<List<dynamic>> fetchMembers(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/cooperatives/members'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }
}
