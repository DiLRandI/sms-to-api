import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_to_api/screen/logs.dart';
import 'package:sms_to_api/screen/phone_numbers.dart';
import 'package:sms_to_api/screen/settings.dart';
import 'package:sms_to_api/service/api_service.dart';
import 'package:sms_to_api/service/log_service.dart';
import 'package:sms_to_api/storage/settings/storage.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _apiService = ApiService();
  final _storage = Storage();
  final _logService = LogService();
  bool _isSettingsConfigured = false;
  bool _isApiReachable = false;
  bool _isCheckingApi = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkSettings();
  }

  Future<void> _checkSettings() async {
    await _logService.logDebug('UI', 'Checking application settings');

    // Check if settings are configured
    final settings = await _storage.load();
    final settingsConfigured =
        settings != null &&
        settings.url.isNotEmpty &&
        settings.apiKey.isNotEmpty;

    await _logService.logInfo('UI', 'Settings configured: $settingsConfigured');

    setState(() {
      _isSettingsConfigured = settingsConfigured;
      _isCheckingApi =
          settingsConfigured; // Only check API if settings are configured
    });

    // Only check API reachability if settings are configured
    if (settingsConfigured) {
      await _logService.logDebug('UI', 'Checking API reachability');
      final isReachable = await _apiService.validateApi();
      await _logService.logInfo('UI', 'API reachable: $isReachable');
      setState(() {
        _isApiReachable = isReachable;
        _isCheckingApi = false;
      });
    } else {
      setState(() {
        _isApiReachable = false;
        _isCheckingApi = false;
      });
    }
  }

  static const MethodChannel _channel = MethodChannel(
    'com.example.flutter_counter_service/counter',
  );

  int _counter = 0;
  String _serviceStatus = 'Not Running'; // Initial status

  @override
  void initState() {
    super.initState();
    _checkSettings();

    // Add logging for UI initialization
    _logService.logDebug('UI', 'Home screen initialized');

    // Listen for method calls from the native side (e.g., service status updates)
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onServiceStatusChanged') {
        await _logService.logInfo(
          'Service',
          'Status changed: ${call.arguments}',
        );
        setState(() {
          _serviceStatus = call.arguments as String;
        });
      }
    });
  }

  // Method to start the native Android foreground service
  Future<void> _startService() async {
    try {
      await _logService.logInfo('UI', 'Attempting to start background service');
      final String result = await _channel.invokeMethod('startCounterService');
      setState(() {
        _serviceStatus = result;
      });
      await _logService.logInfo('UI', 'Service started successfully: $result');
      _showSnackBar("Service started: $result");
    } on PlatformException catch (e) {
      setState(() {
        _serviceStatus = "Failed to start: '${e.message}'";
      });
      await _logService.logError('UI', 'Failed to start service: ${e.message}');
      debugPrint("Failed to start service: ${e.message}");
      _showSnackBar("Error starting service: ${e.message}");
    }
  }

  // Method to stop the native Android foreground service
  Future<void> _stopService() async {
    try {
      await _logService.logInfo('UI', 'Attempting to stop background service');
      final String result = await _channel.invokeMethod('stopCounterService');
      setState(() {
        _serviceStatus = result;
        _counter = 0; // Reset counter when service stops
      });
      await _logService.logInfo('UI', 'Service stopped successfully: $result');
      _showSnackBar("Service stopped: $result");
    } on PlatformException catch (e) {
      setState(() {
        _serviceStatus = "Failed to stop: '${e.message}'";
      });
      await _logService.logError('UI', 'Failed to stop service: ${e.message}');
      debugPrint("Failed to stop service: ${e.message}");
      _showSnackBar("Error stopping service: ${e.message}");
    }
  }

  // Method to bind to the native Android service
  Future<void> _bindService() async {
    try {
      final String result = await _channel.invokeMethod('bindCounterService');
      setState(() {
        _serviceStatus = result;
      });
      _showSnackBar("Service bind request: $result");
    } on PlatformException catch (e) {
      setState(() {
        _serviceStatus = "Failed to bind: '${e.message}'";
      });
      debugPrint("Failed to bind service: ${e.message}");
      _showSnackBar("Error binding service: ${e.message}");
    }
  }

  // Method to unbind from the native Android service
  Future<void> _unbindService() async {
    try {
      final String result = await _channel.invokeMethod('unbindCounterService');
      setState(() {
        _serviceStatus = result;
      });
      _showSnackBar("Service unbind request: $result");
    } on PlatformException catch (e) {
      setState(() {
        _serviceStatus = "Failed to unbind: '${e.message}'";
      });
      debugPrint("Failed to unbind service: ${e.message}");
      _showSnackBar("Error unbinding service: ${e.message}");
    }
  }

  // Method to increment the counter in the native Android service
  Future<void> _incrementCounter() async {
    try {
      final int result = await _channel.invokeMethod('incrementCounter');
      setState(() {
        _counter = result;
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to increment counter: '${e.message}'");
      _showSnackBar("Error: ${e.message}");
    }
  }

  // Method to get the current counter value from the native Android service
  Future<void> _getCounter() async {
    try {
      final int result = await _channel.invokeMethod('getCounter');
      setState(() {
        _counter = result;
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to get counter: '${e.message}'");
      _showSnackBar("Error: ${e.message}");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildStatusSection() {
    return Column(
      children: [
        // Settings Configuration Status Card
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Card(
            elevation: _isSettingsConfigured ? 2 : 4,
            color: _isSettingsConfigured
                ? Colors.green.shade50
                : Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _isSettingsConfigured
                    ? Colors.green.shade200
                    : Colors.red.shade200,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isSettingsConfigured
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isSettingsConfigured ? Icons.check_circle : Icons.error,
                      color: _isSettingsConfigured ? Colors.green : Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings Configuration',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isSettingsConfigured
                              ? 'All settings are properly configured'
                              : 'Please configure your API settings',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _isSettingsConfigured
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // API Reachability Status Card
        if (_isSettingsConfigured) ...[
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Card(
              elevation: _isApiReachable ? 2 : 4,
              color: _isCheckingApi
                  ? Colors.blue.shade50
                  : _isApiReachable
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _isCheckingApi
                      ? Colors.blue.shade200
                      : _isApiReachable
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isCheckingApi
                            ? Colors.blue.shade100
                            : _isApiReachable
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isCheckingApi
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue,
                                ),
                              ),
                            )
                          : Icon(
                              _isApiReachable
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: _isApiReachable
                                  ? Colors.green
                                  : Colors.orange,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'API Endpoint Status',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isCheckingApi
                                ? 'Checking endpoint connectivity...'
                                : _isApiReachable
                                ? 'API endpoint is reachable and responding'
                                : 'API endpoint is not reachable',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: _isCheckingApi
                                      ? Colors.blue.shade700
                                      : _isApiReachable
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildServiceInfoSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service Information',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status: $_serviceStatus',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.numbers,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Counter: $_counter',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceControlSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service Control',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startService,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _stopService,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _bindService,
                    icon: const Icon(Icons.link),
                    label: const Text('Bind'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _unbindService,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Unbind'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterActionsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Counter Actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _incrementCounter,
                icon: const Icon(Icons.add),
                label: const Text('Increment Counter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _getCounter,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Counter'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Text(
          widget.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _checkSettings,
            tooltip: 'Refresh Status',
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PhoneNumbersScreen(),
                ),
              );
            },
            tooltip: 'Phone Numbers',
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogsScreen()),
              );
            },
            tooltip: 'View Logs',
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              foregroundColor: Theme.of(context).colorScheme.onTertiary,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              // Refresh the validation status when returning from settings
              _checkSettings();
            },
            tooltip: 'Settings',
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Cards Section
            _buildStatusSection(),

            const SizedBox(height: 24),

            // Service Information Section
            _buildServiceInfoSection(),

            const SizedBox(height: 24),

            // Service Control Section
            _buildServiceControlSection(),

            const SizedBox(height: 24),

            // Counter Actions Section
            _buildCounterActionsSection(),
          ],
        ),
      ),
    );
  }
}
