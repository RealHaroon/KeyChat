import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/ai_provider.dart';
import 'package:keychat/providers/chat_provider.dart';
import 'package:keychat/providers/settings_provider.dart';
import 'package:keychat/services/chat_storage.dart';
import 'package:keychat/services/llm_api_service.dart';
import 'package:keychat/services/secure_key_storage.dart';
import 'package:keychat/services/settings_storage.dart';
import 'package:keychat/theme/app_theme.dart';
import 'package:keychat/widgets/message_bubble.dart';
import 'package:keychat/models/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake API: no network. Remembers what was sent and replies "Reply N".
class FakeApi extends LlmApiService {
  final sentRequests = <List<Map<String, String>>>[];

  @override
  Stream<String> streamChat({
    required AiProvider provider,
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
  }) {
    sentRequests.add(messages);
    return Stream.fromIterable(['Reply ', '${sentRequests.length}']);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeApi api;
  late ChatProvider chat;
  final groq = AiProvider.byId('groq');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('keychat_test');
    FlutterSecureStorage.setMockInitialValues({'api_key_groq': 'test-key'});
    api = FakeApi();
    chat = ChatProvider(
      storage: await ChatStorage.createAt(tempDir.path),
      api: api,
      keyStorage: SecureKeyStorage(),
    );
  });

  tearDown(() async {
    chat.dispose();
    await tempDir.delete(recursive: true);
  });

  /// Waits until the fake reply has finished streaming.
  Future<void> waitForReply() async {
    while (chat.isGenerating) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> send(String text) async {
    await chat.sendMessage(
      text,
      provider: groq,
      model: 'llama-test',
      systemPrompt: 'Talk like a pirate.',
    );
    await waitForReply();
  }

  test('Every request starts with KeyChat identity + user prompt', () async {
    await send('Who made you?');

    final system = api.sentRequests.single.first;
    expect(system['role'], 'system');
    expect(system['content'], contains('made by Haroon'));
    expect(system['content'], contains('"llama-test" through Groq'));
    expect(system['content'], contains('Talk like a pirate.'));
  });

  test('Editing a message replaces it and everything after it', () async {
    await send('First question');
    await send('Second question');
    expect(chat.messages.map((m) => m.content), [
      'First question',
      'Reply 1',
      'Second question',
      'Reply 2',
    ]);

    await chat.editMessage(
      chat.messages.first,
      'Better first question',
      provider: groq,
      model: 'llama-test',
      systemPrompt: '',
    );
    await waitForReply();

    expect(chat.messages.map((m) => m.content), [
      'Better first question',
      'Reply 3',
    ]);
    // The new request must not contain the deleted messages.
    final sentTexts = api.sentRequests.last.map((m) => m['content']);
    expect(sentTexts, isNot(contains('Second question')));
  });

  test('Old default system prompts are upgraded to the new default', () async {
    SharedPreferences.setMockInitialValues({
      'system_prompt':
          'You are KeyChat, a helpful and friendly AI assistant. '
          'Answer clearly and use Markdown (lists, bold, code blocks) when it helps.',
    });
    final settings = SettingsProvider(
      storage: await SettingsStorage.create(),
      keyStorage: SecureKeyStorage(),
    );
    await settings.load();
    expect(settings.systemPrompt, SettingsProvider.defaultSystemPrompt);
  });

  testWidgets('Long-pressing a user message offers Edit', (tester) async {
    var edited = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MessageBubble(
            message: ChatMessage.user('Hello'),
            onEdit: () => edited = true,
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Hello'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit message'));
    await tester.pumpAndSettle();
    expect(edited, isTrue);
  });
}
