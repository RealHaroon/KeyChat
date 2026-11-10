import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ai_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_exception.dart';
import '../services/llm_api_service.dart';
import '../widgets/keychat_logo.dart';

/// Choose a provider, paste an API key, and "Test & Save" it.
///
/// Used for first-time onboarding and, later, from Settings to change keys.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    this.isOnboarding = false,
    this.initialProvider,
  });

  final bool isOnboarding;
  final AiProvider? initialProvider;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _keyController = TextEditingController();
  late AiProvider _provider;
  bool _obscureKey = true;
  bool _isTesting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _provider =
        widget.initialProvider ?? context.read<SettingsProvider>().provider;
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _pasteKey() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _showSnack('Clipboard is empty');
      return;
    }
    _keyController.text = text;
    setState(() => _error = null);
  }

  Future<void> _testAndSave() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please paste your API key.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isTesting = true;
      _error = null;
    });

    final settings = context.read<SettingsProvider>();
    final api = context.read<LlmApiService>();
    try {
      await api.validateKey(_provider, key);
      await settings.saveApiKey(_provider, key);
      if (!mounted) return;
      _showSnack('${_provider.name} key saved');
      // During onboarding the app switches to the chat screen by itself.
      if (!widget.isOnboarding) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: widget.isOnboarding ? null : AppBar(title: const Text('API key')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.isOnboarding) ...[
                const SizedBox(height: 32),
                const Center(child: KeyChatLogo(size: 72)),
                const SizedBox(height: 20),
                Text(
                  'Welcome to KeyChat',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bring your own API key. It is stored only on this device, '
                  'encrypted, and sent only to the provider you choose.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
              ],
              Text('1. Choose a provider', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final provider in AiProvider.all)
                _ProviderCard(
                  provider: provider,
                  selected: provider.id == _provider.id,
                  onTap: _isTesting
                      ? null
                      : () => setState(() {
                          _provider = provider;
                          _error = null;
                        }),
                ),
              const SizedBox(height: 24),
              Text('2. Paste your API key', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _keyController,
                obscureText: _obscureKey,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_isTesting,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _testAndSave(),
                decoration: InputDecoration(
                  hintText: _provider.keyHint,
                  errorText: _error,
                  errorMaxLines: 3,
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _obscureKey ? 'Show key' : 'Hide key',
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                      IconButton(
                        tooltip: 'Paste',
                        icon: const Icon(Icons.content_paste_rounded),
                        onPressed: _isTesting ? null : _pasteKey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(_provider.apiKeyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text('Get a free ${_provider.name} key'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isTesting ? null : _testAndSave,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: _isTesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isTesting ? 'Testing key…' : 'Test & Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final AiProvider provider;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? colors.primary : colors.outline,
        ),
        title: Text(
          provider.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(provider.description),
      ),
    );
  }
}
