import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/conversation.dart';

/// Saves conversations on the device with Hive.
///
/// Why Hive instead of shared_preferences?
/// - Chats can grow large. Hive stores each conversation as its own entry,
///   so saving one chat does not rewrite all the others.
/// - It is a fast, pure-Dart database that works on Android and iOS with no
///   native setup.
/// - We store each conversation as a JSON string, so no code generation or
///   TypeAdapters are needed.
class ChatStorage {
  ChatStorage._(this._conversations, this._appState);

  final Box<String> _conversations;
  final Box<String> _appState;

  static const _currentIdKey = 'current_conversation_id';

  /// Opens the Hive boxes. Call once at app start.
  static Future<ChatStorage> create() async {
    await Hive.initFlutter();
    return _openBoxes();
  }

  /// Opens the boxes in a plain folder. Used by tests, which can't use the
  /// phone's app directory.
  @visibleForTesting
  static Future<ChatStorage> createAt(String directory) async {
    Hive.init(directory);
    return _openBoxes();
  }

  static Future<ChatStorage> _openBoxes() async {
    final conversations = await Hive.openBox<String>('conversations');
    final appState = await Hive.openBox<String>('app_state');
    return ChatStorage._(conversations, appState);
  }

  List<Conversation> loadAll() {
    final result = <Conversation>[];
    for (final json in _conversations.values) {
      try {
        result.add(Conversation.fromJson(jsonDecode(json)));
      } catch (_) {
        // Skip a corrupted entry instead of crashing the whole app.
      }
    }
    return result;
  }

  Future<void> save(Conversation conversation) =>
      _conversations.put(conversation.id, jsonEncode(conversation.toJson()));

  Future<void> delete(String id) => _conversations.delete(id);

  Future<void> deleteAll() => _conversations.clear();

  /// Remembers which chat was open, so it reopens after the app restarts.
  String? get currentConversationId => _appState.get(_currentIdKey);

  Future<void> setCurrentConversationId(String? id) => id == null
      ? _appState.delete(_currentIdKey)
      : _appState.put(_currentIdKey, id);
}
