import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'log_entry.dart';

class LogStorage {
  static const String _logsKey = 'app_logs';
  static const int _maxLogEntries = 1000; // Keep only last 1000 entries

  Future<List<LogEntry>> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getStringList(_logsKey) ?? [];

    return logsJson
        .map((logJson) {
          try {
            final Map<String, dynamic> logMap = jsonDecode(logJson);
            return LogEntry.fromJson(logMap);
          } catch (e) {
            // If there's an error parsing a log entry, skip it
            return null;
          }
        })
        .where((log) => log != null)
        .cast<LogEntry>()
        .toList();
  }

  Future<bool> saveLogs(List<LogEntry> logs) async {
    final prefs = await SharedPreferences.getInstance();

    // Keep only the most recent entries
    final limitedLogs = logs.length > _maxLogEntries
        ? logs.sublist(logs.length - _maxLogEntries)
        : logs;

    final logsJson = limitedLogs
        .map((log) => jsonEncode(log.toJson()))
        .toList();
    return await prefs.setStringList(_logsKey, logsJson);
  }

  Future<bool> addLog(LogEntry log) async {
    final existingLogs = await loadLogs();
    existingLogs.add(log);
    return await saveLogs(existingLogs);
  }

  Future<bool> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(_logsKey);
  }

  Future<List<LogEntry>> getLogsByLevel(String level) async {
    final logs = await loadLogs();
    return logs.where((log) => log.level == level).toList();
  }

  Future<List<LogEntry>> getLogsByTag(String tag) async {
    final logs = await loadLogs();
    return logs.where((log) => log.tag == tag).toList();
  }

  Future<List<LogEntry>> getLogsInTimeRange(
    DateTime start,
    DateTime end,
  ) async {
    final logs = await loadLogs();
    return logs
        .where(
          (log) => log.timestamp.isAfter(start) && log.timestamp.isBefore(end),
        )
        .toList();
  }
}
