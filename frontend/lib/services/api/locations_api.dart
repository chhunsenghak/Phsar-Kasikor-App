import 'package:http/http.dart' as http;
import 'base_api.dart';

class LocationsApi {
  static Future<Map<String, dynamic>> fetchLocations() async {
    final response = await http.get(Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/locations/'));
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
