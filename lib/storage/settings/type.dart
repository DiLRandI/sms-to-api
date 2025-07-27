class Settings {
  final String url;
  final String apiKey;
  final String authHeaderName;
  final List<String> phoneNumbers;

  Settings({
    required this.url,
    required this.apiKey,
    this.authHeaderName = 'Authorization',
    this.phoneNumbers = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'apiKey': apiKey,
      'authHeaderName': authHeaderName,
      'phoneNumbers': phoneNumbers,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      url: json['url'] ?? '',
      apiKey: json['apiKey'] ?? '',
      authHeaderName: json['authHeaderName'] ?? 'Authorization',
      phoneNumbers:
          (json['phoneNumbers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
