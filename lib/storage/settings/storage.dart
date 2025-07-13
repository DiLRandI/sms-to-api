import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_api/storage/settings/type.dart';

class Storage {
  static final String _prefix = 'settings_';

  Future<void> save(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefix}URL', settings.url);
    await prefs.setString('${_prefix}APIKey', settings.apiKey);
  }

  Future<Settings?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('${_prefix}URL');
    final apiKey = prefs.getString('${_prefix}APIKey');
    if (url != null && apiKey != null) {
      return Settings(url: url, apiKey: apiKey);
    }

    return null;
  }
}
