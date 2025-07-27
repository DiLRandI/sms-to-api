import 'package:flutter/material.dart';
import 'package:sms_to_api/screen/home.dart';
import 'package:sms_to_api/service/log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the log service to listen for Android logs only
  final logService = LogService();
  await logService.initializeLogListener();

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
