import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sms_to_api/service/api_service.dart';
import 'package:sms_to_api/storage/settings/api_endpoint.dart';
import 'package:sms_to_api/storage/settings/storage.dart';
import 'package:sms_to_api/storage/settings/type.dart';

class _StubStorage extends Storage {
  _StubStorage(this.settings) : super(channel: const MethodChannel(Storage.channelName));

  final Settings settings;

  @override
  Future<Settings?> load() async => settings;

  @override
  Future<bool> save(Settings settings) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('validateApi returns true when an endpoint responds 200', () async {
    final client = MockClient((request) async {
      expect(request.method, equals('POST'));
      expect(request.headers['X-Api-Key'], equals('abc123'));
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['test'], isTrue);
      return http.Response('{}', 200);
    });

    final storage = _StubStorage(
      Settings(
        endpoints: const [
          ApiEndpoint(
            id: '1',
            name: 'Primary',
            url: 'https://example.com',
            apiKey: 'abc123',
            authHeaderName: 'X-Api-Key',
            active: true,
          ),
        ],
      ),
    );

    final service = ApiService(storage: storage, httpClient: client);
    expect(await service.validateApi(), isTrue);
  });

  test('validateEndpoint uses fallback header when endpoint header missing', () async {
    final capturedHeaders = <String, String>{};
    final client = MockClient((request) async {
      capturedHeaders.addAll(request.headers);
      return http.Response('{}', 200);
    });

    final storage = _StubStorage(
      Settings(
        authHeaderName: 'Authorization',
        endpoints: const [
          ApiEndpoint(
            id: '1',
            name: 'Fallback',
            url: 'https://example.com',
            apiKey: 'token',
            authHeaderName: '',
            active: true,
          ),
        ],
      ),
    );

    final service = ApiService(storage: storage, httpClient: client);
    final result = await service.validateEndpoint(storage.settings.endpoints.first);

    expect(result, isTrue);
    expect(capturedHeaders['Authorization'], equals('token'));
  });

  test('validateEndpoint masks secrets in error logging', () async {
    var loggedMessage = '';
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        loggedMessage = message;
      }
    };

    addTearDown(() {
      debugPrint = originalDebugPrint;
    });

    final failingClient = MockClient((request) async {
      throw Exception('apiKey=super-secret-token');
    });

    final storage = _StubStorage(
      Settings(
        endpoints: const [
          ApiEndpoint(
            id: '1',
            name: 'Primary',
            url: 'https://example.com',
            apiKey: 'super-secret-token',
            authHeaderName: 'X-Api-Key',
            active: true,
          ),
        ],
      ),
    );

    final service = ApiService(storage: storage, httpClient: failingClient);
    final ok = await service.validateEndpoint(storage.settings.endpoints.first);

    expect(ok, isFalse);
    expect(loggedMessage.contains('***'), isTrue);
    expect(loggedMessage.contains('super-secret-token'), isFalse);
  });
}
