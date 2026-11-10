import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Tells the Markdown renderer to draw ``` code blocks with [CodeBlock].
class CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // A code block is <pre><code class="language-dart">...</code></pre>.
    final codeElement = element.children?.firstOrNull;
    final cssClass = codeElement is md.Element
        ? codeElement.attributes['class']
        : null;
    final language = cssClass?.replaceFirst('language-', '');
    return CodeBlock(code: element.textContent.trimRight(), language: language);
  }
}

/// A code block with a header showing the language and a Copy button.
/// Long lines scroll sideways instead of wrapping, like a code editor.
class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.code, this.language});

  final String code;
  final String? language;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Code copied'),
          duration: Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: colors.surfaceContainerHighest,
          padding: const EdgeInsets.only(left: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  language?.isNotEmpty == true ? language! : 'code',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(14),
          child: Text(
            code,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              height: 1.45,
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
