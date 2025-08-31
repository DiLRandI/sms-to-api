import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/logs/log_entry.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  // Read logs directly from Android storage. Use logical key without the
  // 'flutter.' prefix — the shared_preferences plugin handles prefixing.
  static const String _androidLogsKey = 'app_logs';
  static const int _maxLogs = 300;

  Future<List<LogEntry>> getAllLogs() async {
    final prefs = await SharedPreferences.getInstance();
    // Force a refresh from disk so logs written by Android are visible immediately
    try {
      await prefs.reload();
    } catch (_) {
      // Ignore if reload is unavailable on older plugin versions
    }
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
          stackTrace: logData['stackTrace'],
        );
      }).toList();
    } catch (e) {
      // If parsing fails, return empty list
      return [];
    }
  }

  Future<void> logInfo(String tag, String message) async {
    await _appendLog(level: 'INFO', tag: tag, message: message);
  }

  Future<void> logWarning(String tag, String message) async {
    await _appendLog(level: 'WARNING', tag: tag, message: message);
  }

  Future<void> logError(
    String tag,
    String message, {
    String? stackTrace,
  }) async {
    await _appendLog(
      level: 'ERROR',
      tag: tag,
      message: message,
      stackTrace: stackTrace,
    );
  }

  Future<void> _appendLog({
    required String level,
    required String tag,
    required String message,
    String? stackTrace,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // Try to read existing array string written by Android side
    List<dynamic> logsList;
    try {
      final existing = prefs.getString(_androidLogsKey) ?? '[]';
      logsList = jsonDecode(existing);
    } catch (_) {
      logsList = [];
    }

    final entry = {
      'id': _generateId(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'tag': tag,
      'message': message,
      if (stackTrace != null) 'stackTrace': stackTrace,
    };
    logsList.add(entry);

    // Bound to last N items
    if (logsList.length > _maxLogs) {
      logsList = logsList.sublist(logsList.length - _maxLogs);
    }

    await prefs.setString(_androidLogsKey, jsonEncode(logsList));
  }

  String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final t = DateTime.now().microsecondsSinceEpoch;
    return List.generate(8, (i) => chars[(t + i) % chars.length]).join();
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
