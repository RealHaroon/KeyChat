/// One model returned by a provider's `GET /models` endpoint.
class AiModel {
  const AiModel({
    required this.id,
    required this.name,
    this.contextLength,
    this.isFree = false,
  });

  /// The value sent as `model` in chat requests, e.g. "llama-3.3-70b-versatile".
  final String id;

  /// Display name (OpenRouter provides one; Groq does not, so we use the id).
  final String name;

  /// Maximum context window in tokens, when the provider reports it.
  final int? contextLength;

  /// True when OpenRouter reports a price of 0 for this model.
  final bool isFree;

  /// Parses one entry of the `data` array. Groq and OpenRouter use slightly
  /// different field names, so both are handled here.
  factory AiModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final pricing = json['pricing'];
    final isFree =
        pricing is Map &&
        pricing['prompt']?.toString() == '0' &&
        pricing['completion']?.toString() == '0';

    return AiModel(
      id: id,
      name: (json['name'] as String?) ?? id,
      contextLength: (json['context_length'] ?? json['context_window']) as int?,
      isFree: isFree,
    );
  }

  /// Returns false for models that cannot chat (speech-to-text, text-to-speech,
  /// image-only, ...), so they don't clutter the model picker.
  static bool isChatModel(Map<String, dynamic> json) {
    // OpenRouter describes what a model outputs.
    final architecture = json['architecture'];
    if (architecture is Map && architecture['output_modalities'] is List) {
      return (architecture['output_modalities'] as List).contains('text');
    }
    // Groq has no such field, so filter its audio models by id.
    final id = (json['id'] as String? ?? '').toLowerCase();
    const audioKeywords = ['whisper', 'tts', 'orpheus', 'playai'];
    return !audioKeywords.any(id.contains);
  }
}
