import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_api/storage/settings/type.dart';

class Storage {
  static final String _settingsKey = 'settings_data';

  Future<bool> save(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    var settingsJson = jsonEncode(settings.toJson());
    print('Saving settings: $settingsJson'); // Debug print
    final result = await prefs.setString(_settingsKey, settingsJson);
    print('Save result: $result'); // Debug print
    return result;
  }

  Future<Settings?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    print('Loading settings: $settingsJson'); // Debug print
    if (settingsJson != null) {
      final Map<String, dynamic> settingsMap = jsonDecode(settingsJson);
      final settings = Settings.fromJson(settingsMap);
      print(
        'Loaded settings - URL: ${settings.url}, API Key: ${settings.apiKey}',
      ); // Debug print
      return settings;
    }

    print('No settings found'); // Debug print
    return null;
  }
}
