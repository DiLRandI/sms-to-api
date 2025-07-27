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
}
