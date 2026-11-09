import 'package:flutter/material.dart';

/// The text box and Send / Stop button at the bottom of the chat.
class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.onSend,
    required this.onStop,
    required this.isGenerating,
    this.enabled = true,
    this.hintText = 'Message',
  });

  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final bool isGenerating;
  final bool enabled;
  final String hintText;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // SafeArea keeps the input above the iPhone home indicator and the
    // Android gesture bar. Scaffold moves it above the keyboard.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // While a reply streams, the Send button becomes a Stop button.
            widget.isGenerating
                ? IconButton.filledTonal(
                    tooltip: 'Stop generating',
                    onPressed: widget.onStop,
                    icon: const Icon(Icons.stop_rounded),
                    iconSize: 28,
                  )
                : IconButton.filled(
                    tooltip: 'Send',
                    onPressed: widget.enabled && _hasText ? _send : null,
                    icon: const Icon(Icons.arrow_upward_rounded),
                    iconSize: 28,
                    style: IconButton.styleFrom(
                      disabledBackgroundColor: colors.surfaceContainerHighest,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
