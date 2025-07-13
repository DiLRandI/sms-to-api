import 'package:flutter/material.dart';
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
  void initState() {
    super.initState();
    _checkSettings();
  }

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
