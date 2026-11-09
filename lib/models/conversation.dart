import 'chat_message.dart';

/// A saved chat: a title plus its list of messages.
class Conversation {
  Conversation({
    required this.id,
    required this.messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Creates an empty conversation with a unique, time-based id.
  factory Conversation.create() => Conversation(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    messages: [],
  );

  final String id;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;

  /// The title is the first user message, shortened to one line.
  String get title {
    final firstUser = messages.where((m) => m.isUser).firstOrNull;
    if (firstUser == null) return 'New chat';
    final oneLine = firstUser.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return oneLine.length <= 60 ? oneLine : '${oneLine.substring(0, 60)}…';
  }

  bool get isEmpty => messages.isEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    messages: (json['messages'] as List)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList(),
  );
}
