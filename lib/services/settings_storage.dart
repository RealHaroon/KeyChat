import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saves small, non-secret settings with shared_preferences
/// (Android SharedPreferences / iOS NSUserDefaults).
///
/// Secrets (API keys) do NOT go here; see [SecureKeyStorage].
class SettingsStorage {
  SettingsStorage(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsStorage> create() async =>
      SettingsStorage(await SharedPreferences.getInstance());

  static const _providerKey = 'provider_id';
  static const _themeKey = 'theme_mode';
  static const _systemPromptKey = 'system_prompt';
  static String _modelKey(String providerId) => 'model_$providerId';

  String? get providerId => _prefs.getString(_providerKey);
  Future<void> setProviderId(String id) => _prefs.setString(_providerKey, id);

  ThemeMode get themeMode =>
      ThemeMode.values.asNameMap()[_prefs.getString(_themeKey)] ??
      ThemeMode.system;
  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeKey, mode.name);

  String? get systemPrompt => _prefs.getString(_systemPromptKey);
  Future<void> setSystemPrompt(String prompt) =>
      _prefs.setString(_systemPromptKey, prompt);

  /// The last selected model is remembered separately for each provider.
  String? modelFor(String providerId) =>
      _prefs.getString(_modelKey(providerId));
  Future<void> setModelFor(String providerId, String modelId) =>
      _prefs.setString(_modelKey(providerId), modelId);
}
