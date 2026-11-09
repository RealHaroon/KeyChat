import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'services/chat_storage.dart';
import 'services/llm_api_service.dart';
import 'services/secure_key_storage.dart';
import 'services/settings_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phone-first app: lock to portrait.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Create the services once, then load saved data before showing any UI.
  final keyStorage = SecureKeyStorage();
  final api = LlmApiService();
  final settingsStorage = await SettingsStorage.create();
  final chatStorage = await ChatStorage.create();

  final settings = SettingsProvider(
    storage: settingsStorage,
    keyStorage: keyStorage,
  );
  await settings.load();

  final chat = ChatProvider(
    storage: chatStorage,
    api: api,
    keyStorage: keyStorage,
  )..load();

  runApp(
    MultiProvider(
      providers: [
        // Plain services, read by screens with context.read<...>().
        Provider.value(value: api),
        Provider.value(value: keyStorage),
        // State that widgets listen to with context.watch<...>().
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: chat),
      ],
      child: const KeyChatApp(),
    ),
  );
}
