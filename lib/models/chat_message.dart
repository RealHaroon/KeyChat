/// Who wrote a message. The names match the roles used by the API.
enum MessageRole { system, user, assistant }

/// A single chat message.
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.isError = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  ChatMessage.user(String content)
    : this(role: MessageRole.user, content: content);

  ChatMessage.assistant(String content)
    : this(role: MessageRole.assistant, content: content);

  /// An error shown in the chat (e.g. "Invalid API key"). It is never sent
  /// to the API as part of the conversation history.
  ChatMessage.error(String content)
    : this(role: MessageRole.assistant, content: content, isError: true);

  final MessageRole role;

  /// Not final: while a reply is streaming, new text is appended to it.
  String content;

  final bool isError;
  final DateTime createdAt;

  bool get isUser => role == MessageRole.user;

  /// The shape the OpenAI-compatible API expects: {"role": ..., "content": ...}.
  Map<String, String> toApiJson() => {'role': role.name, 'content': content};

  /// Used for saving to local storage.
  Map<String, dynamic> toJson() => {
    'role': role.name,
    'content': content,
    'isError': isError,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: MessageRole.values.byName(json['role'] as String),
    content: json['content'] as String,
    isError: json['isError'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}
