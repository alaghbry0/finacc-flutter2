import 'package:flutter/material.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../view_models/home_view_model.dart';

/// Home screen of the skeleton application.
///
/// A "dumb" view: all state comes from [HomeViewModel] and is consumed
/// through [ListenableBuilder] so the widget rebuilds only when needed.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewModel = context.watch<HomeViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusCard(message: l10n.envReadyMessage),
            const SizedBox(height: 16),
            _ArchitectureCard(
              title: l10n.architectureSectionTitle,
              layers: [l10n.layerUi, l10n.layerDomain, l10n.layerData],
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) => _CounterCard(
                title: l10n.counterSectionTitle,
                valueLabel: l10n.counterValue(viewModel.tapCount),
                canReset: viewModel.canReset,
                onReset: viewModel.reset,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: viewModel.increment,
        tooltip: l10n.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchitectureCard extends StatelessWidget {
  const _ArchitectureCard({required this.title, required this.layers});

  final String title;
  final List<String> layers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...layers.map(
              (layer) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.layers_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(layer)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard({
    required this.title,
    required this.valueLabel,
    required this.canReset,
    required this.onReset,
  });

  final String title;
  final String valueLabel;
  final bool canReset;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              valueLabel,
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                onPressed: canReset ? onReset : null,
                icon: const Icon(Icons.restart_alt),
                label: Text(AppLocalizations.of(context)!.reset),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
