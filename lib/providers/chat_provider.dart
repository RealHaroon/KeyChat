import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ai_provider.dart';
import '../models/app_info.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/api_exception.dart';
import '../services/chat_storage.dart';
import '../services/llm_api_service.dart';
import '../services/secure_key_storage.dart';

/// Holds all conversations and runs the chat: sending messages, streaming the
/// reply, stopping, and saving to local storage.
class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required this._storage,
    required this._api,
    required this._keyStorage,
  });

  final ChatStorage _storage;
  final LlmApiService _api;
  final SecureKeyStorage _keyStorage;

  final Map<String, Conversation> _conversations = {};
  Conversation _current = Conversation.create();

  /// The subscription to the reply stream. Cancelling it stops generation.
  StreamSubscription<String>? _subscription;
  ChatMessage? _streamingMessage;

  /// Fast models send 100+ small chunks per second. Redrawing the screen for
  /// every chunk wastes battery, so streamed text is shown at most once per
  /// [_uiUpdateInterval] (still smooth: about 20 updates per second).
  static const _uiUpdateInterval = Duration(milliseconds: 50);
  Timer? _uiUpdateTimer;

  Conversation get current => _current;
  List<ChatMessage> get messages => _current.messages;
  bool get isGenerating => _subscription != null;

  /// The message currently receiving streamed text (null when idle).
  ChatMessage? get streamingMessage => _streamingMessage;

  /// Saved conversations, most recent first. Empty chats are not listed.
  List<Conversation> get conversations =>
      _conversations.values.where((c) => !c.isEmpty).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// Loads saved chats and reopens the one that was open last time.
  void load() {
    for (final c in _storage.loadAll()) {
      _conversations[c.id] = c;
    }
    final lastId = _storage.currentConversationId;
    if (lastId != null && _conversations.containsKey(lastId)) {
      _current = _conversations[lastId]!;
    }
    notifyListeners();
  }

  void newChat() {
    stopGenerating();
    _current = Conversation.create();
    _storage.setCurrentConversationId(null);
    notifyListeners();
  }

  void openConversation(String id) {
    final conversation = _conversations[id];
    if (conversation == null) return;
    stopGenerating();
    _current = conversation;
    _storage.setCurrentConversationId(id);
    notifyListeners();
  }

  /// Adds the user's message and streams the AI reply.
  Future<void> sendMessage(
    String text, {
    required AiProvider provider,
    required String model,
    required String systemPrompt,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isGenerating) return;

    _current.messages.add(ChatMessage.user(trimmed));
    _conversations[_current.id] = _current;
    await _storage.setCurrentConversationId(_current.id);
    await saveCurrent();
    notifyListeners();

    await _generateReply(
      provider: provider,
      model: model,
      systemPrompt: systemPrompt,
    );
  }

  /// Replaces a message the user already sent with [newText], deletes
  /// everything after it, and asks for a fresh reply (like "Edit" in ChatGPT).
  Future<void> editMessage(
    ChatMessage message,
    String newText, {
    required AiProvider provider,
    required String model,
    required String systemPrompt,
  }) async {
    final index = messages.indexOf(message);
    if (index == -1 || !message.isUser || newText.trim().isEmpty) return;

    stopGenerating();
    // Remove the old message and every message after it; sendMessage then
    // adds the edited text as a new message and streams the answer.
    messages.removeRange(index, messages.length);
    await sendMessage(
      newText,
      provider: provider,
      model: model,
      systemPrompt: systemPrompt,
    );
  }

  /// Asks for a new answer to the last user message. Used by "Retry" on
  /// errors and "Regenerate" on normal replies: the old reply is removed.
  Future<void> regenerate({
    required AiProvider provider,
    required String model,
    required String systemPrompt,
  }) async {
    if (isGenerating || messages.isEmpty || messages.last.isUser) return;
    messages.removeLast();
    notifyListeners();
    await _generateReply(
      provider: provider,
      model: model,
      systemPrompt: systemPrompt,
    );
  }

  Future<void> _generateReply({
    required AiProvider provider,
    required String model,
    required String systemPrompt,
  }) async {
    final apiKey = await _keyStorage.readKey(provider.id);
    if (apiKey == null || apiKey.isEmpty) {
      _addError('No API key saved for ${provider.name}. Add one in Settings.');
      return;
    }

    // Send the FULL history so the model remembers the conversation.
    // Error messages are only for the user, so they are left out.
    // The hidden instructions: who the AI is (always) + the user's own
    // system prompt (if any), sent as one system message.
    final instructions = [
      AppInfo.identityPrompt(provider: provider, model: model),
      if (systemPrompt.isNotEmpty)
        '## Instructions from the user\n$systemPrompt',
    ].join('\n');

    final history = <Map<String, String>>[
      {'role': MessageRole.system.name, 'content': instructions},
      for (final m in messages)
        if (!m.isError) m.toApiJson(),
    ];

    // An empty assistant message that streamed text is appended to.
    final reply = ChatMessage.assistant('');
    messages.add(reply);
    _streamingMessage = reply;

    final stream = _api.streamChat(
      provider: provider,
      apiKey: apiKey,
      model: model,
      messages: history,
    );

    _subscription = stream.listen(
      (chunk) {
        reply.content += chunk;
        _uiUpdateTimer ??= Timer(_uiUpdateInterval, () {
          _uiUpdateTimer = null;
          notifyListeners();
        });
      },
      onError: (Object error) {
        _finishGeneration();
        _addError(ApiException.from(error).message);
      },
      onDone: _finishGeneration,
      cancelOnError: true,
    );
    notifyListeners();
  }

  /// Called by the "Stop generating" button. Keeps the text received so far.
  void stopGenerating() {
    if (!isGenerating) return;
    _subscription?.cancel(); // Closes the HTTP connection.
    _finishGeneration();
  }

  void _finishGeneration() {
    final reply = _streamingMessage;
    // Drop the placeholder if nothing arrived (e.g. an error or instant stop).
    if (reply != null && reply.content.isEmpty) messages.remove(reply);
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = null;
    _subscription = null;
    _streamingMessage = null;
    saveCurrent();
    notifyListeners();
  }

  void _addError(String message) {
    messages.add(ChatMessage.error(message));
    saveCurrent();
    notifyListeners();
  }

  /// Saves the open chat. Also called when the app goes to the background,
  /// so a half-streamed reply is not lost if the OS closes the app.
  Future<void> saveCurrent() async {
    if (_current.isEmpty) return;
    _current.updatedAt = DateTime.now();
    await _storage.save(_current);
  }

  Future<void> deleteConversation(String id) async {
    if (id == _current.id) newChat();
    _conversations.remove(id);
    await _storage.delete(id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    newChat();
    _conversations.clear();
    await _storage.deleteAll();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _uiUpdateTimer?.cancel();
    super.dispose();
  }
}
