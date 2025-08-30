import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:sms_to_api/storage/settings/storage.dart';

class SMSMessage {
  final String message;
  final String phoneNumber;
  final DateTime timeReceived;

  SMSMessage({
    required this.message,
    required this.phoneNumber,
    required this.timeReceived,
  });

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'phoneNumber': phoneNumber,
      'timeReceived': timeReceived.toIso8601String(),
    };
  }
}

class ApiService {
  final Storage _storage;

  ApiService() : _storage = Storage();

  Future<bool> validateApi() async {
    var settings = await _storage.load();
    if (settings == null) {
      return false;
    }

    if (settings.url.isEmpty || settings.apiKey.isEmpty) {
      return false;
    }

    // Basic URL validation: must be a valid http/https URL
    final uri = Uri.tryParse(settings.url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return false;
    }

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              settings.authHeaderName: settings.apiKey,
            },
            body: jsonEncode({'test': true}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return false;
      }
    } catch (e) {
      // Avoid printing secrets; provide concise diagnostic info.
      // ignore: avoid_print
      debugPrint('Error validating API endpoint: $e');
      return false;
    }

    return true;
  }
}
