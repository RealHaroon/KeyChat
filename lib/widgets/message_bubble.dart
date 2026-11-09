import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import 'typing_indicator.dart';

/// One chat bubble: user messages on the right, AI replies on the left.
/// AI replies are rendered as Markdown. Long-press copies the text.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.onRetry,
  });

  final ChatMessage message;

  /// True while this reply is still arriving.
  final bool isStreaming;

  /// Shown as a "Retry" button on error messages.
  final VoidCallback? onRetry;

  void _copy(BuildContext context) {
    if (message.content.isEmpty) return;
    Clipboard.setData(ClipboardData(text: message.content));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Message copied'),
          duration: Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    final Color background;
    final Color foreground;
    if (message.isError) {
      background = colors.errorContainer;
      foreground = colors.onErrorContainer;
    } else if (isUser) {
      background = colors.primary;
      foreground = colors.onPrimary;
    } else {
      background = colors.surfaceContainerHigh;
      foreground = colors.onSurface;
    }

    // A "tail" corner points toward the sender's side.
    const radius = Radius.circular(20);
    final borderRadius = BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      bottomLeft: isUser ? radius : const Radius.circular(4),
      bottomRight: isUser ? const Radius.circular(4) : radius,
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        // Bubbles use at most ~85% of the screen width on any phone size.
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: background,
            borderRadius: borderRadius,
            child: InkWell(
              borderRadius: borderRadius,
              onLongPress: () => _copy(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: _buildContent(context, foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color foreground) {
    final textTheme = Theme.of(context).textTheme;

    if (isStreaming && message.content.isEmpty) {
      return const TypingIndicator();
    }

    if (message.isError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 20, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.content,
                  style: textTheme.bodyMedium?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
          if (onRetry != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
        ],
      );
    }

    if (message.isUser) {
      return Text(
        message.content,
        style: textTheme.bodyLarge?.copyWith(color: foreground),
      );
    }

    return MarkdownBody(
      data: message.content,
      styleSheet: _markdownStyle(context, foreground),
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context, Color foreground) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyLarge?.copyWith(color: foreground),
      listBullet: theme.textTheme.bodyLarge?.copyWith(color: foreground),
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        color: colors.onSurface,
        backgroundColor: colors.surfaceContainerHighest,
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      blockquoteDecoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        border: Border(left: BorderSide(color: colors.primary, width: 3)),
      ),
    );
  }
}
