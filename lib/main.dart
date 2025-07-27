import 'package:flutter/material.dart';
import 'package:sms_to_api/screen/home.dart';
import 'package:sms_to_api/service/log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the log service
  final logService = LogService();
  await logService.initializeLogListener();

  // Add some initial logs
  await logService.logInfo('App', 'Application started');
  await logService.logDebug('App', 'Initializing SMS to API service');
  await logService.logInfo('System', 'Log system initialized');

  // Add some sample logs for testing
  await logService.logWarning('Settings', 'No API configuration found');
  await logService.logDebug('UI', 'Building main application widget');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS TO API',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurpleAccent),
      ),
      home: const MyHomePage(title: 'SMS TO API'),
    );
  }
}
