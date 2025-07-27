import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/logs/log_entry.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  // Read logs directly from Android storage (same key used by LogManager.kt)
  static const String _androidLogsKey = 'flutter.app_logs';

  Future<List<LogEntry>> getAllLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getString(_androidLogsKey) ?? '[]';

    try {
      final List<dynamic> logsList = jsonDecode(logsJson);
      return logsList.map((logData) {
        return LogEntry(
          id: logData['id'] ?? '',
          timestamp: DateTime.parse(
            logData['timestamp'] ?? DateTime.now().toIso8601String(),
          ),
          level: logData['level'] ?? 'INFO',
          tag: logData['tag'] ?? 'Unknown',
          message: logData['message'] ?? '',
        );
      }).toList();
    } catch (e) {
      // If parsing fails, return empty list
      return [];
    }
  }

  Future<List<LogEntry>> getLogsByLevel(String level) async {
    final allLogs = await getAllLogs();
    return allLogs.where((log) => log.level == level).toList();
  }

  Future<List<LogEntry>> getLogsByTag(String tag) async {
    final allLogs = await getAllLogs();
    return allLogs.where((log) => log.tag == tag).toList();
  }

  Future<List<LogEntry>> getLogsInTimeRange(
    DateTime start,
    DateTime end,
  ) async {
    final allLogs = await getAllLogs();
    return allLogs.where((log) {
      return log.timestamp.isAfter(start) && log.timestamp.isBefore(end);
    }).toList();
  }

  Future<bool> clearAllLogs() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(_androidLogsKey);
  }

  // Debug method to check if there are Android-generated logs
  Future<Map<String, dynamic>> getLogStatistics() async {
    final allLogs = await getAllLogs();
    final androidLogs = allLogs
        .where(
          (log) =>
              log.tag.contains('SmsForwardingService') ||
              log.tag.contains('LogManager'),
        )
        .toList();
    final flutterLogs = allLogs
        .where((log) => log.tag == 'LogService')
        .toList();

    return {
      'total': allLogs.length,
      'android_logs': androidLogs.length,
      'flutter_logs': flutterLogs.length,
      'log_sources': allLogs.map((log) => log.tag).toSet().toList(),
    };
  }
}
