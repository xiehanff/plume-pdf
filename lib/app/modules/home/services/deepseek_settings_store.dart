import 'package:shared_preferences/shared_preferences.dart';

import 'deepseek_service.dart';

class DeepSeekSettingsStore {
  static const String _providerKey = 'ai_selected_provider';

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

  Future<String?> loadSelectedProvider() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getString(_providerKey);
  }

  Future<void> saveSelectedProvider(String provider) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_providerKey, provider);
  }
}
