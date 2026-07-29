import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class UploadApi {
  /// Uploads image bytes to the backend and returns the relative image url.
  static Future<String> uploadImage(String token, Uint8List bytes, String filename) async {
    final uri = Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/upload/');
    final request = http.MultipartRequest('POST', uri);
    
    // Multipart requests shouldn't set Content-Type to application/json, 
    // so we set json: false in getHeaders
    request.headers.addAll(BaseApi.getHeaders(token, json: false));
    
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
    ));
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    final decoded = BaseApi.handleResponse(response);
    return decoded['url'] as String;
  }
}
