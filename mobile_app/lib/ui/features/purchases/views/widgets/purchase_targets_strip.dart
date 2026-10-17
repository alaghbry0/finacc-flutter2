/// شريط أهداف فاتورة الشراء القابل للطي (مورد + عملة + التاريخ) —
/// مرآة الكاشير.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/purchase_cart_view_model.dart';
import 'purchase_widgets.dart';

/// شريط الأهداف القابل للطي (مورد + عملة + تاريخ) — مرآة الكاشير.
class PurchaseTargetsStrip extends StatelessWidget {
  const PurchaseTargetsStrip({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.onPickSupplier,
    required this.onPickCurrency,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onPickSupplier;
  final ValueChanged<int> onPickCurrency;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseCartViewModel>();
    final state = vm.state;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final supplierLabel = state.supplier?.name ?? l10n.purSupplierRequired;
    final currency = state.selectedCurrency;
    return FinCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('pur_targets_toggle'),
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(
                  Icons.local_shipping_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    supplierLabel,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(
                  label: currency?.code ?? '—',
                  tone: ChipTone.brand,
                  dense: true,
                ),
                const SizedBox(width: 8),
                Text(
                  purFormatDate(now),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFeatures: FinText.tabularNums,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    key: const Key('pur_pick_supplier_button'),
                    onPressed: onPickSupplier,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(l10n.purPickSupplier),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PurchaseCurrencyPickerRow(
                    currencies: [
                      for (final c in state.currencies)
                        PurchaseCurrencyOption.fromCurrency(
                          c,
                          rateKnown: c.isBase || c.id == state.currencyId
                              ? state.rateKnown
                              : true,
                        ),
                    ],
                    selectedId: state.currencyId,
                    todayRate: state.todayRate,
                    onSelect: onPickCurrency,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
