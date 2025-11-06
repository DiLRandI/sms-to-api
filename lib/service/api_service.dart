import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sms_to_api/storage/settings/api_endpoint.dart';
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
  ApiService({Storage? storage, http.Client? httpClient})
      : _storage = storage ?? Storage(),
        _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  final Storage _storage;
  final http.Client _httpClient;
  final bool _ownsClient;
  static const Duration _requestTimeout = Duration(seconds: 10);

  @visibleForTesting
  void dispose() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }

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
      final response = await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              headerName: endpoint.apiKey,
            },
            body: jsonEncode({'test': true, 'endpoint': endpoint.name}),
          )
          .timeout(_requestTimeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error validating ${endpoint.name}: ${_maskSecrets('$e')}');
      return false;
    }
  }

  String _maskSecrets(String value) {
    var sanitized = value;
    final patterns = <RegExp>[
      RegExp(r'(api[_-]?key\s*[:=]\s*)([^\s,]+)', caseSensitive: false),
      RegExp(r'(authorization\s*[:=]\s*)(Bearer\s+[^\s,]+)',
          caseSensitive: false),
    ];
    for (final pattern in patterns) {
      sanitized = sanitized.replaceAllMapped(pattern, (match) {
        final prefix = match.group(1) ?? '';
        return '$prefix***';
      });
    }
    return sanitized;
  }
}
