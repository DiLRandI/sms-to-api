import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'SMS TO API',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurpleAccent),
//       ),
//       home: const MyHomePage(title: 'SMS TO API'),
//     );
//   }
// }
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Counter Service',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CounterScreen(),
    );
  }
}

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  // Define the MethodChannel with a unique name
  static const MethodChannel _channel = MethodChannel(
    'com.github.dilrandi.sms_to_api/counter',
  );

  int _counter = 0;
  String _serviceStatus = 'Not Running'; // Initial status

  @override
  void initState() {
    super.initState();
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
      appBar: AppBar(title: const Text('Flutter Android Counter')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
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
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _incrementCounter,
                child: const Text('Increment Counter'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _getCounter,
                child: const Text('Get Counter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
