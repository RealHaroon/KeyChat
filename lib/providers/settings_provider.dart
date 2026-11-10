import 'package:flutter/material.dart';

import '../models/ai_provider.dart';
import '../services/secure_key_storage.dart';
import '../services/settings_storage.dart';

/// App-wide settings: provider, model, theme, system prompt, and whether an
/// API key is saved. Widgets listen to it and rebuild when it changes.
///
/// Note: the key itself is never kept here. Only a "has key" flag is, and the
/// key is read from secure storage right before each request.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({required this._storage, required this._keyStorage});

  final SettingsStorage _storage;
  final SecureKeyStorage _keyStorage;

  static const defaultSystemPrompt =
      'You are KeyChat, a helpful and friendly AI assistant. '
      'KeyChat is an app created by Haroon. When asked who you are or who '
      'created you, say you are KeyChat, made by Haroon. If asked about the '
      'underlying AI model, explain that KeyChat lets the user pick a model '
      'from a provider such as Groq or OpenRouter. '
      'Answer clearly and use Markdown (lists, bold, code blocks) when it helps.';

  AiProvider _provider = AiProvider.all.first;
  ThemeMode _themeMode = ThemeMode.system;
  String _systemPrompt = defaultSystemPrompt;
  String? _selectedModel;
  bool _hasApiKey = false;

  AiProvider get provider => _provider;
  ThemeMode get themeMode => _themeMode;
  String get systemPrompt => _systemPrompt;
  String? get selectedModel => _selectedModel;
  bool get hasApiKey => _hasApiKey;

  /// Loads saved settings. Called once before the app starts.
  Future<void> load() async {
    _provider = AiProvider.byId(_storage.providerId);
    _themeMode = _storage.themeMode;
    _systemPrompt = _storage.systemPrompt ?? defaultSystemPrompt;
    _selectedModel = _storage.modelFor(_provider.id);
    _hasApiKey = await _keyStorage.hasKey(_provider.id);
    notifyListeners();
  }

  /// Makes [provider] the active one and loads its saved model and key status.
  Future<void> setProvider(AiProvider provider) async {
    _provider = provider;
    _selectedModel = _storage.modelFor(provider.id);
    _hasApiKey = await _keyStorage.hasKey(provider.id);
    await _storage.setProviderId(provider.id);
    notifyListeners();
  }

  /// Saves a key that was already tested, and switches to its provider.
  Future<void> saveApiKey(AiProvider provider, String apiKey) async {
    await _keyStorage.saveKey(provider.id, apiKey);
    await setProvider(provider);
  }

  Future<void> deleteApiKey(AiProvider provider) async {
    await _keyStorage.deleteKey(provider.id);
    if (provider.id == _provider.id) {
      _hasApiKey = false;
      notifyListeners();
    }
  }

  Future<bool> hasKeyFor(AiProvider provider) =>
      _keyStorage.hasKey(provider.id);

  Future<void> selectModel(String modelId) async {
    _selectedModel = modelId;
    await _storage.setModelFor(_provider.id, modelId);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _storage.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setSystemPrompt(String prompt) async {
    _systemPrompt = prompt.trim();
    await _storage.setSystemPrompt(_systemPrompt);
    notifyListeners();
  }
}
