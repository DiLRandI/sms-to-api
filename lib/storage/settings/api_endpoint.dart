class ApiEndpoint {
  final String id;
  final String name;
  final String url;
  final String apiKey;
  // Header name specific to this endpoint (profile)
  final String authHeaderName;
  final bool active;

  const ApiEndpoint({
    required this.id,
    required this.name,
    required this.url,
    required this.apiKey,
    this.authHeaderName = 'Authorization',
    this.active = true,
  });

  ApiEndpoint copyWith({
    String? id,
    String? name,
    String? url,
    String? apiKey,
    String? authHeaderName,
    bool? active,
  }) {
    return ApiEndpoint(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      apiKey: apiKey ?? this.apiKey,
      authHeaderName: authHeaderName ?? this.authHeaderName,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'apiKey': apiKey,
    'authHeaderName': authHeaderName,
    'active': active,
  };

  factory ApiEndpoint.fromJson(Map<String, dynamic> json) {
    return ApiEndpoint(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'Endpoint',
      url: json['url']?.toString() ?? '',
      apiKey: json['apiKey']?.toString() ?? '',
      authHeaderName: json['authHeaderName']?.toString() ?? 'Authorization',
      active: json['active'] is bool
          ? (json['active'] as bool)
          : json['active']?.toString().toLowerCase() == 'true',
    );
  }
}
