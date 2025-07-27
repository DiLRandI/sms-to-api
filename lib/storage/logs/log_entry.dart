class LogEntry {
  final String id;
  final DateTime timestamp;
  final String level;
  final String tag;
  final String message;
  final String? stackTrace;

  LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'level': level,
      'tag': tag,
      'message': message,
      'stackTrace': stackTrace,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      level: json['level'],
      tag: json['tag'],
      message: json['message'],
      stackTrace: json['stackTrace'],
    );
  }

  @override
  String toString() {
    return '${timestamp.toIso8601String()} [$level] $tag: $message';
  }
}
