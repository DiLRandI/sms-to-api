import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'logging_service.dart';
import 'persistent_sms_service.dart';

class SmsService with WidgetsBindingObserver {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  static Timer? _pollingTimer;
  static bool _isServiceActive = false;

  // Initialize the service with app lifecycle awareness
  static Future<void> initialize() async {
    _instance._setupLifecycleObserver();
    await LoggingService.info(
      'SMS service initialized with lifecycle awareness',
      'Ready for foreground/background handling',
    );
  }

  void _setupLifecycleObserver() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppForegrounded();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _onAppBackgrounded();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _onAppForegrounded() async {
    if (_isServiceActive) {
      await LoggingService.info(
        'App returned to foreground',
        'Resuming active SMS monitoring',
      );

      // Do an immediate check for any messages missed while backgrounded
      await PersistentSmsService.checkForNewSmsWithPersistence();

      // Resume frequent polling
      _startForegroundPolling();
    }
  }

  void _onAppBackgrounded() async {
    if (_isServiceActive) {
      await LoggingService.info(
        'App moved to background',
        'Switching to slower polling to preserve battery',
      );

      // Stop frequent polling
      _pollingTimer?.cancel();

      // Start slower background polling
      _startBackgroundPolling();
    }
  }

  static void _startForegroundPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      PersistentSmsService.checkForNewSmsWithPersistence();
    });
  }

  static void _startBackgroundPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      PersistentSmsService.checkForNewSmsWithPersistence();
    });
  }

  // Request SMS permissions
  static Future<bool> requestPermissions() async {
    final smsPermission = await Permission.sms.request();
    return smsPermission.isGranted;
  }

  // Check if permissions are granted
  static Future<bool> hasPermissions() async {
    return await Permission.sms.isGranted;
  }

  // Request battery optimization exemption for better background execution
  static Future<bool> requestBatteryOptimizationExemption() async {
    try {
      final result = await Permission.ignoreBatteryOptimizations.request();
      if (result.isGranted) {
        await LoggingService.success(
          'Battery optimization exemption granted',
          'App can now run more reliably in background',
        );
        return true;
      } else {
        await LoggingService.warning(
          'Battery optimization exemption denied',
          'Background execution may be limited',
        );
        return false;
      }
    } catch (e) {
      await LoggingService.error(
        'Failed to request battery optimization exemption: $e',
        'Background execution may be unreliable',
      );
      return false;
    }
  }

  // Initialize SMS listener with hybrid approach (foreground fast polling + background slow polling)
  static Future<void> initializeSmsListener() async {
    if (!await hasPermissions()) {
      await LoggingService.error(
        'Cannot initialize SMS listener',
        'SMS permissions not granted',
      );
      return;
    }

    await LoggingService.info(
      'Initializing hybrid SMS listener',
      'Foreground polling + background monitoring',
    );

    _isServiceActive = true;

    // Start foreground polling (fast)
    _startForegroundPolling();

    await LoggingService.info(
      'Hybrid SMS listener initialized',
      'Foreground: 5s polling, Background: 2min intervals',
    );
  }

  // Stop SMS listener
  static Future<void> stopSmsListener() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isServiceActive = false;

    await LoggingService.info('SMS listener stopped', 'All monitoring stopped');
  }
}
