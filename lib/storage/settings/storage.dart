import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_api/storage/settings/type.dart';

class Storage {
  static final String _settingsKey = 'settings_data';

  Future<bool> save(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    var settingsJson = jsonEncode(settings.toJson());
    // Avoid printing secrets (like API keys). If needed, log only safe metadata.
    final result = await prefs.setString(_settingsKey, settingsJson);
    return result;
  }

  Future<Settings?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    if (settingsJson != null) {
      final Map<String, dynamic> settingsMap = jsonDecode(settingsJson);
      final settings = Settings.fromJson(settingsMap);
      return settings;
    }
    return null;
  }
}
