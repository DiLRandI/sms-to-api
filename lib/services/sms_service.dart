import 'package:sms_advanced/sms_advanced.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';

class SmsService {
  static final SmsReceiver _receiver = SmsReceiver();
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
    _receiver.onSmsReceived!.listen(onSmsReceived);
    print('SMS listener initialized');
  }

  // Handle incoming SMS
  static Future<void> onSmsReceived(SmsMessage message) async {
    print('New SMS received from ${message.sender}: ${message.body}');

    try {
      // Forward SMS to API
      final timestamp = message.date ?? DateTime.now();

      final success = await _apiService.forwardSms(
        sender: message.sender ?? 'Unknown',
        message: message.body ?? '',
        timestamp: timestamp,
      );

      if (success) {
        print('SMS forwarded successfully');
        // Note: In a real app, you'd want to use a proper state management
        // solution to update the counter across the app
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
      final SmsQuery query = SmsQuery();
      final messages = await query.getAllSms;

      // Sort by date and limit
      messages.sort(
        (a, b) =>
            (b.date ?? DateTime.now()).compareTo(a.date ?? DateTime.now()),
      );
      return messages.take(limit).toList();
    } catch (e) {
      print('Error getting SMS history: $e');
      return [];
    }
  }
}
