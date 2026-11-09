import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// The kinds of failure we show different messages for.
enum ApiErrorType { invalidKey, rateLimit, noCredits, network, timeout, server }

/// An error from the LLM API, with a message that is safe to show the user.
///
/// It never contains the API key.
class ApiException implements Exception {
  const ApiException(this.type, this.message);

  final ApiErrorType type;
  final String message;

  /// Builds a friendly error from an HTTP status code and response body.
  factory ApiException.fromResponse(int statusCode, String body) {
    final serverMessage = _extractMessage(body);
    switch (statusCode) {
      case 401:
      case 403:
        return const ApiException(
          ApiErrorType.invalidKey,
          'Invalid API key. Check that you copied the whole key.',
        );
      case 402:
        return const ApiException(
          ApiErrorType.noCredits,
          'Your account has no credits left for this model. '
          'Try a free model or add credits.',
        );
      case 429:
        return const ApiException(
          ApiErrorType.rateLimit,
          'Rate limit reached. Please wait a moment and try again.',
        );
      default:
        return ApiException(
          ApiErrorType.server,
          serverMessage != null
              ? 'Server error ($statusCode): $serverMessage'
              : 'Server error ($statusCode). Please try again.',
        );
    }
  }

  /// Converts low-level errors (no internet, timeouts...) into an [ApiException].
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is TimeoutException) {
      return const ApiException(
        ApiErrorType.timeout,
        'The request timed out. Check your connection and try again.',
      );
    }
    if (error is SocketException ||
        error is HandshakeException ||
        error is http.ClientException) {
      return const ApiException(
        ApiErrorType.network,
        'No internet connection. Check your network and try again.',
      );
    }
    return const ApiException(
      ApiErrorType.server,
      'Something went wrong. Please try again.',
    );
  }

  /// OpenAI-compatible APIs return errors as {"error": {"message": "..."}}.
  static String? _extractMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] is Map) {
        return json['error']['message']?.toString();
      }
    } on FormatException {
      // Body was not JSON; fall through.
    }
    return null;
  }

  @override
  String toString() => message;
}
