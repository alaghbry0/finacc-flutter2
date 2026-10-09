/// نافذة ترحيل فاتورة الشراء — الصافي كبير أعلى + الطرق (نقدي كامل من
/// الصندوق / آجل كامل دين للمورد / مختلط) + المدفوع نقداً والمتبقي آجلاً
/// بوضوح + **لا دفع زائد** (الزيادة فوق الصافي تُرفض — لا «باقٍ» في
/// الشراء) + تأكيد الترحيل + إيصال نجاح PUR (مرآة PaymentSheet البيع).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../domain/core/result.dart';
import '../../../../../domain/models/purchase.dart';
import '../../../../../domain/services/purchase_pricing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/fin_error_card.dart';
import 'purchase_widgets.dart';

/// أنماط الدفع في نافذة الشراء.
enum _PayMode { fullCash, fullCredit, mixed }

/// يفتح نافذة ترحيل الشراء — يعيد `true` عند نجاح الترحيل.
Future<bool> showPurchasePaymentSheet(
  BuildContext context, {
  required double grandTotal,
  required int decimals,
  required String? currencyCode,
  required String? supplierName,
  required Future<Result<PurchasePostedReceipt, String>> Function(
    double paidCash,
    PurchasePaymentMethod method,
  )
  onConfirm,
}) async {
  final posted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) => _PurchasePaymentSheet(
      grandTotal: grandTotal,
      decimals: decimals,
      currencyCode: currencyCode,
      supplierName: supplierName,
      onConfirm: onConfirm,
    ),
  );
  return posted ?? false;
}

class _PurchasePaymentSheet extends StatefulWidget {
  const _PurchasePaymentSheet({
    required this.grandTotal,
    required this.decimals,
    required this.currencyCode,
    required this.supplierName,
    required this.onConfirm,
  });

  final double grandTotal;
  final int decimals;
  final String? currencyCode;
  final String? supplierName;
  final Future<Result<PurchasePostedReceipt, String>> Function(
    double paidCash,
    PurchasePaymentMethod method,
  )
  onConfirm;

  @override
  State<_PurchasePaymentSheet> createState() => _PurchasePaymentSheetState();
}

class _PurchasePaymentSheetState extends State<_PurchasePaymentSheet> {
  _PayMode _mode = _PayMode.fullCash;
  late final TextEditingController _cashController;
  bool _posting = false;
  String? _error;
  PurchasePostedReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController(text: _fmt(widget.grandTotal));
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  static String _fmt(double value) => value == value.truncateToDouble()
      ? value.truncate().toString()
      : value.toStringAsFixed(2);

  double? get _paidCash {
    switch (_mode) {
      case _PayMode.fullCredit:
        return 0;
      case _PayMode.fullCash:
      case _PayMode.mixed:
        final raw = _cashController.text.trim().replaceAll(',', '.');
        if (raw.isEmpty) return null;
        return double.tryParse(raw);
    }
  }

  /// المبلغ الصالح للترحيل حسب النمط — أو null مع سبب في [_error].
  double? _validatedPaidCash() {
    final l10n = AppLocalizations.of(context)!;
    final paid = _paidCash;
    if (paid == null || paid.isNaN || paid.isInfinite || paid < 0) {
      setState(() => _error = l10n.sellPayInvalidAmount);
      return null;
    }
    switch (_mode) {
      case _PayMode.fullCash:
        if (paid + moneyEpsilon < widget.grandTotal) {
          setState(
            () => _error = l10n.purPayCashShort(
              widget.grandTotal.toStringAsFixed(2),
            ),
          );
          return null;
        }
      case _PayMode.fullCredit:
        break; // صفر نقدي — آجل كامل (المورد معروف دائماً).
      case _PayMode.mixed:
        if (paid <= moneyEpsilon || paid + moneyEpsilon >= widget.grandTotal) {
          setState(
            () => _error = l10n.purPayMixedRange(
              widget.grandTotal.toStringAsFixed(2),
            ),
          );
          return null;
        }
    }
    return paid;
  }

  Future<void> _confirm() async {
    final paid = _validatedPaidCash();
    if (paid == null) return;
    final method = PurchasePricing.derivePayStatus(widget.grandTotal, paid);
    setState(() {
      _posting = true;
      _error = null;
    });
    final result = await widget.onConfirm(paid, method);
    if (!mounted) return;
    if (result.isOk) {
      setState(() {
        _posting = false;
        _receipt = result.valueOrNull!;
      });
    } else {
      setState(() {
        _posting = false;
        _error = result.errorOrNull!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: _receipt == null
              ? _buildPayForm(context)
              : _buildReceipt(context),
        ),
      ),
    );
  }

  // ── نموذج الدفع ────────────────────────────────────────────────────

