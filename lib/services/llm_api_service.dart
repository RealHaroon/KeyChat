import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_model.dart';
import '../models/ai_provider.dart';
import 'api_exception.dart';

/// Talks to any OpenAI-compatible API (Groq, OpenRouter, ...).
///
/// Only the provider's base URL and extra headers change between providers,
/// so one class handles all of them.
class LlmApiService {
  static const _timeout = Duration(seconds: 30);

  /// Headers sent with every request. The key goes ONLY into this header;
  /// it is never logged or printed.
  Map<String, String> _headers(AiProvider provider, String apiKey) => {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
    ...provider.extraHeaders,
  };

  Uri _url(AiProvider provider, String path) =>
      Uri.parse('${provider.baseUrl}$path');

  /// Checks that [apiKey] works. Throws an [ApiException] if it doesn't.
  Future<void> validateKey(AiProvider provider, String apiKey) async {
    await _get(provider, apiKey, provider.keyValidationPath);
  }

  /// Fetches the list of chat models from `GET /models`, sorted by name.
  Future<List<AiModel>> fetchModels(AiProvider provider, String apiKey) async {
    final body = await _get(provider, apiKey, '/models');
    final data = (jsonDecode(body) as Map<String, dynamic>)['data'] as List;

    final models =
        data
            .cast<Map<String, dynamic>>()
            .where(AiModel.isChatModel)
            .map(AiModel.fromJson)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return models;
  }

  Future<String> _get(AiProvider provider, String apiKey, String path) async {
    try {
      final response = await http
          .get(_url(provider, path), headers: _headers(provider, apiKey))
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw ApiException.fromResponse(response.statusCode, response.body);
      }
      return response.body;
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Sends the conversation to `POST /chat/completions` with `stream: true`
  /// and yields the reply piece by piece as it arrives.
  ///
  /// The server answers with Server-Sent Events (SSE), one per line:
  ///   data: {"choices":[{"delta":{"content":"Hel"}}]}
  ///   data: {"choices":[{"delta":{"content":"lo!"}}]}
  ///   data: [DONE]
  ///
  /// Cancelling the stream subscription ("Stop generating") runs the
  /// `finally` block, which closes the HTTP connection.
  Stream<String> streamChat({
    required AiProvider provider,
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
  }) async* {
    final client = http.Client();
    try {
      final request = http.Request('POST', _url(provider, '/chat/completions'))
        ..headers.addAll(_headers(provider, apiKey))
        ..body = jsonEncode({
          'model': model,
          'messages': messages,
          'stream': true,
        });

      final response = await client.send(request).timeout(_timeout);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw ApiException.fromResponse(response.statusCode, body);
      }

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        // Skip empty lines and SSE comments such as ": OPENROUTER PROCESSING".
        if (!line.startsWith('data:')) continue;

        final data = line.substring(5).trim();
        if (data == '[DONE]') break;

        final text = parseStreamChunk(data);
        if (text != null && text.isNotEmpty) yield text;
      }
    } catch (e) {
      throw ApiException.from(e);
    } finally {
      client.close();
    }
  }

  /// Extracts the new text from one SSE `data:` payload.
  ///
  /// Returns null when the chunk has no text (e.g. the final chunk with only
  /// a `finish_reason`). Throws if the server sent an error mid-stream.
  @visibleForTesting
  static String? parseStreamChunk(String data) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(data) as Map<String, dynamic>;
    } on FormatException {
      return null; // Ignore malformed chunks instead of crashing.
    }

    if (json['error'] is Map) {
      throw ApiException(
        ApiErrorType.server,
        json['error']['message']?.toString() ?? 'The model returned an error.',
      );
    }

    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final delta = (choices.first as Map)['delta'];
    if (delta is! Map) return null;
    return delta['content'] as String?;
  }
}
