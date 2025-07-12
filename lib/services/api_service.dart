import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _apiUrlKey = 'api_url';
  static const String _apiKeyKey = 'api_key';

  // Get stored API configuration
  Future<Map<String, String?>> getApiConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'url': prefs.getString(_apiUrlKey),
      'key': prefs.getString(_apiKeyKey),
    };
  }

  // Save API configuration
  Future<void> saveApiConfig(String url, String? apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
    if (apiKey != null && apiKey.isNotEmpty) {
      await prefs.setString(_apiKeyKey, apiKey);
    }
  }

  // Forward SMS to API
  Future<bool> forwardSms({
    required String sender,
    required String message,
    required DateTime timestamp,
  }) async {
    try {
      final config = await getApiConfig();
      final apiUrl = config['url'];
      
      if (apiUrl == null || apiUrl.isEmpty) {
        print('API URL not configured');
        return false;
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      // Add API key if configured
      final apiKey = config['key'];
      if (apiKey != null && apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final body = jsonEncode({
        'sender': sender,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'device_info': {
          'platform': 'android',
          'app': 'sms_to_api',
        }
      });

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: body,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('SMS forwarded successfully: ${response.statusCode}');
        return true;
      } else {
        print('Failed to forward SMS: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error forwarding SMS: $e');
      return false;
    }
  }

  // Test API connection
  Future<bool> testApiConnection() async {
    try {
      final config = await getApiConfig();
      final apiUrl = config['url'];
      
      if (apiUrl == null || apiUrl.isEmpty) {
        return false;
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      final apiKey = config['key'];
      if (apiKey != null && apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      // Send a test message
      final body = jsonEncode({
        'test': true,
        'message': 'API connection test from SMS to API app',
        'timestamp': DateTime.now().toIso8601String(),
      });

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: body,
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('Error testing API connection: $e');
      return false;
    }
  }
}
