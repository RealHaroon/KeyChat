import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Switches provider if it already has a key, otherwise asks for one.
  Future<void> _switchProvider(
    BuildContext context,
    AiProvider provider,
  ) async {
    final settings = context.read<SettingsProvider>();
    if (provider.id == settings.provider.id) return;

    if (await settings.hasKeyFor(provider)) {
      await settings.setProvider(provider);
    } else if (context.mounted) {
      _openSetup(context, provider);
    }
  }

  void _openSetup(BuildContext context, AiProvider provider) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SetupScreen(initialProvider: provider)),
    );
  }

  Future<void> _deleteKey(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final provider = settings.provider;
    final confirmed = await _confirm(
      context,
      title: 'Delete ${provider.name} key?',
      message:
          'The key will be removed from this device. '
          'You will need to paste it again to keep chatting.',
      action: 'Delete',
    );
    if (!confirmed || !context.mounted) return;

    // Go back to the first screen; with no key it becomes the setup screen.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await settings.deleteApiKey(provider);
  }

  Future<void> _clearChats(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'Clear all chats?',
      message:
          'Every saved conversation will be deleted. This cannot be undone.',
      action: 'Clear all',
    );
    if (!confirmed || !context.mounted) return;
    await context.read<ChatProvider>().clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('All chats deleted')));
    }
  }

  Future<void> _editSystemPrompt(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _SystemPromptDialog(initialValue: settings.systemPrompt),
    );
    if (result != null) await settings.setSystemPrompt(result);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        children: [
          const _SectionHeader('Provider'),
          for (final provider in AiProvider.all)
            ListTile(
              leading: Icon(
                provider.id == settings.provider.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: provider.id == settings.provider.id
                    ? colors.primary
                    : null,
              ),
              title: Text(provider.name),
              subtitle: Text(provider.description),
              onTap: () => _switchProvider(context, provider),
            ),
          const Divider(),
          const _SectionHeader('API key'),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: Text('Change ${settings.provider.name} key'),
            subtitle: const Text('Stored encrypted on this device'),
            onTap: () => _openSetup(context, settings.provider),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: colors.error),
            title: Text(
              'Delete ${settings.provider.name} key',
              style: TextStyle(color: colors.error),
            ),
            onTap: () => _deleteKey(context),
          ),
          const Divider(),
          const _SectionHeader('Chat'),
          ListTile(
            leading: const Icon(Icons.psychology_outlined),
            title: const Text('System prompt'),
            subtitle: Text(
              settings.systemPrompt.isEmpty ? 'None' : settings.systemPrompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _editSystemPrompt(context),
          ),
          ListTile(
            leading: Icon(Icons.delete_sweep_outlined, color: colors.error),
            title: Text(
              'Clear all chats',
              style: TextStyle(color: colors.error),
            ),
            onTap: () => _clearChats(context),
          ),
          const Divider(),
          const _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Dark'),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) =>
                  settings.setThemeMode(selection.first),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// A dialog with a multi-line text field to edit the system prompt.
class _SystemPromptDialog extends StatefulWidget {
  const _SystemPromptDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_SystemPromptDialog> createState() => _SystemPromptDialogState();
}

class _SystemPromptDialogState extends State<_SystemPromptDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('System prompt'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 4,
        maxLines: 8,
        decoration: const InputDecoration(
          hintText: 'Tell the AI how to behave…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              _controller.text = SettingsProvider.defaultSystemPrompt,
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
