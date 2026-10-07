/// تفاصيل عرض السعر — الرأس (رقم/حالة/عميل/عملة/صلاحية) + البنود +
/// الصافي + أزرار: تحويل إلى فاتورة (يفتح PaymentSheet مختصراً ثم
/// convertToInvoice الذرّي)، تعليم «مُرسَل»، إلغاء بتأكيد.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/quotation.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/quotations_view_model.dart';
import 'quotations_screen.dart' show QuotationStatusChip;
import 'widgets/payment_sheet.dart';
import 'widgets/sell_widgets.dart';

/// تفاصيل عرض السعر (مسار مقترح `/sell/quotations/:id`).
class QuotationDetailScreen extends StatelessWidget {
  const QuotationDetailScreen({super.key, required this.quotationId});

  final int quotationId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final vm = QuotationDetailViewModel(
      quotationRepo: app.quotations!,
      companyRepo: app.companies!,
      quotationId: quotationId,
    );
    unawaited(() async {
      vm.setUserId((await app.companies!.findAdminUserId()) ?? 1);
      await vm.load();
    }());
    return ChangeNotifierProvider<QuotationDetailViewModel>.value(
      value: vm,
      child: const _QuotationDetailBody(),
    );
  }
}

class _QuotationDetailBody extends StatelessWidget {
  const _QuotationDetailBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<QuotationDetailViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final quotation = vm.quotation;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/sell/quotations')),
        title: Text(quotation?.quotationNo ?? l10n.sellQuotationDetailTitle),
      ),
      body: state.loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [ListSkeleton(rows: 6)],
            )
          : state.error != null
          ? ListView(
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
            )
          : state.detail == null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                EmptyState(
                  icon: Icons.request_quote_rounded,
                  title: l10n.sellQuotationNotFoundTitle,
                  message: l10n.sellQuotationNotFoundBody,
                  compact: true,
                ),
              ],
            )
          : _QuotationDetailContent(vm: vm),
      bottomNavigationBar:
          (state.detail != null && quotation!.status.convertible)
          ? _ActionsBar(vm: vm)
          : null,
    );
  }
}

class _QuotationDetailContent extends StatelessWidget {
  const _QuotationDetailContent({required this.vm});

  final QuotationDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final detail = vm.state.detail!;
    final quotation = detail.quotation;
    final local = quotation.issuedAt.toLocal();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quotation.quotationNo,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: FinText.tabularNums,
                      ),
                    ),
                  ),
                  QuotationStatusChip(status: quotation.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${sellFormatDate(local)} · ${sellFormatTime(local)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
              const SizedBox(height: 8),
              _InfoRow(
                label: l10n.sellDetailCustomer,
                value: detail.customerName ?? l10n.sellCashCustomer,
              ),
              if (detail.customerPhone != null &&
                  detail.customerPhone!.isNotEmpty)
                _InfoRow(
                  label: l10n.sellDetailPhone,
                  value: detail.customerPhone!,
                ),
              _InfoRow(
                label: l10n.sellDetailCurrency,
                value:
                    '${detail.currencyCode ?? ''} · '
                    '${l10n.sellQuotationRateLabel} '
                    '${AmountText.format(quotation.exchangeRate, 4)}',
              ),
              if (quotation.validUntil != null)
                _InfoRow(
                  label: l10n.sellQuotationValidUntilLabel,
                  value: sellFormatDate(quotation.validUntil!.toLocal()),
                ),
              if (quotation.convertedInvoiceId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: StatusChip(
                    label: l10n.sellQuotationConvertedTo(
                      '${quotation.convertedInvoiceId}',
                    ),
                    tone: ChipTone.positive,
                    icon: Icons.check_circle_rounded,
                    dense: false,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.sellDetailItemsSection,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              for (final item in detail.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.lineDesc ?? l10n.sellDetailUnknownItem,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${l10n.sellDetailQtyLabel} '
                              '${sellQtyText(item.qty)} × '
                              '${AmountText.format(item.unitPrice, item.unitPrice == item.unitPrice.truncateToDouble() ? 0 : 2)}'
                              '${item.discountAmount > 0 ? ' · ${l10n.sellDetailDiscountLabel} ${AmountText.format(item.discountAmount, 2)}' : ''}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontFeatures: FinText.tabularNums,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: AmountText(
                            amount: item.lineTotal,
                            decimals:
                                item.lineTotal ==
                                    item.lineTotal.truncateToDouble()
                                ? 0
                                : 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AmountRow(
                label: l10n.sellTotalsSubtotal,
                value: quotation.subtotal,
              ),
              if (quotation.discountAmount > 0)
                _AmountRow(
                  label: l10n.sellDetailTotalDiscount,
                  value: quotation.discountAmount,
                  sign: FinSign.outgoing,
                ),
              Divider(
                height: 18,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.sellQuotationNetTotal,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  AmountText(
                    amount: quotation.total,
                    size: AmountSize.large,
                    decimals:
                        quotation.total == quotation.total.truncateToDouble()
                        ? 0
                        : 2,
                  ),
                ],
              ),
            ],
          ),
        ),
        if ((quotation.notesPrinted ?? '').isNotEmpty) ...[
          const SizedBox(height: 14),
          FinCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sellQuotationPrintedNotes,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  quotation.notesPrinted!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionsBar extends StatelessWidget {
  const _ActionsBar({required this.vm});

  final QuotationDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final quotation = vm.quotation!;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: FinColors.of(context).cardBorder, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: vm.state.converting
                      ? null
                      : () => _convert(context, vm),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    textStyle: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: Text(l10n.sellQuotationConvertButton),
                ),
              ),
              if (quotation.status == QuotationStatus.draft) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => _markSent(context, vm),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    label: Text(l10n.sellQuotationMarkSent),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => _cancel(context, vm),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FinColors.of(context).negative,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 20),
                  label: Text(l10n.sellQuotationCancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _convert(
    BuildContext context,
    QuotationDetailViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final quotation = vm.quotation!;
    final posted = await showPaymentSheet(
      context,
      grandTotal: quotation.total,
      decimals: vm.currency?.decimals ?? 2,
      currencyCode: vm.state.detail?.currencyCode,
      customerName: vm.state.detail?.customerName,
      onConfirm: (paidCash, method) =>
          vm.convertToInvoice(paidCash: paidCash, paymentMethod: method),
    );
    if (posted && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.sellQuotationConvertedMessage)),
        );
    }
  }

  Future<void> _markSent(
    BuildContext context,
    QuotationDetailViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await vm.markSent();
    if (!context.mounted) return;
    if (result.isOk) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.sellQuotationSentMessage)));
      unawaited(vm.load());
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result.errorOrNull!)));
    }
  }

  Future<void> _cancel(
    BuildContext context,
    QuotationDetailViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.sellQuotationCancelConfirmTitle),
        content: Text(
          l10n.sellQuotationCancelConfirmBody(vm.quotation!.quotationNo),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      final result = await vm.cancel();
      if (!context.mounted) return;
      if (result.isOk) {
        unawaited(vm.load());
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(result.errorOrNull!)));
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.sign = FinSign.neutral,
  });

  final String label;
  final double value;
  final FinSign sign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          AmountText(
            amount: value,
            sign: sign,
            decimals: value == value.truncateToDouble() ? 0 : 2,
          ),
        ],
      ),
    );
  }
}
