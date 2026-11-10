import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/keychat_logo.dart';
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
    final provider = settings.provider;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _Section(
            title: 'Provider',
            children: [
              for (final p in AiProvider.all)
                ListTile(
                  leading: Icon(
                    p.id == provider.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: p.id == provider.id ? colors.primary : null,
                  ),
                  title: Text(p.name),
                  subtitle: Text(p.description),
                  onTap: () => _switchProvider(context, p),
                ),
            ],
          ),
          _Section(
            title: 'API key',
            children: [
              ListTile(
                leading: const Icon(Icons.vpn_key_outlined),
                title: Text('Change ${provider.name} key'),
                subtitle: const Text('Stored encrypted on this device'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openSetup(context, provider),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.error,
                ),
                title: Text(
                  'Delete ${provider.name} key',
                  style: TextStyle(color: colors.error),
                ),
                onTap: () => _deleteKey(context),
              ),
            ],
          ),
          _Section(
            title: 'Chat',
            children: [
              ListTile(
                leading: const Icon(Icons.psychology_outlined),
                title: const Text('System prompt'),
                subtitle: Text(
                  settings.systemPrompt.isEmpty
                      ? 'None'
                      : settings.systemPrompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
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
            ],
          ),
          _Section(
            title: 'Appearance',
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) =>
                      settings.setThemeMode(selection.first),
                ),
              ),
            ],
          ),
          const _Section(
            title: 'About',
            children: [
              ListTile(
                leading: KeyChatLogo(size: 32),
                title: Text('KeyChat'),
                subtitle: Text('Bring your own key AI chat · made by Haroon'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A titled group of settings drawn as one rounded card.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Tell the AI how to behave…',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'KeyChat always tells the AI what app it is in and who made it, '
            'so you only need to describe tone and style here.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
