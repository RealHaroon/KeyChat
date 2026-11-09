/// An LLM provider that speaks the OpenAI-compatible API
/// (`GET /models` and `POST /chat/completions`).
///
/// Because every provider uses the same API format, the app only needs ONE
/// API service. To support a new provider, add one entry to [AiProvider.all].
class AiProvider {
  const AiProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.description,
    required this.apiKeyUrl,
    this.keyHint = '',
    this.keyValidationPath = '/models',
    this.extraHeaders = const {},
  });

  /// Stable identifier, used as a storage key (e.g. "groq").
  final String id;

  /// Human-readable name shown in the UI.
  final String name;

  /// Base URL of the OpenAI-compatible API, without a trailing slash.
  final String baseUrl;

  /// Short description shown on the setup screen.
  final String description;

  /// Web page where the user can create an API key.
  final String apiKeyUrl;

  /// Example prefix of a key, shown as a hint in the text field.
  final String keyHint;

  /// Endpoint used by "Test & Save" to check that a key is valid.
  final String keyValidationPath;

  /// Extra HTTP headers sent with every request to this provider.
  final Map<String, String> extraHeaders;

  static const groq = AiProvider(
    id: 'groq',
    name: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    description: 'Very fast inference of open models. Free tier available.',
    apiKeyUrl: 'https://console.groq.com/keys',
    keyHint: 'gsk_...',
  );

  static const openRouter = AiProvider(
    id: 'openrouter',
    name: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    description: 'Hundreds of models from many labs, including free ones.',
    apiKeyUrl: 'https://openrouter.ai/keys',
    keyHint: 'sk-or-...',
    // OpenRouter's /models list is public (it works without a key), so we
    // validate keys with /key, which returns 401 for an invalid key.
    keyValidationPath: '/key',
    // Optional headers that identify the app on openrouter.ai.
    extraHeaders: {
      'HTTP-Referer': 'https://github.com/RealHaroon/KeyChat',
      'X-Title': 'KeyChat',
    },
  );

  /// Every provider the app supports. Add new OpenAI-compatible ones here.
  static const List<AiProvider> all = [groq, openRouter];

  /// Finds a provider by [id], falling back to the first one.
  static AiProvider byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);
}
