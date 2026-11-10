# KeyChat – project context for Claude

Flutter "bring your own API key" chatbot for a university App Development course.
Code must stay clean, well-organized and easy to explain in a presentation.

## Platforms
- **Android and iOS only.** Never add or configure web, Linux, Windows or macOS.
- The developer is on Ubuntu (8 GB RAM) and tests Android with `flutter run` on a phone/emulator.
  iOS code/config must stay correct but is tested later on a Mac.
- Only use packages that support both Android and iOS.

## Architecture (see README.md for full details)
- `lib/models`: AiProvider (provider list: Groq, OpenRouter), AiModel, ChatMessage, Conversation,
  AppInfo (identity prompt about KeyChat + creator Haroon, always sent before the user's system prompt;
  only state facts the user confirmed, never invent personal details)
- `lib/services`: LlmApiService (ONE service for all OpenAI-compatible APIs, SSE streaming),
  ApiException (friendly errors), SecureKeyStorage (flutter_secure_storage), SettingsStorage
  (shared_preferences), ChatStorage (Hive, conversations stored as JSON strings)
- `lib/providers`: SettingsProvider, ChatProvider (Provider + ChangeNotifier, beginner-friendly)
- `lib/theme/app_theme.dart`: all colors/shapes (seed indigo + brand gradient)
- `lib/screens`: setup, chat, model_picker, settings (history is a drawer, not a screen)
- `lib/widgets`: message_bubble (user bubble / full-width AI reply / error card, Copy + Regenerate),
  code_block (custom `pre` builder with Copy), edit_message_dialog, history_drawer (grouped by date), keychat_logo,
  chat_input (Send/Stop), typing_indicator, empty_chat_view
- ChatProvider throttles streaming redraws to every 50 ms; keep that when touching streaming.
- New OpenAI-compatible providers = one entry in `AiProvider.all`.

## Rules
- API keys: only in flutter_secure_storage; never log, print, or hold them in app state.
- OpenRouter key validation uses `GET /key` (its `/models` is public and accepts any key);
  Groq uses `GET /models`. Model list is always fetched live, never hardcoded.
- Markdown uses `flutter_markdown_plus` (original flutter_markdown is discontinued).
- Android: minSdk 24 (flutter_secure_storage 11), INTERNET permission, Gradle heap 3 GB.
  iOS: deployment target 15.0 (Xcode project + ios/Podfile), display name KeyChat.
- Run `flutter analyze` (must be clean) and `flutter test` after changes.

## Git
- Commit as the user (RealHaroon) only. **Never add a Co-Authored-By / Claude attribution line.**
- Remote: https://github.com/RealHaroon/KeyChat (branch `main`).

## Environment notes
- The project lives at `~/KeyChat`. Never build from a path containing `:`. The old copy at
  `/run/media/haroon/Local Disk (D:)/...` failed with "GradleWrapperMain not found" because Java
  splits classpaths on `:`.
- Release APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.
  Signing uses `android/key.properties` if present, otherwise the debug key.

## Status (Nov 2026)
All 6 phases done: API + chat, setup + secure storage, model picker, markdown + streaming,
history + settings, icons/app name/release APK. Placeholder icon in `assets/icon/` (user will
provide the real one, then run `dart run flutter_launcher_icons`). Not yet tested hands-on on a device.
