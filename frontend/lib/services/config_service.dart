import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ConfigService {
  static Map<String, dynamic> _config = {};

  /// Load and parse config.json from assets
  static Future<void> initialize() async {
    try {
      final String jsonString = await rootBundle.loadString('config.json');
      _config = jsonDecode(jsonString);
    } catch (e) {
      debugPrint('Failed to load config.json: $e');
    }
  }

  /// Get value by key with optional fallback
  static String get(String key, {String defaultValue = ''}) {
    return _config[key]?.toString() ?? defaultValue;
  }
}
