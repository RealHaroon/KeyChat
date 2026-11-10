import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/setup_screen.dart';
import 'theme/app_theme.dart';

class KeyChatApp extends StatelessWidget {
  const KeyChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    // select() rebuilds the app only when these two values change,
    // not on every settings change (e.g. picking a new model).
    final themeMode = context.select((SettingsProvider s) => s.themeMode);
    final hasApiKey = context.select((SettingsProvider s) => s.hasApiKey);

    return MaterialApp(
      title: 'KeyChat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // No key yet -> onboarding. Once a key is saved this rebuilds and the
      // chat screen appears automatically.
      home: hasApiKey
          ? const ChatScreen()
          : const SetupScreen(isOnboarding: true),
    );
  }
}
