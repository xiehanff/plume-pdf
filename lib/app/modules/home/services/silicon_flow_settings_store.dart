import 'package:shared_preferences/shared_preferences.dart';

import 'silicon_flow_service.dart';

class SiliconFlowSettingsStore {
  Future<String> loadApiKey() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getString(SiliconFlowService.apiKeyStorageKey) ?? '';
  }

  Future<void> saveApiKey(String apiKey) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      SiliconFlowService.apiKeyStorageKey,
      apiKey.trim(),
    );
  }
}
