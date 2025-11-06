import 'api_endpoint.dart';

class Settings {
  final List<ApiEndpoint> endpoints;
  final String authHeaderName;
  final List<String> phoneNumbers;

  const Settings({
    this.endpoints = const [],
    this.authHeaderName = 'Authorization',
    this.phoneNumbers = const [],
  });

  Settings copyWith({
    List<ApiEndpoint>? endpoints,
    String? authHeaderName,
    List<String>? phoneNumbers,
  }) {
    return Settings(
      endpoints: endpoints ?? this.endpoints,
      authHeaderName: authHeaderName ?? this.authHeaderName,
      phoneNumbers: phoneNumbers ?? this.phoneNumbers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'endpoints': endpoints.map((e) => e.toJson()).toList(),
      'authHeaderName': authHeaderName,
      'phoneNumbers': phoneNumbers,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    final parsedEndpoints =
        (json['endpoints'] as List?)
            ?.map(
              (e) => ApiEndpoint.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList() ??
        <ApiEndpoint>[];

    return Settings(
      endpoints: parsedEndpoints,
      authHeaderName: json['authHeaderName']?.toString() ?? 'Authorization',
      phoneNumbers:
          (json['phoneNumbers'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
    );
  }
}
