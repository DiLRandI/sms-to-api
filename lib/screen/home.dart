import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_to_api/screen/settings.dart';
import 'package:sms_to_api/service/api_service.dart';
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
  bool _isSettingsConfigured = false;
  bool _isApiReachable = false;
  bool _isCheckingApi = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkSettings();
  }

  Future<void> _checkSettings() async {
    // Check if settings are configured
    final settings = await _storage.load();
    final settingsConfigured =
        settings != null &&
        settings.url.isNotEmpty &&
        settings.apiKey.isNotEmpty;

    setState(() {
      _isSettingsConfigured = settingsConfigured;
      _isCheckingApi =
          settingsConfigured; // Only check API if settings are configured
    });

    // Only check API reachability if settings are configured
    if (settingsConfigured) {
      final isReachable = await _apiService.validateApi();
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
    // Listen for method calls from the native side (e.g., service status updates)
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onServiceStatusChanged') {
        setState(() {
          _serviceStatus = call.arguments as String;
        });
      }
    });
  }

  // Method to start the native Android foreground service
  Future<void> _startService() async {
    try {
      final String result = await _channel.invokeMethod('startCounterService');
      setState(() {
        _serviceStatus = result;
      });
      _showSnackBar("Service started: $result");
    } on PlatformException catch (e) {
      setState(() {
        _serviceStatus = "Failed to start: '${e.message}'";
      });
      debugPrint("Failed to start service: ${e.message}");
      _showSnackBar("Error starting service: ${e.message}");
    }
  }

  // Method to stop the native Android foreground service
  Future<void> _stopService() async {
    try {
      final String result = await _channel.invokeMethod('stopCounterService');
      setState(() {
        _serviceStatus = result;
        _counter = 0; // Reset counter when service stops
      });
      _showSnackBar("Service stopped: $result");
    } on PlatformException catch (e) {
      setState(() {
        _serviceStatus = "Failed to stop: '${e.message}'";
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkSettings,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              // Refresh the validation status when returning from settings
              _checkSettings();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Settings Configuration Status
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isSettingsConfigured
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                border: Border.all(
                  color: _isSettingsConfigured ? Colors.green : Colors.red,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSettingsConfigured ? Icons.check_circle : Icons.error,
                    color: _isSettingsConfigured ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isSettingsConfigured
                        ? 'Settings configured'
                        : 'Please configure settings',
                    style: TextStyle(
                      color: _isSettingsConfigured ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              child: Row(
                children: [
                  Text(
                    'Service Status: $_serviceStatus',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Counter Value: $_counter',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _startService,
                    child: const Text('Start Service'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _stopService,
                    child: const Text('Stop Service'),
                  ),
                  const SizedBox(height: 20), // Added spacing
                  ElevatedButton(
                    onPressed: _bindService,
                    child: const Text('Bind Service'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _unbindService,
                    child: const Text('Unbind Service'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _incrementCounter,
                    child: const Text('Increment Counter (App UI)'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _getCounter,
                    child: const Text('Get Counter (App UI)'),
                  ),
                ],
              ),
            ),

            // API Reachability Status
            if (_isSettingsConfigured)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _isCheckingApi
                      ? Colors.blue.shade100
                      : _isApiReachable
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  border: Border.all(
                    color: _isCheckingApi
                        ? Colors.blue
                        : _isApiReachable
                        ? Colors.green
                        : Colors.orange,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isCheckingApi)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        ),
                      )
                    else
                      Icon(
                        _isApiReachable ? Icons.check_circle : Icons.warning,
                        color: _isApiReachable ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _isCheckingApi
                          ? 'Checking API endpoint...'
                          : _isApiReachable
                          ? 'API endpoint reachable'
                          : 'API endpoint not reachable',
                      style: TextStyle(
                        color: _isCheckingApi
                            ? Colors.blue
                            : _isApiReachable
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
