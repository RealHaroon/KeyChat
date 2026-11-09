import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/conversation.dart';
import '../providers/chat_provider.dart';

/// Lists saved conversations. Tap to open, swipe or tap the bin to delete.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this chat?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final conversations = chat.conversations;

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          chat.newChat();
          Navigator.of(context).pop();
        },
        icon: const Icon(Icons.add),
        label: const Text('New chat'),
      ),
      body: conversations.isEmpty
          ? const _EmptyHistory()
          : ListView.builder(
              // Leave room so the last item is not hidden by the button.
              padding: EdgeInsets.only(
                bottom: 88 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return Dismissible(
                  key: ValueKey(conversation.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmDelete(context),
                  onDismissed: (_) => chat.deleteConversation(conversation.id),
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete_outline),
                  ),
                  child: _ConversationTile(
                    conversation: conversation,
                    isOpen: conversation.id == chat.current.id,
                    onTap: () {
                      chat.openConversation(conversation.id);
                      Navigator.of(context).pop();
                    },
                    onDelete: () async {
                      if (await _confirmDelete(context)) {
                        chat.deleteConversation(conversation.id);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.isOpen,
    required this.onTap,
    required this.onDelete,
  });

  final Conversation conversation;
  final bool isOpen;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// "Just now", "5 min ago", "Yesterday", or a date like "12/3/2026".
  static String _friendlyDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final count = conversation.messages.length;
    return ListTile(
      selected: isOpen,
      onTap: onTap,
      leading: const Icon(Icons.chat_bubble_outline),
      title: Text(
        conversation.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$count message${count == 1 ? '' : 's'} · ${_friendlyDate(conversation.updatedAt)}',
      ),
      trailing: IconButton(
        tooltip: 'Delete',
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: 56,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text('No saved chats yet', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
