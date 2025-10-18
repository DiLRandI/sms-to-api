import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_api/service/log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('LogService redacts sensitive tokens', () async {
    final logService = LogService();
    await logService.logError('Test', 'apiKey=super-secret-token');

    final logs = await logService.getAllLogs();
    expect(logs, isNotEmpty);
    final entry = logs.last;
    expect(entry.message.contains('***'), isTrue);
    expect(entry.message.contains('super-secret-token'), isFalse);
  });

  test('LogService keeps list bounded', () async {
    final logService = LogService();

    for (var i = 0; i < 400; i++) {
      await logService.logInfo('Bounded', 'message $i');
    }

    final logs = await logService.getAllLogs();
    expect(logs.length <= 300, isTrue);
  });
}

