import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/contact_filter_service.dart';
import '../services/logging_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final List<String> _debugResults = [];

  void _addResult(String result) {
    setState(() {
      _debugResults.add('${DateTime.now().toIso8601String()}: $result');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Debug'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _checkPermissions,
                  child: const Text('1. Check Permissions'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _readRecentSms,
                  child: const Text('2. Read Recent SMS'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _testApiConnection,
                  child: const Text('3. Test API Connection'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _testAndroidService,
                  child: const Text('4. Test Android Service'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _clearResults,
                  child: const Text('Clear Results'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _checkLogData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text('5. Check Log Data Format'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _simulateCrashScenario,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('6. Simulate SMS Processing'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _debugResults.length,
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  title: Text(
                    _debugResults[index],
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPermissions() async {
    _addResult('=== CHECKING PERMISSIONS ===');

    try {
      final smsPermission = await Permission.sms.status;
      _addResult('SMS Permission: $smsPermission');

      if (!smsPermission.isGranted) {
        _addResult('Requesting SMS permission...');
        final result = await Permission.sms.request();
        _addResult('SMS Permission after request: $result');
      }

      final notificationPermission = await Permission.notification.status;
      _addResult('Notification Permission: $notificationPermission');

      final batteryOptimization =
          await Permission.ignoreBatteryOptimizations.status;
      _addResult('Battery Optimization: $batteryOptimization');
    } catch (e) {
      _addResult('Error checking permissions: $e');
    }
  }

  Future<void> _readRecentSms() async {
    _addResult('=== READING RECENT SMS ===');

    try {
      final SmsQuery query = SmsQuery();
      final messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 5, // Get last 5 messages
      );

      _addResult('Found ${messages.length} SMS messages');

      for (int i = 0; i < messages.length; i++) {
        final message = messages[i];
        _addResult('SMS $i:');
        _addResult('  From: ${message.address ?? "Unknown"}');
        _addResult(
          '  Body: ${(message.body ?? "").substring(0, (message.body?.length ?? 0) > 50 ? 50 : (message.body?.length ?? 0))}...',
        );
        _addResult('  Date: ${message.date?.toIso8601String() ?? "Unknown"}');
        _addResult('  ID: ${message.id ?? "Unknown"}');

        // Check if this message would pass filtering
        final shouldForward = await ContactFilterService.shouldForwardMessage(
          message.address ?? '',
        );
        _addResult('  Would forward: $shouldForward');
      }
    } catch (e) {
      _addResult('Error reading SMS: $e');
    }
  }

  Future<void> _testApiConnection() async {
    _addResult('=== TESTING API CONNECTION ===');

    try {
      final apiService = ApiService();
      final config = await apiService.getApiConfig();

      _addResult('API URL: ${config['url']}');
      _addResult(
        'API Key: ${config['key']?.isNotEmpty == true ? 'Set' : 'Not set'}',
      );

      if (config['url']?.isNotEmpty == true) {
        _addResult('Testing API connection...');
        final success = await apiService.testApiConnection();
        _addResult('API connection test: ${success ? 'SUCCESS' : 'FAILED'}');

        // Try sending a test SMS
        _addResult('Sending test SMS to API...');
        final testSuccess = await apiService.forwardSms(
          sender: 'DEBUG_TEST',
          message: 'Test message from debug screen',
          timestamp: DateTime.now(),
        );
        _addResult('Test SMS forward: ${testSuccess ? 'SUCCESS' : 'FAILED'}');
      } else {
        _addResult('API URL not configured');
      }
    } catch (e) {
      _addResult('Error testing API: $e');
    }
  }

  Future<void> _testAndroidService() async {
    _addResult('=== TESTING ANDROID SERVICE ===');

    try {
      const platform = MethodChannel('sms_forwarding_service');

      _addResult('Checking service status...');
      final isRunning = await platform.invokeMethod('isServiceRunning');
      _addResult('Android service running: $isRunning');

      if (!isRunning) {
        _addResult('Starting Android service...');
        await platform.invokeMethod('startService');

        // Wait a bit and check again
        await Future.delayed(const Duration(seconds: 2));
        final isRunningAfter = await platform.invokeMethod('isServiceRunning');
        _addResult('Android service running after start: $isRunningAfter');
      }

      _addResult('Triggering test SMS processing...');
      await platform.invokeMethod('testSmsProcessing');
      _addResult('Test SMS processing triggered');
    } catch (e) {
      _addResult('Error testing Android service: $e');
    }
  }

  void _clearResults() {
    setState(() {
      _debugResults.clear();
    });
  }

  Future<void> _checkLogData() async {
    _addResult('=== CHECKING LOG DATA FORMAT ===');

    try {
      // Check SharedPreferences directly
      final prefs = await SharedPreferences.getInstance();

      // Check Dart format logs
      final dartLogs = prefs.getStringList('app_logs');
      _addResult(
        'Dart format logs (StringList): ${dartLogs != null ? dartLogs.length : 'null'}',
      );

      // Check Android format logs
      final androidLogs = prefs.getString('flutter.app_logs');
      _addResult(
        'Android format logs (String): ${androidLogs != null ? 'exists (${androidLogs.length} chars)' : 'null'}',
      );

      if (androidLogs != null &&
          androidLogs.isNotEmpty &&
          androidLogs != '[]') {
        try {
          final parsed = jsonDecode(androidLogs);
          if (parsed is List) {
            _addResult(
              'Android logs parsed successfully: ${parsed.length} entries',
            );
          } else {
            _addResult('Android logs format unexpected: ${parsed.runtimeType}');
          }
        } catch (e) {
          _addResult('Android logs parse error: $e');
        }
      }

      // Test log service
      _addResult('Testing LoggingService...');
      final logs = await LoggingService.getAllLogs();
      _addResult('LoggingService returned ${logs.length} logs');

      // Add a test log
      await LoggingService.info(
        'Debug test log',
        'Testing log system from debug screen',
      );
      _addResult('Test log added successfully');
    } catch (e) {
      _addResult('Error checking log data: $e');
    }
  }

  Future<void> _simulateCrashScenario() async {
    _addResult('=== SIMULATING SMS PROCESSING SCENARIO ===');

    try {
      _addResult('Step 1: Testing direct Dart SMS reading...');

      // Try to read SMS directly like the persistent service does
      final SmsQuery query = SmsQuery();
      final messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 1,
      );

      if (messages.isNotEmpty) {
        final message = messages.first;
        _addResult('Found latest SMS from: ${message.address}');

        _addResult('Step 2: Testing contact filtering...');
        final shouldForward = await ContactFilterService.shouldForwardMessage(
          message.address ?? '',
        );
        _addResult('Contact filter result: $shouldForward');

        if (shouldForward) {
          _addResult('Step 3: Testing API forwarding...');
          final apiService = ApiService();
          final success = await apiService.forwardSms(
            sender: message.address ?? 'Unknown',
            message: 'DEBUG: ${message.body ?? 'No body'}',
            timestamp: DateTime.now(),
          );
          _addResult('API forward result: $success');
        }

        _addResult('Step 4: Testing Android service integration...');
        const platform = MethodChannel('sms_forwarding_service');
        await platform.invokeMethod('testSmsProcessing');
        _addResult('Android service test completed');
      } else {
        _addResult('No SMS messages found to test with');
      }

      _addResult('=== SIMULATION COMPLETED ===');
    } catch (e) {
      _addResult('ERROR in simulation: $e');
      _addResult('Stack trace: ${e.toString()}');
    }
  }
}
