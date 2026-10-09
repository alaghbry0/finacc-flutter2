/// شاشة بطاقة الصنف (FR-01-03 / FR-09-03): رأس بالاسم والباركود (EAN-13
/// + QR قابلة للمسح)، رقائق الأسعار بكل العملات، بطاقة المخزون بمؤشر
/// حد الطلب، الدفعات FEFO برقائق أيام ملونة، آخر الحركات، وتعديل/أرشفة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../domain/services/numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/fin_tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/info_note.dart';
import '../../../core/widgets/fin_section_title.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/item_detail_view_model.dart';
import 'widgets/inventory_widgets.dart';
import '../../../core/widgets/refresh_on_return.dart';

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.itemId, this.viewModel});

  /// معرّف الصنف المطلوب.
  final int itemId;

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final ItemDetailViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final ItemDetailViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = ItemDetailViewModel(
        itemRepo: app.items!,
        batchRepo: app.batches!,
        companyRepo: app.companies!,
        itemId: itemId,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<ItemDetailViewModel>.value(
      value: vm,
      // تحديث البطاقة عند العودة من مسار التعديل الفرعي (item/:id/edit).
      child: RefreshOnReturn(
        onReappear: vm.load,
        child: const _ItemDetailBody(),
      ),
    );
  }
}

class _ItemDetailBody extends StatelessWidget {
  const _ItemDetailBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ItemDetailViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.itemDetailTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRetry,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: vm.load,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.loading) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [ListSkeleton(rows: 6)],
            );
          }
          if (state.notFound) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ErrorState(
                  title: l10n.genericErrorTitle,
                  message: l10n.itemDetailNotFound,
                  retryLabel: l10n.commonRetry,
                  onRetry: vm.load,
                  compact: true,
                ),
              ],
            );
          }
          if (state.error != null) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ErrorState(
                  title: l10n.genericErrorTitle,
                  message: l10n.dbOpenErrorMessage,
                  technicalDetails: state.error.toString(),
                  retryLabel: l10n.commonRetry,
                  onRetry: vm.load,
                  compact: true,
                ),
              ],
            );
          }
          final detail = state.detail!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _HeaderCard(state: state),
              const SizedBox(height: 14),
              if (!state.archived) _ActionsRow(state: state),
              const SizedBox(height: 14),
              _PricesCard(state: state),
              const SizedBox(height: 14),
              if (detail.item.isService)
                InfoNote(
                  icon: Icons.miscellaneous_services_rounded,
                  message: l10n.itemDetailServiceNote,
                )
              else
                _StockCard(state: state),
              if (detail.item.trackBatches) ...[
                const SizedBox(height: 14),
                _BatchesCard(state: state),
              ],
              const SizedBox(height: 14),
              _MovementsCard(state: state),
            ],
          );
        },
      ),
    );
  }
}

/// رأس البطاقة — الاسم والشارات والباركود وشرح تأجيل الطباعة.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.state});

  final ItemDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final item = state.detail!.item;
    return FinCard(
      accent: FinColors.of(context).gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary,
                      Color.lerp(scheme.primary, Colors.black, 0.25)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(FinRadius.control),
                ),
                child: Icon(
                  item.isService
                      ? Icons.miscellaneous_services_rounded
                      : Icons.inventory_2_rounded,
                  color: scheme.onPrimary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (item.isService)
                StatusChip(label: l10n.itemServiceBadge, tone: ChipTone.brand),
              if (item.trackBatches)
                StatusChip(
                  label: l10n.itemDetailBatchesBadge,
                  tone: ChipTone.neutral,
                  icon: Icons.layers_rounded,
                ),
              if (state.archived)
                StatusChip(
                  label: l10n.itemDetailArchivedBadge,
                  tone: ChipTone.negative,
                  icon: Icons.archive_rounded,
                ),
            ],
          ),
          if (item.barcode != null && item.barcode!.isNotEmpty) ...[
            const SizedBox(height: 14),
            BarcodePreview(
              code: item.barcode!,
              name: item.name,
              caption: l10n.itemDetailBarcodeNote,
            ),
          ],
        ],
      ),
    );
  }
}

/// صف أزرار التعديل والأرشفة.
class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.state});

  final ItemDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final vm = context.read<ItemDetailViewModel>();
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('item_detail_edit_btn'),
            onPressed: () =>
                context.go('/inventory/item/${state.item!.id}/edit'),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text(l10n.itemDetailEditAction),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('item_detail_archive_btn'),
            onPressed: state.archiving
                ? null
                : () => unawaited(_confirmArchive(context, vm, l10n)),
            icon: Icon(Icons.archive_rounded, size: 18, color: colors.negative),
            label: Text(
              l10n.itemDetailArchiveAction,
              style: TextStyle(color: colors.negative),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: colors.negative.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    ItemDetailViewModel vm,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.itemDetailArchiveTitle),
        content: Text(l10n.itemDetailArchiveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.itemDetailArchiveAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await vm.archive();
    if (!ok && context.mounted && vm.state.archiveError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(vm.state.archiveError!)));
      return;
    }
    if (ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.itemDetailArchivedMessage)));
    }
  }
}

/// بطاقة الأسعار — رقاقة لكل عملة (رمز + مبلغ بمنازل العملة).
class _PricesCard extends StatelessWidget {
  const _PricesCard({required this.state});

