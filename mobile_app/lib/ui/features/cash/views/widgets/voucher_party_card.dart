/// بطاقة الطرف لشاشة السند — زر اختيار كبير أو الطرف المختار برصيده
/// بعملته (سطر رصيد لكل طرف×عملة).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/voucher_view_model.dart';

/// بطاقة الطرف — زر اختيار كبير أو الطرف المختار برصيده بعملته.
class VoucherPartyCard extends StatelessWidget {
  const VoucherPartyCard({super.key, required this.vm, required this.onPick});

  final VoucherViewModel vm;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);

    if (vm.partyId == null) {
      return FinCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  vm.isReceipt
                      ? Icons.person_search_rounded
                      : Icons.local_shipping_rounded,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.cashVoucherPartySection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: Text(l10n.cashVoucherPickParty),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      );
    }

    final balanceLabel = vm.isReceipt
        ? (vm.partyBalance! > 0
              ? l10n.cashVoucherPartyOwesYou
              : vm.partyBalance! < 0
              ? l10n.cashVoucherPartyCredit
              : l10n.sellCustomerClear)
        : (vm.partyBalance! > 0
              ? l10n.cashVoucherPartyWeOwe
              : vm.partyBalance! < 0
              ? l10n.cashVoucherPartyCredit
              : l10n.sellCustomerClear);
    final balanceColor = vm.partyBalance! > 0
        ? (vm.isReceipt ? colors.positive : colors.warning)
        : vm.partyBalance! < 0
        ? (vm.isReceipt ? colors.neutral : colors.positive)
        : scheme.onSurfaceVariant;

    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    vm.partyName!.trim().isEmpty
                        ? '؟'
                        : vm.partyName!.trim().characters.first,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vm.partyName!,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          l10n.cashVoucherPartyBalance,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            balanceLabel,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: balanceColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      AmountText(
                        amount: vm.partyBalance!.abs(),
                        decimals: 2,
                        showSignMarker: false,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vm.partyCurrencyCode ?? '',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.gold,
                          fontWeight: FontWeight.w800,
                          fontFeatures: FinText.tabularNums,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(l10n.cashVoucherChangeParty),
            ),
          ),
        ],
      ),
    );
  }
}
