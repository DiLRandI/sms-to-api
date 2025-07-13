import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logging_service.dart';

class AndroidSmsService {
  static const MethodChannel _channel = MethodChannel('sms_forwarding_service');

  static Future<bool> startService() async {
    try {
      await LoggingService.info(
        'Starting Android SMS service',
        'Initiating background service startup',
      );

      final result = await _channel.invokeMethod('startService');

      if (result == true) {
        await LoggingService.success(
          'Android SMS service started',
          'Background service is now active and monitoring SMS',
        );

        // Update service state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('service_enabled', true);

        return true;
      } else {
        await LoggingService.error(
          'Failed to start Android SMS service',
          'Service startup returned false',
        );
        return false;
      }
    } catch (e) {
      await LoggingService.error(
        'Error starting Android SMS service',
        'Exception: $e',
      );
      return false;
    }
  }

  static Future<bool> stopService() async {
    try {
      await LoggingService.info(
        'Stopping Android SMS service',
        'Initiating background service shutdown',
      );

      final result = await _channel.invokeMethod('stopService');

      if (result == true) {
        await LoggingService.info(
          'Android SMS service stopped',
          'Background service is no longer active',
        );

        // Update service state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('service_enabled', false);

        return true;
      } else {
        await LoggingService.warning(
          'Android SMS service stop returned false',
          'Service may still be running',
        );
        return false;
      }
    } catch (e) {
      await LoggingService.error(
        'Error stopping Android SMS service',
        'Exception: $e',
      );
      return false;
    }
  }

  static Future<bool> isServiceRunning() async {
    try {
      final result = await _channel.invokeMethod('isServiceRunning');
      return result == true;
    } catch (e) {
      await LoggingService.warning(
        'Error checking service status',
        'Exception: $e',
      );
      return false;
    }
  }

  static Future<int> getMessageCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('message_count') ?? 0;
    } catch (e) {
      await LoggingService.warning(
        'Error getting message count',
        'Exception: $e',
      );
      return 0;
    }
  }

  static Future<void> resetMessageCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('message_count', 0);
      await LoggingService.info(
        'Message counter reset',
        'Counter set back to 0',
      );
    } catch (e) {
      await LoggingService.error(
        'Error resetting message count',
        'Exception: $e',
      );
    }
  }

  static Future<void> requestBatteryOptimizationExemption() async {
    try {
      await _channel.invokeMethod('requestBatteryOptimization');
      await LoggingService.info(
        'Battery optimization exemption requested',
        'User will see system dialog',
      );
    } catch (e) {
      await LoggingService.warning(
        'Error requesting battery optimization exemption',
        'Exception: $e',
      );
    }
  }
}
