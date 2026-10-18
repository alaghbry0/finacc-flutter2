/// إسقاط طباعة سند القبض/الصرف من صف الحركة (R19-D3a — مستخرج حرفياً
/// من `movements_screen.dart` بلا أي تغيير دلالة؛ كانت `_isPrintableVoucher`
/// و`_voucherDecimals` و`_voucherPrintDoc`).
library;

import '../../../../../domain/models/cash.dart';
import '../../../../../domain/models/company.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../printing/docs/print_docs.dart';
import 'cash_widgets.dart';

/// هل يجوز طباعة هذه الحركة كسند؟ — سندات RVT/PMT المرقّمة حصراً.
bool movementIsPrintableVoucher(CashMovementRow movement) =>
    (movement.voucherNo ?? '').isNotEmpty &&
    (movement.txTypeCode == 'RVT' || movement.txTypeCode == 'PMT');

/// منازل العملة للطباعة (يفوّض إلى `AmountText.decimalsFor` — قاعدة 5.4-9
/// بمصدرها الموحد؛ الخرج مطابق حرفياً).
int movementVoucherDecimals(CashMovementRow movement) =>
    AmountText.decimalsFor(movement.currencyCode);

/// يبني إسقاط السند من صف الحركة + رأس المنشأة — كل تسمية مسبقة التعريب
/// من l10n، والمبلغ عبر `AmountText.format` (غربي بفواصل آلاف).
VoucherPrintDoc movementVoucherPrintDoc(
  AppLocalizations l10n,
  CashMovementRow movement,
  Company? company,
) {
  return VoucherPrintDoc(
    header: PrintHeader(
      name: company?.name ?? '',
      phone: company?.phone,
      address: company?.address,
      footerText: company?.footerText,
    ),
    isReceipt: movement.txTypeCode == 'RVT',
    voucherNo: movement.voucherNo!,
    dateLabel: cashFormatDate(movement.txDate),
    partyName: movement.customerName ?? movement.supplierName,
    amountLabel: AmountText.format(
      movement.amount,
      movementVoucherDecimals(movement),
    ),
    currencyCode: movement.currencyCode,
    description: movement.description,
    boxName: movement.cashboxName,
    labels: VoucherLabels(
      titleReceipt: l10n.printingVoucherReceiptTitle,
      titlePayment: l10n.printingVoucherPaymentTitle,
      party: l10n.printingLblParty,
      date: l10n.printingLblDate,
      amount: l10n.printingLblAmount,
      description: l10n.printingLblDescription,
      box: l10n.printingLblBox,
      signature: l10n.printingLblSignature,
      footerThanks: l10n.printingFooterThanks,
    ),
  );
}
