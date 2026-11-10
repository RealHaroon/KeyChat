import 'package:flutter/material.dart';

/// Lets the user change a message they already sent.
/// Returns the new text, or null if they cancel.
class EditMessageDialog extends StatefulWidget {
  const EditMessageDialog({super.key, required this.initialText});

  final String initialText;

  /// Shows the dialog and returns the edited text (null if cancelled).
  static Future<String?> show(BuildContext context, String initialText) {
    return showDialog<String>(
      context: context,
      builder: (_) => EditMessageDialog(initialText: initialText),
    );
  }

  @override
  State<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<EditMessageDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Edit message'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          Text(
            'The reply to this message (and anything after it) will be '
            'replaced with a new answer.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        // Rebuilds only the button, so it is disabled while the box is empty.
        ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, value.text.trim()),
            child: const Text('Send'),
          ),
        ),
      ],
    );
  }
}
