/// نافذة تفاصيل حركة الصندوق + الإبطال (R19-D3a — مستخرجة حرفياً من
/// `movements_screen.dart` بلا أي تغيير دلالة؛ كانت `showMovementDetailSheet`
/// و`_MovementDetailSheet` و`_DetailRow` و`_RateRow`).
///
/// الرسوم (بطاقة الحقول/بطاقة التخصيصات/إجراء الإبطال) بملفاتها
/// المركزّعة بجوارها (R20-D3d) — هذا الملف: آلة الحالة (التحميل/
/// الإبطال/معاينة سند PDF) بنمط payment_sheet.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../domain/models/cash.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/session/app_controller.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../printing/services/voucher_pdf_builder.dart';
import '../../../printing/views/pdf_preview_dialog.dart';
import '../../view_models/movements_view_model.dart';
import 'cash_widgets.dart';
import 'movement_detail_allocations_card.dart';
import 'movement_detail_fields_card.dart';
import 'movement_detail_void_action.dart';
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
              MovementDetailFieldsCard(movement: _detail!.movement),
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
                MovementDetailAllocationsCard(
                  allocations: _detail!.allocations,
                ),
              ],
              const SizedBox(height: 16),
              MovementDetailVoidAction(
                movement: _detail!.movement,
                voiding: widget.vm.state.voidingId == _detail!.movement.id,
                onVoid: () => unawaited(_confirmVoid(_detail!.movement)),
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
