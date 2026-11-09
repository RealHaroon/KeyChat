import 'package:flutter/material.dart';

/// Shown when the chat has no messages yet.
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
    'Explain how the internet works in simple terms',
    'Write a Dart function that reverses a string',
    'Give me 5 ideas for a weekend project',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: colors.primaryContainer,
              child: Icon(
                Icons.forum_rounded,
                size: 36,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text('How can I help?', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            if (!hasModel) ...[
              Text(
                'Choose a model to start chatting.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onPickModel,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Choose a model'),
              ),
            ] else
              for (final suggestion in _suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ActionChip(
                    label: Text(suggestion, textAlign: TextAlign.center),
                    onPressed: () => onSuggestion(suggestion),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
