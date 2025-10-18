import 'api_endpoint.dart';

class Settings {
  // Deprecated single-endpoint fields (kept for backward compatibility/migration)
  final String url;
  final String apiKey;
  // New multi-endpoint support
  final List<ApiEndpoint> endpoints;
  // Shared header name applied to all endpoints
  final String authHeaderName;
  final List<String> phoneNumbers;

  Settings({
    this.url = '',
    this.apiKey = '',
    this.endpoints = const [],
    this.authHeaderName = 'Authorization',
    this.phoneNumbers = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      // Keep legacy fields to not break older native readers
      'url': url,
      'apiKey': apiKey,
      // New endpoints array
      'endpoints': endpoints.map((e) => e.toJson()).toList(),
      'authHeaderName': authHeaderName,
      'phoneNumbers': phoneNumbers,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    final legacyUrl = json['url']?.toString() ?? '';
    final legacyKey = json['apiKey']?.toString() ?? '';

    // If 'endpoints' present, parse it; otherwise, migrate legacy url/apiKey into a single endpoint
    final parsedEndpoints =
        (json['endpoints'] as List?)
            ?.map(
              (e) => ApiEndpoint.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList() ??
        [];

    final endpoints = parsedEndpoints.isNotEmpty
        ? parsedEndpoints
        : (legacyUrl.isNotEmpty || legacyKey.isNotEmpty)
        ? [
            ApiEndpoint(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: 'Default',
              url: legacyUrl,
              apiKey: legacyKey,
              active: true,
            ),
          ]
        : <ApiEndpoint>[];

    return Settings(
      url: legacyUrl,
      apiKey: legacyKey,
      endpoints: endpoints,
      authHeaderName: json['authHeaderName']?.toString() ?? 'Authorization',
      phoneNumbers:
          (json['phoneNumbers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
