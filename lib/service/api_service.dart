import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sms_to_api/storage/settings/storage.dart';
import 'package:sms_to_api/storage/settings/type.dart';

class SMSMessage {
  final String message;
  final String phoneNumber;
  final DateTime timeReceived;

  SMSMessage({
    required this.message,
    required this.phoneNumber,
    required this.timeReceived,
  });

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'phoneNumber': phoneNumber,
      'timeReceived': timeReceived.toIso8601String(),
    };
  }
}

class ApiService {
  final Storage _storage;

  ApiService() : _storage = Storage();

  Future<bool> validateApi() async {
    var settings = await _storage.load();
    if (settings == null) {
      return false;
    }

    if (settings.url.isEmpty || settings.apiKey.isEmpty) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(settings.url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${settings.apiKey}',
        },
        body: jsonEncode({'test': true}),
      );

      if (response.statusCode != 200) {
        return false;
      }
    } catch (e) {
      print('Error validating API: $e');
      return false;
    }

    return true;
  }

  Future<bool> sendSms(SMSMessage message) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.example.com/sms/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_API_KEY',
        },
        body: jsonEncode(message.toJson()),
      );

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      print('Error sending SMS: $e');
    }

    return false;
  }
}
