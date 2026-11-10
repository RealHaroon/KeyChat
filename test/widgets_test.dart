import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/chat_message.dart';
import 'package:keychat/theme/app_theme.dart';
import 'package:keychat/widgets/chat_input.dart';
import 'package:keychat/widgets/empty_chat_view.dart';
import 'package:keychat/widgets/message_bubble.dart';

/// Wraps a widget in a themed app so it can be rendered in a test.
Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

/// A typical phone screen (portrait, 412 x 915 logical pixels).
void _usePhoneScreen(WidgetTester tester, {double width = 412}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 915);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('AI reply renders code blocks with language and Copy button', (
    tester,
  ) async {
    final message = ChatMessage.assistant(
      'Here you go:\n\n```dart\nvoid main() {}\n```',
    );
    await tester.pumpWidget(
      _wrap(MessageBubble(message: message, onRegenerate: () {})),
    );

    expect(find.text('dart'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('void main() {}'), findsOneWidget);
    expect(find.byTooltip('Regenerate'), findsOneWidget);
  });

  testWidgets('Streaming reply hides the action buttons', (tester) async {
    final message = ChatMessage.assistant('Partial answer');
    await tester.pumpWidget(
      _wrap(MessageBubble(message: message, isStreaming: true)),
    );

    expect(find.byTooltip('Copy'), findsNothing);
  });

  testWidgets('Error message shows Retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        MessageBubble(
          message: ChatMessage.error('Invalid API key'),
          onRegenerate: () => retried = true,
        ),
      ),
    );

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('Tapping a suggestion sends its full prompt', (tester) async {
    _usePhoneScreen(tester);
    String? sent;
    await tester.pumpWidget(
      _wrap(
        EmptyChatView(
          hasModel: true,
          onPickModel: () {},
          onSuggestion: (text) => sent = text,
        ),
      ),
    );

    await tester.tap(find.text('Brainstorm'));
    expect(sent, 'Brainstorm 5 ideas for a weekend project');
  });

  testWidgets('Send button is enabled only when there is text', (tester) async {
    String? sent;
    await tester.pumpWidget(
      _wrap(
        ChatInput(
          isGenerating: false,
          onSend: (text) => sent = text,
          onStop: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Send'));
    expect(sent, isNull);

    await tester.enterText(find.byType(TextField), '  Hello  ');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    expect(sent, 'Hello');
  });

  testWidgets('Empty chat fits a small phone with large text', (tester) async {
    _usePhoneScreen(tester, width: 320);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 915),
          textScaler: TextScaler.linear(1.3),
        ),
        child: _wrap(
          EmptyChatView(
            hasModel: true,
            onPickModel: () {},
            onSuggestion: (_) {},
          ),
        ),
      ),
    );
    // A layout overflow would be reported as an exception.
    expect(tester.takeException(), isNull);
  });
}
