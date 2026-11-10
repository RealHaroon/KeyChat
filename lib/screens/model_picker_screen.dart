import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_model.dart';
import '../providers/settings_provider.dart';
import '../services/api_exception.dart';
import '../services/llm_api_service.dart';
import '../services/secure_key_storage.dart';

/// Lists the provider's models (fetched live from GET /models) with search.
class ModelPickerScreen extends StatefulWidget {
  const ModelPickerScreen({super.key});

  @override
  State<ModelPickerScreen> createState() => _ModelPickerScreenState();
}

class _ModelPickerScreenState extends State<ModelPickerScreen> {
  final _searchController = TextEditingController();
  List<AiModel> _models = [];
  String _query = '';
  bool _freeOnly = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = context.read<SettingsProvider>().provider;
    final api = context.read<LlmApiService>();
    final keyStorage = context.read<SecureKeyStorage>();

    try {
      final apiKey = await keyStorage.readKey(provider.id) ?? '';
      final models = await api.fetchModels(provider, apiKey);
      if (mounted) setState(() => _models = models);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _hasFreeModels => _models.any((m) => m.isFree);

  List<AiModel> get _filteredModels {
    final q = _query.toLowerCase();
    return _models
        .where((m) => !_freeOnly || m.isFree)
        .where(
          (m) =>
              q.isEmpty ||
              m.id.toLowerCase().contains(q) ||
              m.name.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _select(AiModel model) async {
    await context.read<SettingsProvider>().selectModel(model.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('${settings.provider.name} models')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Search models',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            // Only useful for providers that mix free and paid models.
            if (!_isLoading && _hasFreeModels)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Free only'),
                      selected: _freeOnly,
                      onSelected: (value) => setState(() => _freeOnly = value),
                    ),
                    const Spacer(),
                    Text(
                      '${_filteredModels.length} models',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildBody(settings.selectedModel)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String? selectedId) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _MessageView(
        icon: Icons.cloud_off_rounded,
        message: _error!,
        action: FilledButton.icon(
          onPressed: _loadModels,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }

    final models = _filteredModels;
    if (models.isEmpty) {
      return _MessageView(
        icon: Icons.search_off_rounded,
        message: _query.isEmpty
            ? 'No models found.'
            : 'No models match "$_query".',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadModels,
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: models.length,
        itemBuilder: (context, index) {
          final model = models[index];
          return _ModelTile(
            model: model,
            selected: model.id == selectedId,
            onTap: () => _select(model),
          );
        },
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final AiModel model;
  final bool selected;
  final VoidCallback onTap;

  String? get _contextLabel {
    final tokens = model.contextLength;
    if (tokens == null) return null;
    return tokens >= 1000
        ? '${(tokens / 1000).round()}K context'
        : '$tokens context';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = [
      if (model.name != model.id) model.id,
      ?_contextLabel, // Added only when not null.
    ].join(' · ');

    return ListTile(
      selected: selected,
      selectedTileColor: colors.primaryContainer.withValues(alpha: 0.4),
      onTap: onTap,
      title: Text(model.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: details.isEmpty
          ? null
          : Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (model.isFree)
            Chip(
              label: const Text('Free'),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
              backgroundColor: colors.tertiaryContainer,
              labelStyle: TextStyle(color: colors.onTertiaryContainer),
            ),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_rounded, color: colors.primary),
          ],
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
