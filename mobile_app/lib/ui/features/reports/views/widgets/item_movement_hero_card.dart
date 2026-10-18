/// بطاقة الاختيار البطلة لتقرير حركة صنف حين لم يُحدَّد صنف بعد
/// (R19-D3a — مستخرجة حرفياً من `item_movement_screen.dart` بلا أي
/// تغيير دلالة؛ كانت `_ProductPickerHeroCard`).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/fin_card.dart';

/// بطاقة الاختيار البطلة حين لم يُحدَّد صنف بعد.
class ItemMovementPickerHeroCard extends StatelessWidget {
  const ItemMovementPickerHeroCard({super.key, required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FinCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.manage_search_rounded,
                  size: 26,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.itemMovementPickTitle,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.itemMovementPickBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              key: const Key('itemMovement_pick_button'),
              onPressed: onPick,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: Text(l10n.itemMovementPickButton),
            ),
          ),
        ],
      ),
    );
  }
}
