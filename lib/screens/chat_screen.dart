import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/chat_input.dart';
import '../widgets/empty_chat_view.dart';
import '../widgets/history_drawer.dart';
import '../widgets/message_bubble.dart';
import 'model_picker_screen.dart';
import 'settings_screen.dart';

/// The main screen: message list + input box, with chat history in a drawer.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// [WidgetsBindingObserver] tells us when the app goes to the background,
/// so we can save the current chat before the OS might close the app.
class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _scrollController = ScrollController();

  /// Whether to show the "jump to latest" button. A ValueNotifier means only
  /// that button rebuilds while scrolling, not the whole screen.
  final _showScrollButton = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(() {
      // Reversed list: offset 0 is the newest message.
      _showScrollButton.value = _scrollController.offset > 400;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _showScrollButton.dispose();
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

  void _regenerate() {
    final settings = context.read<SettingsProvider>();
    final model = settings.selectedModel;
    if (model == null) return;
    context.read<ChatProvider>().regenerate(
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
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _openModelPicker() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ModelPickerScreen()));
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
    final hasModel = settings.selectedModel != null;

    return Scaffold(
      drawer: HistoryDrawer(onOpenSettings: _openSettings),
      appBar: AppBar(
        titleSpacing: 0,
        // The default leading button opens the drawer.
        title: _ModelPill(
          providerName: settings.provider.name,
          model: settings.selectedModel,
          onTap: _openModelPicker,
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: messages.isEmpty ? null : chat.newChat,
          ),
          const SizedBox(width: 4),
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
                      hasModel: hasModel,
                      onPickModel: _openModelPicker,
                      onSuggestion: _send,
                    )
                  : Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            // Reversed list: index 0 is the newest message.
                            final message =
                                messages[messages.length - 1 - index];
                            final canRegenerate =
                                index == 0 &&
                                !message.isUser &&
                                !chat.isGenerating;
                            return MessageBubble(
                              key: ObjectKey(message),
                              message: message,
                              isStreaming: chat.streamingMessage == message,
                              onRegenerate: canRegenerate ? _regenerate : null,
                            );
                          },
                        ),
                        Positioned(
                          right: 0,
                          left: 0,
                          bottom: 8,
                          child: Center(
                            child: ValueListenableBuilder(
                              valueListenable: _showScrollButton,
                              builder: (context, show, _) => AnimatedScale(
                                scale: show ? 1 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: IconButton.filledTonal(
                                  tooltip: 'Jump to latest',
                                  onPressed: _scrollToBottom,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            ChatInput(
              isGenerating: chat.isGenerating,
              enabled: hasModel,
              hintText: hasModel ? 'Message KeyChat' : 'Choose a model first',
              onSend: _send,
              onStop: chat.stopGenerating,
            ),
          ],
        ),
      ),
    );
  }
}

/// A rounded "pill" in the AppBar showing the current model.
/// Tap it to choose a different model.
class _ModelPill extends StatelessWidget {
  const _ModelPill({
    required this.providerName,
    required this.model,
    required this.onTap,
  });

  final String providerName;
  final String? model;
  final VoidCallback onTap;

  /// "meta-llama/llama-3.3-70b:free" -> "llama-3.3-70b:free" (shorter to read).
  String get _shortModel => model!.split('/').last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        model == null ? 'Choose a model' : _shortModel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        providerName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
