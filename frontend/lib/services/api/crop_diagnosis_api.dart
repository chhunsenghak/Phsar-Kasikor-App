import 'package:http/http.dart' as http;
import 'base_api.dart';

class CropDiagnosisApi {
  /// The Crop Advisor's "common issues" reference list — public, no auth,
  /// mirrors MarketPriceApi.fetchMarketPrices.
  static Future<List<dynamic>> fetchAll() async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/crop-diagnosis/'),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  /// Scores [symptoms] against every reference entry's keywords and
  /// returns `{matched, best_match, possible_matches}` — a real computed
  /// result, never a fabricated one.
  static Future<Map<String, dynamic>> match(String symptoms) async {
    final uri = Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/crop-diagnosis/match')
        .replace(queryParameters: {'symptoms': symptoms});
    final response = await http.get(uri);
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
