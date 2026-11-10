import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import 'code_block.dart';
import 'keychat_logo.dart';
import 'typing_indicator.dart';

/// One chat message.
///
/// - User messages: a colored bubble on the right.
/// - AI replies: full width with a small logo, rendered as Markdown, with
///   Copy / Regenerate buttons underneath (like ChatGPT or Gemini).
/// - Errors: a red card with a Retry button.
///
/// Long-press any message to copy it.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.onRegenerate,
  });

  final ChatMessage message;

  /// True while this reply is still arriving.
  final bool isStreaming;

  /// Only set on the last reply: shows "Regenerate" (or "Retry" on errors).
  final VoidCallback? onRegenerate;

  /// Shared between all bubbles; creating it once avoids extra work.
  static final _markdownBuilders = {'pre': CodeBlockBuilder()};

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
    // RepaintBoundary: when one message changes (streaming), the others
    // don't have to be repainted.
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: message.isUser
            ? _buildUserBubble(context)
            : message.isError
            ? _buildError(context)
            : _buildAssistant(context),
      ),
    );
  }

  Widget _buildUserBubble(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const radius = BorderRadius.only(
      topLeft: Radius.circular(22),
      topRight: Radius.circular(22),
      bottomLeft: Radius.circular(22),
      bottomRight: Radius.circular(6),
    );

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        // At most ~80% of the screen width on any phone size.
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Material(
          color: colors.primaryContainer,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onLongPress: () => _copy(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Text(
                message.content,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssistant(BuildContext context) {
    final showActions = !isStreaming && message.content.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: KeyChatLogo(size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onLongPress: () => _copy(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isStreaming && message.content.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: TypingIndicator(),
                  )
                else
                  MarkdownBody(
                    data: message.content,
                    styleSheet: _markdownStyle(context),
                    builders: _markdownBuilders,
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        launchUrl(
                          Uri.parse(href),
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
                if (showActions) _buildActions(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          _ActionIcon(
            icon: Icons.copy_rounded,
            tooltip: 'Copy',
            color: color,
            onPressed: () => _copy(context),
          ),
          if (onRegenerate != null)
            _ActionIcon(
              icon: Icons.refresh_rounded,
              tooltip: 'Regenerate',
              color: color,
              onPressed: onRegenerate!,
            ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, color: colors.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (onRegenerate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRegenerate,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onErrorContainer,
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.5);

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: body,
      listBullet: body,
      h1: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      h3: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      blockSpacing: 12,
      a: TextStyle(color: colors.primary, decoration: TextDecoration.underline),
      // Inline `code`.
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        color: colors.tertiary,
        backgroundColor: colors.surfaceContainerHigh,
      ),
      // ``` code blocks are drawn by CodeBlock; this is the frame around it.
      codeblockDecoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      blockquoteDecoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(left: BorderSide(color: colors.primary, width: 3)),
      ),
      tableBorder: TableBorder.all(color: colors.outlineVariant),
      tableCellsPadding: const EdgeInsets.all(8),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}
