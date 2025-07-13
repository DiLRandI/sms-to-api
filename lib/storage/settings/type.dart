class Settings {
  final String url;
  final String apiKey;
  final List<String> phoneNumbers;

  Settings({
    required this.url,
    required this.apiKey,
    this.phoneNumbers = const [],
  });

  Map<String, dynamic> toJson() {
    return {'url': url, 'apiKey': apiKey, 'phoneNumbers': phoneNumbers};
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      url: json['url'] ?? '',
      apiKey: json['apiKey'] ?? '',
      phoneNumbers:
          (json['phoneNumbers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
