import 'package:http/http.dart' as http;
import 'base_api.dart';

class AnalyticsApi {
  static Future<Map<String, dynamic>> fetchFarmerSalesAnalytics(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/analytics/farmer-sales'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
