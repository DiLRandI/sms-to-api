import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_api/storage/settings/api_endpoint.dart';
import 'package:sms_to_api/storage/settings/storage.dart';
import 'package:sms_to_api/storage/settings/type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(Storage.channelName);
  late List<MethodCall> recordedCalls;
  String? storedPayload;

  setUp(() {
    recordedCalls = <MethodCall>[];
    storedPayload = null;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      recordedCalls.add(methodCall);
      switch (methodCall.method) {
        case 'saveSettings':
          storedPayload = methodCall.arguments['payload'] as String?;
          return true;
        case 'loadSettings':
          return storedPayload;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Settings buildSettings() {
    return Settings(
      endpoints: const [
        ApiEndpoint(
          id: '1',
          name: 'Primary',
          url: 'https://example.com',
          apiKey: 'secret123',
          authHeaderName: 'X-Api-Key',
        ),
      ],
      phoneNumbers: const ['+15551234567'],
    );
  }

  test('Storage persists settings through secure channel', () async {
    final storage = Storage();
    final settings = buildSettings();

    final saved = await storage.save(settings);
    expect(saved, isTrue);
    expect(recordedCalls.map((c) => c.method), contains('saveSettings'));
    expect(storedPayload, isNotNull);

    final loaded = await storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.endpoints.single.apiKey, equals('secret123'));
    expect(loaded.phoneNumbers.single, equals('+15551234567'));
  });

  test('Storage falls back to legacy preferences when channel missing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    final settings = buildSettings();
    final storage = Storage();

    final saved = await storage.save(settings);
    expect(saved, isTrue);

    final prefs = await SharedPreferences.getInstance();
    final legacyRaw = prefs.getString('settings_data');
    expect(legacyRaw, isNotNull);

    final reloaded = await storage.load();
    expect(reloaded, isNotNull);
    expect(jsonDecode(legacyRaw!)['endpoints'], isNotEmpty);
  });
}

