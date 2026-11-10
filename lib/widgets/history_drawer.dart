import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/conversation.dart';
import '../providers/chat_provider.dart';
import 'keychat_logo.dart';

/// Side menu with "New chat", saved conversations grouped by date
/// (Today, Yesterday, ...), and a link to Settings.
/// Open it with the menu button or by swiping from the left edge.
class HistoryDrawer extends StatelessWidget {
  const HistoryDrawer({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  /// Puts each conversation into a date group. The list is already sorted
  /// newest first, so the groups come out in the right order.
  static Map<String, List<Conversation>> _groupByDate(
    List<Conversation> conversations,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<Conversation>>{};

    for (final c in conversations) {
      final d = c.updatedAt;
      final day = DateTime(d.year, d.month, d.day);
      final daysAgo = today.difference(day).inDays;
      final label = switch (daysAgo) {
        <= 0 => 'Today',
        1 => 'Yesterday',
        < 7 => 'Previous 7 days',
        < 30 => 'Previous 30 days',
        _ => 'Older',
      };
      groups.putIfAbsent(label, () => []).add(c);
    }
    return groups;
  }

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
    final theme = Theme.of(context);
    final chat = context.watch<ChatProvider>();
    final groups = _groupByDate(chat.conversations);

    void close() => Navigator.of(context).pop();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: logo + app name.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  const KeyChatLogo(size: 36),
                  const SizedBox(width: 12),
                  Text(
                    'KeyChat',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.tonalIcon(
                onPressed: () {
                  chat.newChat();
                  close();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('New chat'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: groups.isEmpty
                  ? const _EmptyHistory()
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final entry in groups.entries) ...[
                          _GroupHeader(entry.key),
                          for (final conversation in entry.value)
                            _ConversationTile(
                              conversation: conversation,
                              isOpen: conversation.id == chat.current.id,
                              onTap: () {
                                chat.openConversation(conversation.id);
                                close();
                              },
                              onDelete: () async {
                                if (await _confirmDelete(context)) {
                                  chat.deleteConversation(conversation.id);
                                }
                              },
                            ),
                        ],
                      ],
                    ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () {
                  close();
                  onOpenSettings();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One saved chat. Tap to open; long-press or tap the bin to delete.
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      selected: isOpen,
      selectedColor: colors.onSecondaryContainer,
      selectedTileColor: colors.secondaryContainer,
      contentPadding: const EdgeInsets.only(left: 12, right: 0),
      title: Text(
        conversation.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      onTap: onTap,
      onLongPress: onDelete,
      trailing: IconButton(
        tooltip: 'Delete',
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Your chats will appear here',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
