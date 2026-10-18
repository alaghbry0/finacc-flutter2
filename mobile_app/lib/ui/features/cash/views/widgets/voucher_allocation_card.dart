/// بطاقة التخصيص لشاشة السند — خيار FIFO/على الحساب + معاينة الفواتير
/// المفتوحة وخطة FIFO الحية + سطر الإيداع المتوقع بعملة الصندوق.
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/voucher_view_model.dart';
import 'cash_widgets.dart';

/// خيار التخصيص + معاينة الفواتير المفتوحة وخطة FIFO الحية.
class VoucherAllocationCard extends StatelessWidget {
  const VoucherAllocationCard({super.key, required this.vm});

  final VoucherViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final plan = vm.previewPlan;
    final unallocated = vm.unallocatedRemainder;

    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.cashVoucherAllocationSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(l10n.cashVoucherAllocFifo),
                icon: const Icon(Icons.low_priority_rounded),
              ),
              ButtonSegment(
                value: false,
                label: Text(l10n.cashVoucherAllocOnAccount),
                icon: const Icon(Icons.account_balance_wallet_rounded),
              ),
            ],
            selected: {vm.allocateFifo},
            onSelectionChanged: vm.saving
                ? null
                : (selection) => vm.setAllocateFifo(selection.first),
          ),
          if (vm.openInvoicesLoading)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else if (vm.allocateFifo) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.cashVoucherOpenDuesTotal,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                AmountText(amount: vm.openDuesTotal, showSignMarker: false),
                const SizedBox(width: 4),
                Text(
                  vm.voucherCurrencyCode ?? '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.gold,
                  ),
                ),
              ],
            ),
            if (vm.openInvoices.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.cashVoucherNoOpenDues,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              for (final invoice in vm.openInvoices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice.invoiceNo,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: FinText.tabularNums,
                                  ),
                            ),
                            Text(
                              cashFormatDate(invoice.issuedAt),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontFeatures: FinText.tabularNums),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.cashVoucherOpenRemaining,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(width: 6),
                      AmountText(
                        amount: invoice.remaining,
                        showSignMarker: false,
                      ),
                    ],
                  ),
                ),
              if (plan.isNotEmpty) ...[
                const Divider(height: 18, thickness: 0.6),
                Text(
                  l10n.cashVoucherPlanTitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
                for (final entry in plan)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.subdirectory_arrow_left_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.invoiceNo,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontFeatures: FinText.tabularNums),
                          ),
                        ),
                        AmountText(
                          amount: entry.amount,
                          // DS-18: علامة + غير لونية إلزامية للتخصيصات
                          // (إشارة واردة للفاتورة) — إصلاح جولة 13.
                          sign: FinSign.incoming,
                        ),
                      ],
                    ),
                  ),
                if (unallocated > 0.005)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 14,
                          color: colors.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.cashVoucherUnallocated,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: colors.warning),
                          ),
                        ),
                        AmountText(amount: unallocated, showSignMarker: false),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

/// سطر الإيداع المتوقع بعملة الصندوق عند اختلاف عملتي السند والصندوق.
class VoucherCrossCurrencyNote extends StatelessWidget {
  const VoucherCrossCurrencyNote({super.key, required this.vm});

  final VoucherViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.currency_exchange_rounded,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.cashVoucherCrossDeposit(
                AmountText.format(vm.projectedBoxDeposit!, 2),
                vm.selectedBox?.box.currencyCode ?? '',
              ),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
