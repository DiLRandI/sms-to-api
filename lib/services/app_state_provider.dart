import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';
import 'android_sms_service.dart';
import 'logging_service.dart';
import 'dart:async';

class AppStateProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isServiceEnabled = false;
  bool _hasPermissions = false;
  String _apiUrl = '';
  String _apiKey = '';
  bool _isLoading = false;
  String _statusMessage = 'Service stopped';
  int _messageCount = 0;

  // Getters
  bool get isServiceEnabled => _isServiceEnabled;
  bool get hasPermissions => _hasPermissions;
  String get apiUrl => _apiUrl;
  String get apiKey => _apiKey;
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  int get messageCount => _messageCount;

  AppStateProvider() {
    _loadSettings();
    _checkPermissions();
    _startMessageCountUpdater();
  }

  Timer? _messageCountTimer;

  void _startMessageCountUpdater() {
    _messageCountTimer?.cancel();
    _messageCountTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      await _updateMessageCountFromService();
    });
  }

  Future<void> _updateMessageCountFromService() async {
    try {
      final count = await AndroidSmsService.getMessageCount();
      if (count != _messageCount) {
        _messageCount = count;
        notifyListeners();
      }
    } catch (e) {
      // Silent fail - service might not be running
    }
  }

  @override
  void dispose() {
    _messageCountTimer?.cancel();
    super.dispose();
  }

  // Load settings from storage
  Future<void> _loadSettings() async {
    setLoading(true);

    final prefs = await SharedPreferences.getInstance();
    _isServiceEnabled = prefs.getBool('service_enabled') ?? false;
    _messageCount = prefs.getInt('message_count') ?? 0;

    final config = await _apiService.getApiConfig();
    _apiUrl = config['url'] ?? '';
    _apiKey = config['key'] ?? '';

    _updateStatusMessage();
    setLoading(false);
  }

  // Check permissions
  Future<void> _checkPermissions() async {
    _hasPermissions = await Permission.sms.isGranted;
    notifyListeners();
  }

  // Request permissions
  Future<bool> requestPermissions() async {
    setLoading(true);
    final smsPermission = await Permission.sms.request();
    _hasPermissions = smsPermission.isGranted;
    setLoading(false);
    return _hasPermissions;
  }

  // Update API configuration
  Future<void> updateApiConfig(String url, String key) async {
    setLoading(true);

    _apiUrl = url;
    _apiKey = key;

    await _apiService.saveApiConfig(url, key);
    await LoggingService.info('API configuration updated', 'URL: $url');
    _updateStatusMessage();

    setLoading(false);
  }

  // Test API connection
  Future<bool> testApiConnection() async {
    setLoading(true);
    await LoggingService.info(
      'Testing API connection',
      'Attempting to connect to configured endpoint',
    );
    final success = await _apiService.testApiConnection();

    if (success) {
      await LoggingService.success(
        'API connection test successful',
        'API endpoint is reachable',
      );
    } else {
      await LoggingService.error(
        'API connection test failed',
        'Check URL and network connectivity',
      );
    }

    setLoading(false);
    return success;
  }

  // Toggle service
  Future<void> toggleService() async {
    if (!_hasPermissions) {
      final granted = await requestPermissions();
      if (!granted) {
        await LoggingService.error(
          'Service toggle failed',
          'SMS permissions not granted',
        );
        return;
      }
    }

    setLoading(true);

    _isServiceEnabled = !_isServiceEnabled;

    if (_isServiceEnabled) {
      await LoggingService.info(
        'Android SMS service starting',
        'User initiated service start',
      );
      final success = await AndroidSmsService.startService();
      if (success) {
        await LoggingService.success(
          'Android SMS service started',
          'Background service is now monitoring for incoming SMS',
        );
        // Request battery optimization exemption for better reliability
        await AndroidSmsService.requestBatteryOptimizationExemption();
      } else {
        _isServiceEnabled = false;
        await LoggingService.error(
          'Failed to start Android SMS service',
          'Service initialization failed',
        );
      }
    } else {
      await LoggingService.info(
        'Android SMS service stopping',
        'User initiated service stop',
      );
      final success = await AndroidSmsService.stopService();
      if (success) {
        await LoggingService.info(
          'Android SMS service stopped',
          'Background service is no longer monitoring SMS',
        );
      } else {
        await LoggingService.warning(
          'Android SMS service stop may have failed',
          'Service might still be running',
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('service_enabled', _isServiceEnabled);

    _updateStatusMessage();
    setLoading(false);
  }

  // Increment message count
  void incrementMessageCount() async {
    _messageCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('message_count', _messageCount);
    notifyListeners();
  }

  // Reset message count
  void resetMessageCount() async {
    await AndroidSmsService.resetMessageCount();
    _messageCount = 0;
    notifyListeners();
  }

  // Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Update status message
  void _updateStatusMessage() {
    if (!_hasPermissions) {
      _statusMessage = 'Permissions required';
    } else if (_apiUrl.isEmpty) {
      _statusMessage = 'API URL not configured';
    } else if (_isServiceEnabled) {
      _statusMessage = 'Service running - monitoring SMS';
    } else {
      _statusMessage = 'Service stopped';
    }
    notifyListeners();
  }
}
