/// PaymentSheet (DS-40 / §6.5) — نافذة الدفع السفلية الملزمة:
/// الصافي كبير أعلى + الطرق (نقدي كامل / آجل كامل / مختلط) + المدفوع
/// نقداً والباقي للعميل بوضوح + رفض الآجل لعميل نقدي مجهول + تأكيد
/// الترحيل + إيصال نجاح مبسط بشارة «سعر صرف تقديري» عند fallback.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../domain/core/result.dart';
import '../../../../../domain/models/sale.dart';
import '../../../../../domain/services/sale_pricing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import 'sell_widgets.dart';

/// أنماط الدفع في النافذة.
enum _PayMode { fullCash, fullCredit, mixed }

/// يفتح PaymentSheet — يعيد `true` عند نجاح الترحيل.
///
/// [onConfirm] ينفّذ الترحيل الفعلي (postSale للسلة، أو convertToInvoice
/// لعرض السعر) ويعيد نتيجته كما هي — رسائل الرفض العربية تُعرض داخل
/// النافذة بلا فقد للسياق.
Future<bool> showPaymentSheet(
  BuildContext context, {
  required double grandTotal,
  required int decimals,
  required String? currencyCode,
  required String? customerName,
  required Future<Result<SalePostedReceipt, String>> Function(
    double paidCash,
    SalePaymentMethod method,
  )
  onConfirm,
}) async {
  final posted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) => _PaymentSheet(
      grandTotal: grandTotal,
      decimals: decimals,
      currencyCode: currencyCode,
      customerName: customerName,
      onConfirm: onConfirm,
    ),
  );
  return posted ?? false;
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.grandTotal,
    required this.decimals,
    required this.currencyCode,
    required this.customerName,
    required this.onConfirm,
  });

  final double grandTotal;
  final int decimals;
  final String? currencyCode;
  final String? customerName;
  final Future<Result<SalePostedReceipt, String>> Function(
    double paidCash,
    SalePaymentMethod method,
  )
  onConfirm;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  _PayMode _mode = _PayMode.fullCash;
  late final TextEditingController _cashController;
  bool _posting = false;
  String? _error;
  SalePostedReceipt? _receipt;

  bool get _hasCustomer => widget.customerName != null;

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
            () => _error = l10n.sellPayCashShort(
              widget.grandTotal.toStringAsFixed(2),
            ),
          );
          return null;
        }
      case _PayMode.fullCredit:
        if (!_hasCustomer) {
          setState(() => _error = l10n.sellPayCreditNeedsCustomer);
          return null;
        }
      case _PayMode.mixed:
        if (!_hasCustomer) {
          setState(() => _error = l10n.sellPayCreditNeedsCustomer);
          return null;
        }
        if (paid <= moneyEpsilon || paid + moneyEpsilon >= widget.grandTotal) {
          setState(
            () => _error = l10n.sellPayMixedRange(
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
    final method = SalePricing.derivePayStatus(widget.grandTotal, paid);
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
    final colors = FinColors.of(context);
    final paid = _paidCash ?? 0;
    final settlement = settlePreview(widget.grandTotal, paid);

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
          customerName: widget.customerName,
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
        if (!_hasCustomer)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: colors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.sellPayAnonymousCashOnly,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_mode != _PayMode.fullCredit) ...[
          const SizedBox(height: 10),
          TextField(
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
              labelText: l10n.sellPayCashFieldLabel,
              suffixText: widget.currencyCode ?? '',
              helperText: _mode == _PayMode.fullCash
                  ? l10n.sellPayCashFieldHelper
                  : null,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _SettlementPreview(
          grandTotal: widget.grandTotal,
          decimals: widget.decimals,
          netPaid: _mode == _PayMode.fullCredit ? 0 : settlement.netPaid,
          changeDue: _mode == _PayMode.fullCredit ? 0 : settlement.changeDue,
          remainingCredit: _mode == _PayMode.fullCredit
              ? widget.grandTotal
              : settlement.remainingCredit,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _ErrorCard(message: _error!),
        ],
        const SizedBox(height: 18),
        FilledButton(
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
              : Text(l10n.sellPayConfirm),
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
        PostedReceiptCard(
          receipt: _receipt!,
          currencyCode: widget.currencyCode,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.post_add_rounded),
          label: Text(l10n.sellReceiptNewInvoice),
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

/// رأس النافذة — الصافي كبير + رمز العملة + العميل.
class _TotalHeader extends StatelessWidget {
  const _TotalHeader({
    required this.grandTotal,
    required this.decimals,
    required this.currencyCode,
    required this.customerName,
  });

  final double grandTotal;
  final int decimals;
  final String? currencyCode;
  final String? customerName;

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
          customerName ?? l10n.sellPayWalkInCustomer,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// معاينة التسوية الحية — المدفوع نقداً / الباقي للعميل / المتبقي آجلاً.
class _SettlementPreview extends StatelessWidget {
  const _SettlementPreview({
    required this.grandTotal,
    required this.decimals,
    required this.netPaid,
    required this.changeDue,
    required this.remainingCredit,
  });

  final double grandTotal;
  final int decimals;
  final double netPaid;
  final double changeDue;
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
          if (changeDue > 0)
            _PreviewRow(
              label: l10n.sellReceiptChangeDue,
              value: changeDue,
              decimals: d,
              color: colors.warning,
              bold: true,
            ),
          if (remainingCredit > 0)
            _PreviewRow(
              label: l10n.sellReceiptRemainingCredit,
              value: remainingCredit,
              decimals: d,
              color: colors.warning,
            ),
          if (changeDue <= 0 && remainingCredit <= 0)
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
    this.bold = false,
  });

  final String label;
  final double? value;
  final int decimals;
  final Color color;
  final bool bold;

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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
              ),
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

/// بطاقة الخطأ الحمراء — رسالة الرفض العربية كاملة (لا تُختصر).
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    return FinCard(
      padding: const EdgeInsets.all(14),
      accent: colors.negative,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.negative, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
