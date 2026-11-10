import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'keychat_logo.dart';

/// Shown when the chat has no messages yet: a greeting and suggestion cards.
/// If no model is selected, it asks the user to pick one first.
class EmptyChatView extends StatelessWidget {
  const EmptyChatView({
    super.key,
    required this.hasModel,
    required this.onPickModel,
    required this.onSuggestion,
  });

  final bool hasModel;
  final VoidCallback onPickModel;
  final ValueChanged<String> onSuggestion;

  static const _suggestions = [
    (
      Icons.lightbulb_outline_rounded,
      'Explain',
      'how the internet works in simple terms',
    ),
    (Icons.code_rounded, 'Write', 'a Dart function that reverses a string'),
    (
      Icons.edit_note_rounded,
      'Help me write',
      'a short email asking for a deadline extension',
    ),
    (Icons.explore_outlined, 'Brainstorm', '5 ideas for a weekend project'),
  ];

  Widget _buildCard((IconData, String, String) suggestion) {
    final (icon, title, detail) = suggestion;
    return _SuggestionCard(
      icon: icon,
      title: title,
      detail: detail,
      onTap: () => onSuggestion('$title $detail'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const Center(child: KeyChatLogo(size: 64)),
        const SizedBox(height: 24),
        // Gradient-colored greeting text.
        ShaderMask(
          shaderCallback: AppTheme.brandGradient.createShader,
          child: Text(
            'Hello there',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'How can I help you today?',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        if (!hasModel)
          Center(
            child: FilledButton.icon(
              onPressed: onPickModel,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Choose a model to start'),
            ),
          )
        else
          // Two columns of suggestion cards. Each row is as tall as its
          // tallest card, so text never gets cut off (even with large fonts).
          for (var i = 0; i < _suggestions.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildCard(_suggestions[i])),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCard(_suggestions[i + 1])),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
