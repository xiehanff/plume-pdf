import 'package:shared_preferences/shared_preferences.dart';

/// Plume host policy for persisting the DeepSeek credential.
///
/// Credential storage deliberately stays outside `plume_ai_chat`; other host
/// applications may choose secure storage, a server proxy or another policy.
class DeepSeekSettingsStore {
  static const String _apiKeyStorageKey = 'deepseek_api_key';

  Future<String> loadApiKey() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getString(_apiKeyStorageKey) ?? '';
  }

  Future<void> saveApiKey(String apiKey) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_apiKeyStorageKey, apiKey.trim());
  }
}
