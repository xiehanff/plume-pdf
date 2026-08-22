import 'package:shared_preferences/shared_preferences.dart';

import 'deepseek_service.dart';

class DeepSeekSettingsStore {
  Future<String> loadApiKey() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getString(DeepSeekService.apiKeyStorageKey) ?? '';
  }

  Future<void> saveApiKey(String apiKey) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      DeepSeekService.apiKeyStorageKey,
      apiKey.trim(),
    );
  }
}
