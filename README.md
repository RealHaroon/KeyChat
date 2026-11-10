# KeyChat

A Flutter chatbot for **Android and iOS** where you **bring your own API key**.
KeyChat talks to cloud LLM providers (Groq and OpenRouter) through their
OpenAI-compatible APIs. No model runs on the phone, and no backend server is involved.
Your key is stored encrypted on the device and sent only to the provider you choose.

## Features

- **Onboarding**: pick a provider, paste your key (there is a paste button), and tap **Test & Save**.
  The key is checked with a real API call before it is saved. Errors say what went wrong: invalid key,
  no internet, rate limit, timeout.
- **Chat**: user bubbles on the right; AI replies use the full width with the KeyChat logo, like
  ChatGPT/Gemini. Replies render as **Markdown** (lists, bold, tables, links), and code blocks show
  the language and a **Copy** button. Every reply has Copy, and the last one has **Regenerate**.
- **Edit messages**: long-press one of your messages → **Edit message**. The reply to it (and
  anything after it) is replaced with a fresh answer.
- **Knows who it is**: every chat starts with hidden instructions from `lib/models/app_info.dart`:
  what KeyChat is, its features, that it was made by Haroon, and which model is currently running.
  The user's own system prompt is added after it, so editing it never removes this.
- **Streaming**: replies appear word by word (Server-Sent Events). The Send button turns into a
  **Stop** button while a reply is streaming.
- **Context**: the full conversation is sent with every request, so the bot remembers what was said.
- **Model picker**: the list comes live from `GET /models` (no model names are hardcoded). It has a
  search box, a *Free only* filter, context size and *Free* badges (OpenRouter), and remembers the last model for each provider.
- **Chat history**: a side drawer (menu button or swipe from the left) lists saved chats grouped
  by date: Today, Yesterday, Previous 7 days... Tap to open, tap the bin to delete. The title is
  the first user message.
- **Settings**: switch provider, change or delete the API key, edit the system prompt, choose
  light/dark/system theme, and clear all chats.
- **Mobile details**: portrait layout, safe areas (notch and gesture bar), input stays above the
  keyboard, tap outside or drag the list to hide the keyboard, auto-scroll to the newest message,
  a "jump to latest" button when scrolled up, long-press a message to copy it, and the chat is
  saved when the app goes to the background.

## Folder structure

```
lib/
├── main.dart                 # Creates services, loads saved data, starts the app
├── app.dart                  # MaterialApp, light/dark theme, first screen
├── theme/
│   └── app_theme.dart        # All colors, shapes and component styles in one place
├── models/                   # Plain data classes
│   ├── ai_provider.dart      # Provider list (Groq, OpenRouter): base URL, headers
│   ├── ai_model.dart         # A model from GET /models
│   ├── app_info.dart         # Facts about KeyChat + creator, sent to the AI with every chat
│   ├── chat_message.dart     # One message (role + content)
│   └── conversation.dart     # A saved chat (id, title, messages)
├── services/                 # Talking to the outside world (network + storage)
│   ├── llm_api_service.dart  # ONE service for all OpenAI-compatible APIs (+ SSE streaming)
│   ├── api_exception.dart    # Turns HTTP/network errors into friendly messages
│   ├── secure_key_storage.dart # API keys: Android Keystore / iOS Keychain
│   ├── settings_storage.dart # Small settings: shared_preferences
│   └── chat_storage.dart     # Conversations: Hive
├── providers/                # State management (Provider + ChangeNotifier)
│   ├── settings_provider.dart
│   └── chat_provider.dart    # Sending, streaming, stopping, saving chats
├── screens/
│   ├── setup_screen.dart     # Onboarding / change key
│   ├── chat_screen.dart
│   ├── model_picker_screen.dart
│   └── settings_screen.dart
└── widgets/
    ├── message_bubble.dart   # User bubble / AI reply (Markdown) / error card
    ├── code_block.dart       # Code block with language label + Copy button
    ├── edit_message_dialog.dart # Edit a sent message
    ├── history_drawer.dart   # Side drawer: saved chats grouped by date
    ├── keychat_logo.dart     # Gradient logo, also the AI's avatar
    ├── chat_input.dart       # Text field + Send/Stop button
    ├── typing_indicator.dart # Animated "..." while waiting
    └── empty_chat_view.dart  # Welcome screen + suggestions
```

## Design decisions (for the presentation)

