class Settings {
  final String url;
  final String apiKey;

  Settings({required this.url, required this.apiKey});

  Map<String, dynamic> toJson() {
    return {'url': url, 'apiKey': apiKey};
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(url: json['url'] ?? '', apiKey: json['apiKey'] ?? '');
  }
}
