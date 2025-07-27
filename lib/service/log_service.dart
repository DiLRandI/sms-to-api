import 'dart:math';
import 'package:flutter/services.dart';
import '../storage/logs/log_entry.dart';
import '../storage/logs/log_storage.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final LogStorage _storage = LogStorage();

  static const MethodChannel _channel = MethodChannel(
    'com.example.flutter_counter_service/logs',
  );

  Future<void> initializeLogListener() async {
    // Set up method channel to receive logs from Android
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewLog') {
        final Map<String, dynamic> logData = Map<String, dynamic>.from(
          call.arguments,
        );
        await _addLogFromNative(
          level: logData['level'] ?? 'INFO',
          tag: logData['tag'] ?? 'Unknown',
          message: logData['message'] ?? '',
        );
      }
    });
  }

  Future<void> _addLogFromNative({
    required String level,
    required String tag,
    required String message,
  }) async {
    final log = LogEntry(
      id: _generateId(),
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );

    await _storage.addLog(log);
  }

  Future<void> addLog({
    required String level,
    required String tag,
    required String message,
    String? stackTrace,
  }) async {
    final log = LogEntry(
      id: _generateId(),
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      stackTrace: stackTrace,
    );

    await _storage.addLog(log);
  }

  Future<void> logInfo(String tag, String message) async {
    await addLog(level: 'INFO', tag: tag, message: message);
  }

  Future<void> logDebug(String tag, String message) async {
    await addLog(level: 'DEBUG', tag: tag, message: message);
  }

  Future<void> logWarning(String tag, String message) async {
    await addLog(level: 'WARNING', tag: tag, message: message);
  }

  Future<void> logError(
    String tag,
    String message, [
    String? stackTrace,
  ]) async {
    await addLog(
      level: 'ERROR',
      tag: tag,
      message: message,
      stackTrace: stackTrace,
    );
  }

  Future<List<LogEntry>> getAllLogs() async {
    return await _storage.loadLogs();
  }

  Future<List<LogEntry>> getLogsByLevel(String level) async {
    return await _storage.getLogsByLevel(level);
  }

  Future<List<LogEntry>> getLogsByTag(String tag) async {
    return await _storage.getLogsByTag(tag);
  }

  Future<List<LogEntry>> getLogsInTimeRange(
    DateTime start,
    DateTime end,
  ) async {
    return await _storage.getLogsInTimeRange(start, end);
  }

  Future<bool> clearAllLogs() async {
    return await _storage.clearLogs();
  }

  String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        8,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
}
