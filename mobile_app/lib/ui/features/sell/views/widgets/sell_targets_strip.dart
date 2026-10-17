/// شريط أهداف الكاشير القابل للطي (عميل + عملة + تاريخ) — §6.5.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/sell_cart_view_model.dart';
import 'sell_widgets.dart';

class SellTargetsStrip extends StatelessWidget {
  const SellTargetsStrip({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.onPickCustomer,
    required this.onPickCash,
    required this.onPickCurrency,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onPickCustomer;
  final VoidCallback onPickCash;
  final ValueChanged<int> onPickCurrency;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellCartViewModel>();
    final state = vm.state;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final customerLabel = state.customer?.name ?? l10n.sellCashCustomer;
    final currency = state.selectedCurrency;
    return FinCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(
                  Icons.person_pin_circle_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customerLabel,
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
                  sellFormatDate(now),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPickCustomer,
                          icon: const Icon(Icons.search_rounded, size: 18),
                          label: Text(l10n.sellPickCustomer),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPickCash,
                          icon: const Icon(Icons.person_off_outlined, size: 18),
                          label: Text(l10n.sellCashCustomer),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CurrencyPickerRow(
                    currencies: [
                      for (final c in state.currencies)
                        CurrencyOption(
                          id: c.id,
                          code: c.code,
                          isBase: c.isBase,
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
