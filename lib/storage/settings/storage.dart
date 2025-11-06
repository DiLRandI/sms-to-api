import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_api/storage/settings/type.dart';

class Storage {
  Storage({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName =
      'com.github.dilrandi.sms_to_api/settings';
  static const String _legacySettingsKey = 'settings_data';
  final MethodChannel _channel;

  Future<bool> save(Settings settings) async {
    final payload = jsonEncode(settings.toJson());

    try {
      final result = await _channel.invokeMethod<bool>(
        'saveSettings',
        {'payload': payload},
      );
      if (result == true) {
        return true;
      }
    } on MissingPluginException {
      // Fall back to legacy storage for unsupported platforms/tests.
    } on PlatformException {
      // If secure storage fails, attempt legacy fallback so settings are not lost.
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_legacySettingsKey, payload);
  }

  Future<Settings?> load() async {
    String? settingsJson;

    try {
      settingsJson = await _channel.invokeMethod<String>('loadSettings');
    } on MissingPluginException {
      // Fall back to legacy store when secure channel is unavailable.
    } on PlatformException {
      // Ignore and try legacy fallback below.
    }

    settingsJson ??=
        (await SharedPreferences.getInstance()).getString(_legacySettingsKey);

    if (settingsJson == null) {
      return null;
    }

    final Map<String, dynamic> settingsMap = jsonDecode(settingsJson);
    return Settings.fromJson(settingsMap);
  }
}
