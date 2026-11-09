import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/chat_input.dart';
import '../widgets/empty_chat_view.dart';
import '../widgets/message_bubble.dart';
import 'history_screen.dart';
import 'model_picker_screen.dart';
import 'settings_screen.dart';

/// The main screen: message list + input box.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// [WidgetsBindingObserver] tells us when the app goes to the background,
/// so we can save the current chat before the OS might close the app.
class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      context.read<ChatProvider>().saveCurrent();
    }
  }

  void _send(String text) {
    final settings = context.read<SettingsProvider>();
    final model = settings.selectedModel;
    if (model == null) {
      _openModelPicker();
      return;
    }
    context.read<ChatProvider>().sendMessage(
      text,
      provider: settings.provider,
      model: model,
      systemPrompt: settings.systemPrompt,
    );
    _scrollToBottom();
  }

  void _retry() {
    final settings = context.read<SettingsProvider>();
    final model = settings.selectedModel;
    if (model == null) return;
    context.read<ChatProvider>().retry(
      provider: settings.provider,
      model: model,
      systemPrompt: settings.systemPrompt,
    );
  }

  /// The list is reversed (newest message at offset 0), so "bottom" is 0.
  /// Reversed lists also stay pinned to the newest message as text streams in.
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _openModelPicker() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ModelPickerScreen()));
  }

  void _openHistory() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final settings = context.watch<SettingsProvider>();
    final messages = chat.messages;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        leading: IconButton(
          tooltip: 'Chat history',
          icon: const Icon(Icons.menu_rounded),
          onPressed: _openHistory,
        ),
        title: _ModelTitle(
          providerName: settings.provider.name,
          model: settings.selectedModel,
          onTap: _openModelPicker,
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.edit_square),
            onPressed: messages.isEmpty ? null : chat.newChat,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      // Scaffold resizes the body when the keyboard opens, which keeps the
      // input box visible above it (resizeToAvoidBottomInset is true by default).
      body: GestureDetector(
        // Tap anywhere outside the text box to hide the keyboard.
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? EmptyChatView(
                      hasModel: settings.selectedModel != null,
                      onPickModel: _openModelPicker,
                      onSuggestion: _send,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        // Reversed list: index 0 is the newest message.
                        final message = messages[messages.length - 1 - index];
                        final isLast = index == 0;
                        return MessageBubble(
                          key: ObjectKey(message),
                          message: message,
                          isStreaming: chat.streamingMessage == message,
                          onRetry: isLast && message.isError ? _retry : null,
                        );
                      },
                    ),
            ),
            ChatInput(
              isGenerating: chat.isGenerating,
              enabled: settings.selectedModel != null,
              hintText: settings.selectedModel == null
                  ? 'Choose a model first'
                  : 'Message',
              onSend: _send,
              onStop: chat.stopGenerating,
            ),
          ],
        ),
      ),
    );
  }
}

/// AppBar title showing the provider and model. Tap to change the model.
class _ModelTitle extends StatelessWidget {
  const _ModelTitle({
    required this.providerName,
    required this.model,
    required this.onTap,
  });

  final String providerName;
  final String? model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('KeyChat', style: theme.textTheme.titleMedium),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    model == null ? 'Choose a model' : '$providerName · $model',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
