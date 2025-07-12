import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AppLog {
  final DateTime timestamp;
  final String level; // 'info', 'warning', 'error', 'success'
  final String message;
  final String? details;

  AppLog({
    required this.timestamp,
    required this.level,
    required this.message,
    this.details,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level,
    'message': message,
    'details': details,
  };

  // Convert from JSON
  factory AppLog.fromJson(Map<String, dynamic> json) {
    return AppLog(
      level: json['level'],
      message: json['message'],
      details: json['details'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class LoggingService {
  static const String _logsKey = 'app_logs';
  static const int _maxLogs = 500; // Maximum number of logs to keep

  // Add a log entry
  static Future<void> addLog(
    String level,
    String message, [
    String? details,
  ]) async {
    final log = AppLog(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      details: details,
    );

    final logs = await getLogs();
    logs.insert(0, log); // Add new log at the beginning

    // Keep only the latest logs
    if (logs.length > _maxLogs) {
      logs.removeRange(_maxLogs, logs.length);
    }

    await _saveLogs(logs);
  }

  // Convenience methods for different log levels
  static Future<void> info(String message, [String? details]) async {
    await addLog('info', message, details);
  }

  static Future<void> warning(String message, [String? details]) async {
    await addLog('warning', message, details);
  }

  static Future<void> error(String message, [String? details]) async {
    await addLog('error', message, details);
  }

  static Future<void> success(String message, [String? details]) async {
    await addLog('success', message, details);
  }

  // Get all logs
  static Future<List<AppLog>> getLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getStringList(_logsKey) ?? [];

      return logsJson.map((logString) {
        final Map<String, dynamic> logMap = jsonDecode(logString);
        return AppLog.fromJson(logMap);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Retrieve all logs
  static Future<List<AppLog>> getAllLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getStringList('app_logs') ?? [];

    return logsJson.map((logJson) {
      final Map<String, dynamic> logMap = json.decode(logJson);
      return AppLog.fromJson(logMap);
    }).toList();
  }

  // Get logs by level
  static Future<List<AppLog>> getLogsByLevel(String level) async {
    final logs = await getLogs();
    return logs.where((log) => log.level == level).toList();
  }

  // Get logs from a specific time period
  static Future<List<AppLog>> getLogsFromDate(DateTime fromDate) async {
    final logs = await getLogs();
    return logs.where((log) => log.timestamp.isAfter(fromDate)).toList();
  }

  // Clear all logs
  static Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logsKey);
  }

  // Save logs to storage
  static Future<void> _saveLogs(List<AppLog> logs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = logs.map((log) => jsonEncode(log.toJson())).toList();
      await prefs.setStringList(_logsKey, logsJson);
    } catch (e) {
      // If we can't save logs, just continue silently
    }
  }

  // Get log count by level
  static Future<Map<String, int>> getLogCounts() async {
    final logs = await getLogs();
    final Map<String, int> counts = {
      'info': 0,
      'warning': 0,
      'error': 0,
      'success': 0,
    };

    for (final log in logs) {
      counts[log.level] = (counts[log.level] ?? 0) + 1;
    }

    return counts;
  }

  // Export logs as text (for sharing or debugging)
  static Future<String> exportLogsAsText() async {
    final logs = await getLogs();
    final buffer = StringBuffer();

    buffer.writeln('SMS to API - Application Logs');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total logs: ${logs.length}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final log in logs) {
      buffer.writeln('[${log.level.toUpperCase()}] ${log.timestamp.toLocal()}');
      buffer.writeln('Message: ${log.message}');
      if (log.details != null && log.details!.isNotEmpty) {
        buffer.writeln('Details: ${log.details}');
      }
      buffer.writeln('-' * 30);
    }

    return buffer.toString();
  }

  // Export logs as formatted text
  static Future<String> exportLogs() async {
    final logs = await getAllLogs();

    if (logs.isEmpty) {
      return 'No logs available for export.';
    }

    final buffer = StringBuffer();
    buffer.writeln('SMS to API - Application Logs');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total logs: ${logs.length}');
    buffer.writeln('${'=' * 50}');
    buffer.writeln();

    for (final log in logs) {
      buffer.writeln(
        '[${log.timestamp.toIso8601String()}] ${log.level}: ${log.message}',
      );
      if (log.details != null && log.details!.isNotEmpty) {
        buffer.writeln('  Details: ${log.details}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
