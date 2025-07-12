import 'dart:async';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';
import 'contact_filter_service.dart';
import 'logging_service.dart';

class SmsService {
  static final SmsQuery _query = SmsQuery();
  static final ApiService _apiService = ApiService();
  static Timer? _pollingTimer;
  static DateTime? _lastCheckedTime;
  static Set<String> _processedSmsIds = {};

  // Request SMS permissions
  static Future<bool> requestPermissions() async {
    final smsPermission = await Permission.sms.request();
    return smsPermission.isGranted;
  }

  // Check if permissions are granted
  static Future<bool> hasPermissions() async {
    return await Permission.sms.isGranted;
  }

  // Initialize SMS listener with polling approach
  static Future<void> initializeSmsListener() async {
    if (!await hasPermissions()) {
      await LoggingService.error(
        'Cannot initialize SMS listener',
        'SMS permissions not granted',
      );
      return;
    }

    await LoggingService.info(
      'Initializing SMS listener',
      'Using polling method',
    );

    // Initialize last checked time to now
    _lastCheckedTime = DateTime.now();

    // Start polling for new SMS every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkForNewSms();
    });

    await LoggingService.info(
      'SMS listener initialized',
      'Polling interval: 5 seconds',
    );
  }

  // Stop SMS listener
  static void stopSmsListener() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    LoggingService.info('SMS listener stopped', 'Polling stopped');
  }

  // Check for new SMS messages
  static Future<void> _checkForNewSms() async {
    try {
      if (!await hasPermissions()) return;

      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 10, // Check last 10 messages
      );

      final newMessages = messages.where((message) {
        // Check if message is newer than last check and not already processed
        final messageTime = message.date ?? DateTime.now();
        final isNew =
            _lastCheckedTime != null && messageTime.isAfter(_lastCheckedTime!);
        final notProcessed = !_processedSmsIds.contains(message.id.toString());
        return isNew && notProcessed;
      }).toList();

      for (final message in newMessages) {
        await onSmsReceived(message);
        _processedSmsIds.add(message.id.toString());
      }

      _lastCheckedTime = DateTime.now();
    } catch (e) {
      await LoggingService.error(
        'Error checking for new SMS: $e',
        'SMS polling failed',
      );
    }
  }

  // Handle incoming SMS
  static Future<void> onSmsReceived(SmsMessage message) async {
    final sender = message.address ?? 'Unknown';
    final messageBody = message.body ?? '';

    await LoggingService.info(
      'New SMS received from $sender',
      'Message: $messageBody',
    );

    try {
      // Check if this contact should be forwarded
      final shouldForward = await ContactFilterService.shouldForwardMessage(
        sender,
      );

      if (!shouldForward) {
        await LoggingService.info(
          'SMS filtered out - not forwarding',
          'Sender: $sender',
        );
        return;
      }

      // Forward SMS to API
      final timestamp = message.date ?? DateTime.now();

      final success = await _apiService.forwardSms(
        sender: sender,
        message: messageBody,
        timestamp: timestamp,
      );

      if (success) {
        await LoggingService.success(
          'SMS forwarded successfully',
          'To API from: $sender',
        );
      } else {
        await LoggingService.error('Failed to forward SMS', 'Sender: $sender');
      }
    } catch (e) {
      await LoggingService.error('Error processing SMS: $e', 'Sender: $sender');
    }
  }

  // Get SMS history (for testing/display purposes)
  static Future<List<SmsMessage>> getSmsHistory({int limit = 50}) async {
    if (!await hasPermissions()) {
      return [];
    }

    try {
      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: limit,
      );

      return messages;
    } catch (e) {
      print('Error getting SMS history: $e');
      return [];
    }
  }
}