| Decision | Why |
|---|---|
| **One API service, many providers** | Groq and OpenRouter both use the OpenAI `/chat/completions` format. Only the base URL and headers differ, so they live in `AiProvider`. To add another OpenAI-compatible provider (Together, Mistral, a local server...), you add **one entry** to `AiProvider.all`. |
| **Provider (package) for state** | Beginner-friendly: `ChangeNotifier` + `notifyListeners()`, read with `context.watch` / `context.read`. Two providers: settings and chat. |
| **flutter_secure_storage for keys** | Keys are encrypted with Android Keystore / stored in iOS Keychain. They are never printed or logged, never kept in app state (only a "has key" flag is), and read from secure storage right before each request. |
| **Hive for chats** | Chats can get long. Hive stores each conversation as its own entry, so saving one chat doesn't rewrite all of them (shared_preferences rewrites one big file). It is pure Dart, works the same on Android and iOS, and storing JSON strings means no code generation is needed. |
| **shared_preferences for settings** | Small key/value settings (theme, provider, last model, system prompt) are what it is designed for. |
| **Streaming with SSE** | `stream: true` makes the server send `data: {...}` lines. `LlmApiService.streamChat` is an `async*` generator that yields each text piece. "Stop" cancels the stream subscription, which closes the HTTP connection. |
| **flutter_markdown_plus** | The original `flutter_markdown` package was discontinued by the Flutter team. `flutter_markdown_plus` is the maintained fork with the same API. |
| **Reversed ListView** | The newest message sits at offset 0, so the chat stays pinned to the bottom while text streams in. |
| **Throttled streaming updates** | Fast models send 100+ tiny chunks per second. The text is added immediately, but the screen is redrawn at most every 50 ms (~20 fps), which looks just as smooth and saves battery. `RepaintBoundary` on each message means only the changing message is repainted. |
| **Identity prompt separate from system prompt** | Facts about the app and creator (`AppInfo`) are always sent; the editable system prompt only controls tone. It also tells the model which model it runs on, so it answers honestly ("KeyChat, powered by X") instead of claiming to be a different product. |
| **One theme file** | `AppTheme` sets colors and shapes for buttons, cards, inputs and dialogs once, so screens stay short and consistent. |
| **OpenRouter key check uses `/key`** | OpenRouter's `GET /models` is public and returns 200 even with a wrong key, so it can't validate keys. KeyChat uses `GET /key` for OpenRouter and `GET /models` for Groq (see `keyValidationPath`). The model picker still uses `GET /models` for both. |

## Get a free API key

**Groq** (fast, free tier):
1. Go to <https://console.groq.com/keys> and sign in.
2. Click **Create API Key**, copy it (it starts with `gsk_`).
3. In KeyChat choose **Groq**, tap the paste button, then **Test & Save**.

**OpenRouter** (many models, several free ones):
1. Go to <https://openrouter.ai/keys> and sign in.
2. Click **Create Key**, copy it (it starts with `sk-or-`).
3. In KeyChat choose **OpenRouter**, paste it, then **Test & Save**.
4. In the model picker, search for `free` to find models that cost nothing.

## Run and build for Android

> ⚠️ **Don't build from a folder path that contains a colon (`:`).** For example,
> `/run/media/<user>/Local Disk (D:)/...` will fail with
> `Could not find or load main class org.gradle.wrapper.GradleWrapperMain`, because Java uses `:` to
> separate classpath entries on Linux. Move or clone the project somewhere like `~/Projects/KeyChat`.

```bash
flutter pub get
flutter analyze
flutter test
flutter run                     # on a connected phone or emulator
flutter build apk --release     # → build/app/outputs/flutter-apk/app-release.apk
```

Smaller, per-CPU APKs: `flutter build apk --release --split-per-abi`.

Install on a phone: `adb install build/app/outputs/flutter-apk/app-release.apk`.

### Release signing (optional, needed for Play Store)

Without a keystore, release builds are signed with the debug key. That is fine for testing
and for sharing the APK with classmates. To sign with your own key:

```bash
keytool -genkey -v -keystore ~/keychat-release.jks -keyalg RSA -keysize 2048 \
        -validity 10000 -alias keychat
```

Then create `android/key.properties`. It is git-ignored, so never commit it:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=keychat
storeFile=/home/YOUR_USER/keychat-release.jks
```

`android/app/build.gradle.kts` uses this file automatically when it exists.

### Android configuration that's already done
- `INTERNET` permission in `AndroidManifest.xml` (release builds need it)
- App label **KeyChat**, `minSdk = 24` (required by flutter_secure_storage 11)
- `allowBackup="false"`, so encrypted keys aren't restored to a device that can't decrypt them
- Gradle memory lowered to 3 GB in `android/gradle.properties` so it builds on 8 GB RAM

## Build for iOS (on a Mac)

The iOS project is already configured: display name **KeyChat**, portrait only, and a minimum
iOS version of **15.0** in both the Xcode project and `ios/Podfile`. Every plugin used supports iOS 13+.

1. Install Xcode from the App Store, then run `sudo xcode-select --switch /Applications/Xcode.app`
   and `sudo xcodebuild -runFirstLaunch`.
2. Install CocoaPods: `brew install cocoapods` (or `sudo gem install cocoapods`).
3. Clone the project, then:
   ```bash
   flutter pub get
   cd ios && pod install && cd ..
   ```
4. Open `ios/Runner.xcworkspace` in Xcode → **Runner** target → **Signing & Capabilities** →
   pick your Team (a free Apple ID works for running on your own device). Change the bundle
   identifier if `com.haroon.keychat` is taken.
5. Run it:
   ```bash
   open -a Simulator && flutter run      # simulator
   flutter run --release                 # on a plugged-in iPhone (enable Developer Mode on the phone)
   flutter build ipa                     # archive for TestFlight / App Store (paid developer account)
   ```

No Info.plist permission entries are needed: the app only uses the network, the Keychain and the clipboard.

## App icon

Placeholder icons are in `assets/icon/`. To use your own:

1. Replace `assets/icon/app_icon.png` (1024×1024, no transparency; used for iOS and older Android).
2. Replace `assets/icon/app_icon_foreground.png` (1024×1024, transparent background, logo inside
   the middle ~66%; Android adaptive icon). Change `adaptive_icon_background` in `pubspec.yaml` if needed.
3. Run `dart run flutter_launcher_icons`.

## Tech stack

Flutter 3.47 · Dart 3.13 · Material 3 · provider · http · flutter_secure_storage · hive_ce ·
shared_preferences · flutter_markdown_plus · url_launcher · flutter_launcher_icons