  Widget _buildPayForm(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final paid = _paidCash ?? 0;
    final settlement = PurchasePricing.settlePayment(widget.grandTotal, paid);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _dragHandle(scheme)),
        const SizedBox(height: 12),
        _TotalHeader(
          grandTotal: widget.grandTotal,
          decimals: widget.decimals,
          currencyCode: widget.currencyCode,
          supplierName: widget.supplierName,
        ),
        const SizedBox(height: 18),
        SegmentedButton<_PayMode>(
          segments: [
            ButtonSegment(
              value: _PayMode.fullCash,
              label: Text(l10n.sellPayMethodCash),
              icon: const Icon(Icons.payments_rounded),
            ),
            ButtonSegment(
              value: _PayMode.fullCredit,
              label: Text(l10n.sellPayMethodCredit),
              icon: const Icon(Icons.schedule_rounded),
            ),
            ButtonSegment(
              value: _PayMode.mixed,
              label: Text(l10n.sellPayMethodMixed),
              icon: const Icon(Icons.call_split_rounded),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) {
            setState(() {
              _mode = selection.first;
              _error = null;
              if (_mode == _PayMode.fullCash) {
                _cashController.text = _fmt(widget.grandTotal);
              } else if (_mode == _PayMode.mixed) {
                _cashController.text = _fmt(widget.grandTotal / 2);
              }
            });
          },
        ),
        const SizedBox(height: 8),
        if (_mode != _PayMode.fullCredit) ...[
          const SizedBox(height: 10),
          TextField(
            key: const Key('pur_pay_cash_field'),
            controller: _cashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,4}')),
            ],
            enabled: !_posting,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: l10n.purPayCashFieldLabel,
              suffixText: widget.currencyCode ?? '',
              helperText: l10n.purPayCashFieldHelper,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _SettlementPreview(
          grandTotal: widget.grandTotal,
          decimals: widget.decimals,
          netPaid: _mode == _PayMode.fullCredit ? 0 : settlement.netPaid,
          remainingCredit: _mode == _PayMode.fullCredit
              ? widget.grandTotal
              : settlement.remainingCredit,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          FinErrorCard(message: _error!),
        ],
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('pur_pay_confirm'),
          onPressed: _posting ? null : _confirm,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          child: _posting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Text(l10n.purPayConfirm),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _posting ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }

  // ── إيصال النجاح ───────────────────────────────────────────────────

  Widget _buildReceipt(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _dragHandle(Theme.of(context).colorScheme)),
        const SizedBox(height: 8),
        PostedPurchaseReceiptCard(
          receipt: _receipt!,
          currencyCode: widget.currencyCode,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('pur_receipt_new'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.post_add_rounded),
          label: Text(l10n.purReceiptNewInvoice),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonDone),
        ),
      ],
    );
  }

  static Widget _dragHandle(ColorScheme scheme) => Container(
    width: 44,
    height: 5,
    decoration: BoxDecoration(
      color: scheme.outlineVariant,
      borderRadius: BorderRadius.circular(999),
    ),
  );
}

/// رأس النافذة — الصافي كبير + رمز العملة + المورد.
class _TotalHeader extends StatelessWidget {
  const _TotalHeader({
    required this.grandTotal,
    required this.decimals,
    required this.currencyCode,
    required this.supplierName,
  });

  final double grandTotal;
  final int decimals;
  final String? currencyCode;
  final String? supplierName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return Column(
      children: [
        Text(
          l10n.sellPayNetTotalLabel,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AmountText(
              amount: grandTotal,
              size: AmountSize.display,
              decimals: decimals == 0 ? 0 : 2,
            ),
            if (currencyCode != null && currencyCode!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                currencyCode!,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: colors.gold, fontWeight: FontWeight.w800),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          supplierName ?? l10n.purSupplierRequired,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// معاينة التسوية الحية — المدفوع نقداً / المتبقي آجلاً (دين للمورد).
class _SettlementPreview extends StatelessWidget {
  const _SettlementPreview({
    required this.grandTotal,
    required this.decimals,
    required this.netPaid,
    required this.remainingCredit,
  });

  final double grandTotal;
  final int decimals;
  final double netPaid;
  final double remainingCredit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final d = decimals == 0 ? 0 : 2;
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _PreviewRow(
            label: l10n.sellPayNetPaid,
            value: netPaid,
            decimals: d,
            color: colors.positive,
          ),
          if (remainingCredit > 0)
            _PreviewRow(
              label: l10n.purReceiptSupplierCredit,
              value: remainingCredit,
              decimals: d,
              color: colors.warning,
            ),
          if (remainingCredit <= 0)
            _PreviewRow(
              label: l10n.sellPaySettledFully,
              value: null,
              decimals: d,
              color: colors.positive,
            ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    required this.decimals,
    required this.color,
  });

  final String label;
  final double? value;
  final int decimals;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          if (value != null)
            AmountText(
              amount: value!,
              decimals: decimals,
              showSignMarker: false,
            )
          else
            Icon(Icons.check_circle_rounded, size: 20, color: color),
        ],
      ),
    );
  }
}