  final ItemDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final prices = state.detail!.prices
        .where((line) => line.priceLevel == 'retail')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinSectionTitle(
          icon: Icons.sell_rounded,
          title: l10n.itemDetailPricesSection,
        ),
        const SizedBox(height: 8),
        FinCard(
          child: prices.isEmpty
              ? Text(
                  '—',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final line in prices)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.gold.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.gold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              line.currencyCode,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            AmountText(
                              amount: line.price,
                              decimals: state.decimalsFor(line.currencyId),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// بطاقة المخزون — الإجمالي + حد الطلب بمؤشر تقدم ملون + توزيع المخازن.
class _StockCard extends StatelessWidget {
  const _StockCard({required this.state});

  final ItemDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final detail = state.detail!;
    final item = detail.item;
    final total = detail.totalQty;

    final progressColor = total <= 0
        ? colors.negative
        : (total <= item.minStock ? colors.warning : colors.positive);
    final ratio = item.minStock <= 0
        ? (total > 0 ? 1.0 : 0.0)
        : (total / item.minStock).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinSectionTitle(
          icon: Icons.inventory_rounded,
          title: l10n.itemDetailStockSection,
        ),
        const SizedBox(height: 8),
        FinCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.itemDetailTotalLabel,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 2),
                        AmountText(
                          amount: total,
                          size: AmountSize.large,
                          decimals: total == total.truncateToDouble() ? 0 : 2,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.itemDetailMinStockLabel,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 2),
                      AmountText(
                        amount: item.minStock,
                        decimals:
                            item.minStock == item.minStock.truncateToDouble()
                            ? 0
                            : 2,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    color: progressColor,
                  ),
                ),
              ),
              if (detail.stockByWarehouse.isNotEmpty) ...[
                const SizedBox(height: 14),
                Divider(
                  color: Theme.of(context).colorScheme.outlineVariant
                      .withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                for (final warehouse in detail.stockByWarehouse)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.store_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            warehouse.warehouseName,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        AmountText(amount: warehouse.qty, decimals: 0),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// بطاقة الدفعات — مرتبة FEFO مع رقائق أيام ملونة وكميات.
class _BatchesCard extends StatelessWidget {
  const _BatchesCard({required this.state});

  final ItemDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final arabicIndic = NumeralsScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinSectionTitle(
          icon: Icons.layers_rounded,
          title: l10n.itemDetailBatchesSection,
        ),
        const SizedBox(height: 8),
        FinCard(
          child: state.batches.isEmpty
              ? Text(
                  l10n.itemDetailNoBatches,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                )
              : Column(
                  children: [
                    for (final batch in state.batches)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.layers_rounded,
                                size: 17,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MonoText(
                                    batch.batchNumber,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(batch.expiryDate, arabicIndic),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 5),
                                  ExpiryDaysChip(days: batch.daysToExpiry),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                AmountText(amount: batch.qty, decimals: 0),
                                Text(
                                  l10n.batchesQtyLabel,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// بطاقة الحركات — نوع + كمية موقَّعة + رصيد بعدها + تاريخ.
class _MovementsCard extends StatelessWidget {
  const _MovementsCard({required this.state});

  final ItemDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final arabicIndic = NumeralsScope.of(context);
    final movements = state.detail!.recentMovements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinSectionTitle(
          icon: Icons.receipt_long_rounded,
          title: l10n.itemDetailMovementsSection,
        ),
        const SizedBox(height: 8),
        FinCard(
          child: movements.isEmpty
              ? Text(
                  l10n.itemDetailNoMovements,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                )
              : Column(
                  children: [
                    for (final movement in movements)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            StatusChip(
                              label: _movementLabel(
                                l10n,
                                movement.movementType,
                              ),
                              tone: movement.qty >= 0
                                  ? ChipTone.positive
                                  : ChipTone.negative,
                              dense: true,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: AmountText(
                                          amount: movement.qty.abs(),
                                          sign: movement.qty >= 0
                                              ? FinSign.incoming
                                              : FinSign.outgoing,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${l10n.itemDetailRemainingLabel}: ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                      Flexible(
                                        child: Builder(
                                          builder: (context) {
                                            final remaining =
                                                movement.remainingAfter ?? 0;
                                            final decimals =
                                                remaining ==
                                                    remaining.truncateToDouble()
                                                ? 0
                                                : 2;
                                            return Text(
                                              AmountText.formatFor(
                                                context,
                                                remaining,
                                                decimals,
                                              ),
                                              style: FinText.amountRow(
                                                scheme.onSurfaceVariant,
                                              ).copyWith(fontSize: 13),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(
                                      movement.movedAt.toLocal(),
                                      arabicIndic,
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: colors.gold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  static String _movementLabel(AppLocalizations l10n, String type) =>
      switch (type) {
        'opening' => l10n.itemMovementOpening,
        'purchase' => l10n.itemMovementPurchase,
        'sale' => l10n.itemMovementSale,
        'sale_return' => l10n.itemMovementSaleReturn,
        'purchase_return' => l10n.itemMovementPurchaseReturn,
        'stocktake_adjust' => l10n.itemMovementStocktakeAdjust,
        'manual_adjust' => l10n.itemMovementManualAdjust,
        'transfer_in' => l10n.itemMovementTransferIn,
        'transfer_out' => l10n.itemMovementTransferOut,
        _ => l10n.itemMovementUnknown,
      };
}

/// تاريخ قياسي (ميلادي) بأرقام السياق — «YYYY/MM/dd HH:mm».
String _formatDate(DateTime date, bool arabicIndic) {
  final formatted = DateFormat('yyyy/MM/dd HH:mm').format(date);
  return arabicIndic ? Numerals.toArabicIndic(formatted) : formatted;
}
