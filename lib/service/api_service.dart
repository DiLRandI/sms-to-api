import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:sms_to_api/storage/settings/storage.dart';
import 'package:sms_to_api/storage/settings/api_endpoint.dart';

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
    final settings = await _storage.load();
    if (settings == null) return false;

    final activeEndpoints = settings.endpoints.where((e) => e.active).toList();
    if (activeEndpoints.isEmpty) return false;

    // Consider configuration reachable if at least one active endpoint responds with 200
    for (final endpoint in activeEndpoints) {
      final ok = await validateEndpoint(
        endpoint,
        fallbackHeaderName: settings.authHeaderName,
      );
      if (ok) return true;
    }
    return false;
  }

  Future<bool> validateEndpoint(
    ApiEndpoint endpoint, {
    String? fallbackHeaderName,
  }) async {
    final uri = Uri.tryParse(endpoint.url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return false;
    }
    final headerName = (endpoint.authHeaderName.isNotEmpty
            ? endpoint.authHeaderName
            : null) ??
        (fallbackHeaderName?.isNotEmpty == true
            ? fallbackHeaderName!
            : 'Authorization');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              headerName: endpoint.apiKey,
            },
            body: jsonEncode({'test': true, 'endpoint': endpoint.name}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error validating ${endpoint.name}: $e');
      return false;
    }
  }
}
