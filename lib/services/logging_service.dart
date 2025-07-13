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

      // First try to get as StringList (Dart format)
      final logsStringList = prefs.getStringList(_logsKey);
      if (logsStringList != null) {
        return logsStringList.map((logString) {
          final Map<String, dynamic> logMap = jsonDecode(logString);
          return AppLog.fromJson(logMap);
        }).toList();
      }

      // If that fails, try to get as String (Android format)
      final logsString =
          prefs.getString('flutter.app_logs') ?? prefs.getString(_logsKey);
      if (logsString != null && logsString.isNotEmpty && logsString != '[]') {
        final List<dynamic> logsJsonArray = jsonDecode(logsString);
        return logsJsonArray.map((logJson) {
          // Handle both Map<String, dynamic> and String formats
          final Map<String, dynamic> logMap = logJson is String
              ? jsonDecode(logJson)
              : logJson as Map<String, dynamic>;
          return AppLog.fromJson(logMap);
        }).toList();
      }

      return [];
    } catch (e) {
      // If parsing fails, clear the corrupted data and return empty list
      await _clearCorruptedLogs();
      return [];
    }
  }

  // Retrieve all logs (alias for getLogs for backward compatibility)
  static Future<List<AppLog>> getAllLogs() async {
    return getLogs();
  }

  // Clear corrupted log data
  static Future<void> _clearCorruptedLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logsKey);
      await prefs.remove('flutter.app_logs');
    } catch (e) {
      // Ignore errors when clearing
    }
  }

  // Migrate and fix log data format
  static Future<void> migrateLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we have Android format logs that need migration
      final androidLogs = prefs.getString('flutter.app_logs');
      final dartLogs = prefs.getStringList(_logsKey);

      if (androidLogs != null &&
          androidLogs.isNotEmpty &&
          androidLogs != '[]' &&
          dartLogs == null) {
        // We have Android logs but no Dart logs, migrate them
        final List<dynamic> logsJsonArray = jsonDecode(androidLogs);
        final logs = logsJsonArray.map((logJson) {
          final Map<String, dynamic> logMap = logJson is String
              ? jsonDecode(logJson)
              : logJson as Map<String, dynamic>;
          return AppLog.fromJson(logMap);
        }).toList();

        // Save in both formats
        await _saveLogs(logs);
      }
    } catch (e) {
      // If migration fails, clear everything and start fresh
      await _clearCorruptedLogs();
    }
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
    await prefs.remove('flutter.app_logs'); // Also clear Android format logs
  }

  // Save logs to storage
  static Future<void> _saveLogs(List<AppLog> logs) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save in Dart format (StringList)
      final logsJson = logs.map((log) => jsonEncode(log.toJson())).toList();
      await prefs.setStringList(_logsKey, logsJson);

      // Also save in Android format for compatibility
      final androidLogsArray = logs.map((log) => log.toJson()).toList();
      await prefs.setString('flutter.app_logs', jsonEncode(androidLogsArray));
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
