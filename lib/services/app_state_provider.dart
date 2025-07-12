import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'sms_service.dart';
import 'logging_service.dart';

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
    _hasPermissions = await SmsService.hasPermissions();
    notifyListeners();
  }

  // Request permissions
  Future<bool> requestPermissions() async {
    setLoading(true);
    final granted = await SmsService.requestPermissions();
    _hasPermissions = granted;
    setLoading(false);
    return granted;
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
        'SMS service starting',
        'User initiated service start',
      );
      await SmsService.initializeSmsListener();
      await LoggingService.success(
        'SMS service started',
        'Service is now monitoring for incoming SMS',
      );
    } else {
      await LoggingService.info(
        'SMS service stopping',
        'User initiated service stop',
      );
      SmsService.stopSmsListener();
      await LoggingService.info(
        'SMS service stopped',
        'Service is no longer monitoring SMS',
      );
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
    _messageCount = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('message_count', _messageCount);
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
