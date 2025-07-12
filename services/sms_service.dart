import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';

class SmsService {
  static final Telephony telephony = Telephony.instance;
  static final ApiService _apiService = ApiService();

  // Request SMS permissions
  static Future<bool> requestPermissions() async {
    final smsPermission = await Permission.sms.request();
    return smsPermission.isGranted;
  }

  // Check if permissions are granted
  static Future<bool> hasPermissions() async {
    return await Permission.sms.isGranted;
  }

  // Initialize SMS listener
  static Future<void> initializeSmsListener() async {
    if (!await hasPermissions()) {
      print('SMS permissions not granted');
      return;
    }

    // Listen for incoming SMS
    telephony.listenIncomingSms(
      onNewMessage: onSmsReceived,
      listenInBackground: true,
    );

    print('SMS listener initialized');
  }

  // Handle incoming SMS
  static Future<void> onSmsReceived(SmsMessage message) async {
    print('New SMS received from ${message.address}: ${message.body}');

    try {
      // Forward SMS to API
      final timestamp = message.date != null
          ? DateTime.fromMillisecondsSinceEpoch(message.date as int)
          : DateTime.now();

      final success = await _apiService.forwardSms(
        sender: message.address ?? 'Unknown',
        message: message.body ?? '',
        timestamp: timestamp,
      );

      if (success) {
        print('SMS forwarded successfully');
      } else {
        print('Failed to forward SMS');
      }
    } catch (e) {
      print('Error processing SMS: $e');
    }
  }

  // Get SMS history (for testing/display purposes)
  static Future<List<SmsMessage>> getSmsHistory({int limit = 50}) async {
    if (!await hasPermissions()) {
      return [];
    }

    try {
      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      return messages.take(limit).toList();
    } catch (e) {
      print('Error getting SMS history: $e');
      return [];
    }
  }
}
