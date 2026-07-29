import 'package:http/http.dart' as http;
import 'base_api.dart';

class MarketPriceApi {
  static Future<List<dynamic>> fetchMarketPrices() async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/market-prices/'),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }
}
