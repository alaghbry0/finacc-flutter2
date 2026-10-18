/// نافذة تفاصيل حركة الصندوق + الإبطال (R19-D3a — مستخرجة حرفياً من
/// `movements_screen.dart` بلا أي تغيير دلالة؛ كانت `showMovementDetailSheet`
/// و`_MovementDetailSheet` و`_DetailRow` و`_RateRow`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/session/app_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../printing/services/voucher_pdf_builder.dart';
import '../../../printing/views/pdf_preview_dialog.dart';
import '../../view_models/movements_view_model.dart';
import 'cash_widgets.dart';
import 'movement_voucher_pdf.dart';

/// يفتح نافذة التفاصيل؛ بعد إغلاقها يُعاد تحميل السجل إن تغيّر (الإبطال
/// يعيد التحميل من النموذج أصلاً — هذا للأمان العام).
Future<void> showMovementDetailSheet(
  BuildContext context, {
  required MovementsViewModel vm,
  required int movementId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MovementDetailSheet(vm: vm, movementId: movementId),
  );
}

class _MovementDetailSheet extends StatefulWidget {
  const _MovementDetailSheet({required this.vm, required this.movementId});

  final MovementsViewModel vm;
  final int movementId;

  @override
  State<_MovementDetailSheet> createState() => _MovementDetailSheetState();
}

class _MovementDetailSheetState extends State<_MovementDetailSheet> {
  CashMovementDetail? _detail;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final detail = await widget.vm.movementDetail(widget.movementId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _confirmVoid(CashMovementRow movement) async {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.cashMovementVoidTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.cashMovementVoidBody),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: l10n.cashMovementVoidReasonLabel,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.cashMovementVoidConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      final result = await widget.vm.voidMovement(
        movement.id,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );
      reasonController.dispose();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (result.isOk) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.cashMovementVoidedSnackBar)),
          );
        Navigator.of(context).pop();
      } else {
        // رفض المستودع برسالة عربية — تُعرض كما هي.
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              content: Text(
                result.errorOrNull!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          );
      }
    } else {
      reasonController.dispose();
    }
  }

  /// يفتح نافذة معاينة طباعة سند القبض/الصرف (الشريحة 7) — كل القيم
  /// تُلتقط قبل أي await (لا سياق عبر فجوة غير متزامنة). واتساب من
  /// المنشأة حصراً: هاتف الطرف غير متوفر على صف الحركة.
  Future<void> _openVoucherPdf(CashMovementRow movement) async {
    final l10n = AppLocalizations.of(context)!;
    final company = context.read<AppController>().company;
    final voucherNo = movement.voucherNo!;
    await showPdfPreviewDialog(
      context,
      title: voucherNo,
      build: () => const VoucherPdfBuilder().build(
        movementVoucherPrintDoc(l10n, movement, company),
      ),
      whatsappPhone: company?.whatsapp,
      shareMessage: l10n.printingShareMessageVoucher(
        AmountText.format(movement.amount, movementVoucherDecimals(movement)),
        voucherNo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CashSheetDragHandle(),
            const SizedBox(height: 14),
            Text(
              l10n.cashMovementDetailTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              )
            else if (_error != null)
              ErrorState(
                title: l10n.genericErrorTitle,
                message: l10n.dbOpenErrorMessage,
                technicalDetails: _error.toString(),
                retryLabel: l10n.commonRetry,
                onRetry: _load,
                compact: true,
              )
            else if (_detail == null)
              EmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.cashMovementsNoResultsTitle,
                message: l10n.cashMovementsNoResultsBody,
                compact: true,
              )
            else ...[
              FinCard(
                padding: const EdgeInsets.all(14),
                child: CashMovementTile(
                  movement: _detail!.movement,
                  dimmed: _detail!.movement.isVoided,
                ),
              ),
              const SizedBox(height: 12),
              FinCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DetailRow(
                      label: l10n.cashMovementFieldDate,
                      value: cashFormatDate(_detail!.movement.txDate),
                    ),
                    _DetailRow(
                      label: l10n.cashMovementFieldBox,
                      value:
                          '${_detail!.movement.cashboxName} '
                          '(${_detail!.movement.currencyCode})',
                    ),
                    if (_detail!.movement.toCashboxName != null)
                      _DetailRow(
                        label: l10n.cashMovementFieldTo,
                        value: _detail!.movement.toCashboxName!,
                      ),
                    if (_detail!.movement.voucherNo != null)
                      _DetailRow(
                        label: l10n.cashMovementFieldVoucher,
                        value: _detail!.movement.voucherNo!,
                      ),
                    if (_detail!.movement.customerName != null)
                      _DetailRow(
                        label: l10n.cashMovementFieldParty,
                        value: _detail!.movement.customerName!,
                      ),
                    if (_detail!.movement.supplierName != null)
                      _DetailRow(
                        label: l10n.cashMovementFieldParty,
                        value: _detail!.movement.supplierName!,
                      ),
                    if (_detail!.movement.expenseCategoryName != null)
                      _DetailRow(
                        label: l10n.cashMovementFieldCategory,
                        value: _detail!.movement.expenseCategoryName!,
                      ),
                    _RateRow(
                      label: l10n.cashMovementFieldRate,
                      value: _detail!.movement.exchangeRate,
                    ),
                    if (_detail!.movement.settlementRate != null)
                      _RateRow(
                        label: l10n.cashMovementFieldSettlement,
                        value: _detail!.movement.settlementRate!,
                      ),
                    if ((_detail!.movement.fxGainLoss.abs()) > 0.005)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.cashMovementFieldFx,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                            AmountText(
                              amount: _detail!.movement.fxGainLoss,
                              sign: _detail!.movement.fxGainLoss > 0
                                  ? FinSign.incoming
                                  : FinSign.outgoing,
                            ),
                          ],
                        ),
                      ),
                    if (_detail!.movement.description != null &&
                        _detail!.movement.description!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.cashMovementFieldDescription,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _detail!.movement.description!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // طباعة سند PDF (الشريحة 7) — لسندات RVT/PMT المرقّمة فقط.
              if (movementIsPrintableVoucher(_detail!.movement)) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () =>
                      unawaited(_openVoucherPdf(_detail!.movement)),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                  label: Text(l10n.printingVoucherPdfButton),
                ),
              ],
              if (_detail!.allocations.isNotEmpty) ...[
                const SizedBox(height: 12),
                FinCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.cashMovementAllocationsTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      for (final allocation in _detail!.allocations)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      allocation.invoiceNo,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            fontFeatures: FinText.tabularNums,
                                          ),
                                    ),
                                    Text(
                                      allocation.invoiceTypeCode == 'sale'
                                          ? l10n.cashAllocSaleInvoice
                                          : l10n.cashAllocPurchaseInvoice,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                              AmountText(
                                amount: allocation.allocatedAmount,
                                showSignMarker: false,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                allocation.currencyCode,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colors.gold,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_detail!.movement.isVoidable)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.negative,
                    foregroundColor: colors.onNegative,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: widget.vm.state.voidingId == _detail!.movement.id
                      ? null
                      : () => unawaited(_confirmVoid(_detail!.movement)),
                  icon: widget.vm.state.voidingId == _detail!.movement.id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(Icons.block_rounded, size: 20),
                  label: Text(l10n.cashMovementVoidButton),
                )
              else if (!_detail!.movement.isVoided)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.cashMovementNotVoidableNote,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonDone),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: FinText.tabularNums,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Text(
            AmountText.format(value, 4),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: FinText.tabularNums,
            ),
          ),
        ],
      ),
    );
  }
}
