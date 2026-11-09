import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/ai_model.dart';
import 'package:keychat/models/ai_provider.dart';
import 'package:keychat/models/chat_message.dart';
import 'package:keychat/models/conversation.dart';
import 'package:keychat/services/api_exception.dart';
import 'package:keychat/services/llm_api_service.dart';

void main() {
  group('SSE stream parsing', () {
    test('extracts text from a delta chunk', () {
      const data = '{"choices":[{"delta":{"content":"Hello"}}]}';
      expect(LlmApiService.parseStreamChunk(data), 'Hello');
    });

    test('returns null for chunks without text', () {
      const data = '{"choices":[{"delta":{},"finish_reason":"stop"}]}';
      expect(LlmApiService.parseStreamChunk(data), isNull);
      expect(LlmApiService.parseStreamChunk('not json'), isNull);
    });

    test('throws on an error sent mid-stream', () {
      const data = '{"error":{"message":"Model overloaded"}}';
      expect(
        () => LlmApiService.parseStreamChunk(data),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('ApiException', () {
    test('maps status codes to friendly errors', () {
      expect(ApiException.fromResponse(401, '').type, ApiErrorType.invalidKey);
      expect(ApiException.fromResponse(429, '').type, ApiErrorType.rateLimit);
      expect(
        ApiException.fromResponse(500, '{"error":{"message":"boom"}}').message,
        contains('boom'),
      );
    });
  });

  group('Models', () {
    test('conversation survives a JSON round trip', () {
      final conversation = Conversation.create()
        ..messages.add(ChatMessage.user('Hi there'))
        ..messages.add(ChatMessage.assistant('**Hello!**'));

      final restored = Conversation.fromJson(conversation.toJson());

      expect(restored.id, conversation.id);
      expect(restored.title, 'Hi there');
      expect(restored.messages.length, 2);
      expect(restored.messages.last.role, MessageRole.assistant);
    });

    test('filters out non-chat models', () {
      expect(AiModel.isChatModel({'id': 'whisper-large-v3'}), isFalse);
      expect(AiModel.isChatModel({'id': 'llama-3.3-70b-versatile'}), isTrue);
    });

    test('detects free OpenRouter models', () {
      final model = AiModel.fromJson({
        'id': 'some/model:free',
        'name': 'Some Model',
        'context_length': 32000,
        'pricing': {'prompt': '0', 'completion': '0'},
      });
      expect(model.isFree, isTrue);
      expect(model.contextLength, 32000);
    });

    test('provider lookup falls back to the first provider', () {
      expect(AiProvider.byId('openrouter'), AiProvider.openRouter);
      expect(AiProvider.byId('unknown'), AiProvider.all.first);
    });
  });
}
