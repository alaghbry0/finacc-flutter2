/// نافذة رد قيمة المرتجع (SRN/PRN — FR-02-07/08) + إيصال نجاح المرتجع:
/// قيمة المرتجع كبيرة أعلى + اتجاه الرد (نقدي من الصندوق / خصم من حساب
/// الطرف / مختلط) + المبلغ النقدي المحدود بقيمة المرتجع (لا رد زائد) +
/// تأكيد الترحيل عبر `ReturnRepository` الذرّي.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../data/repositories/return_repository.dart';
import '../../../../../domain/core/result.dart';
import '../../../../../domain/services/purchase_pricing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/fin_error_card.dart';
import '../../../../core/widgets/status_chip.dart';

/// أنماط رد القيمة في النافذة.
enum _RefundMode { fullCash, fullCredit, mixed }

/// يفتح نافذة رد قيمة المرتجع — يعيد `true` عند نجاح الترحيل.
///
/// [cashOnly] يفرض الرد النقدي حصراً (فاتورة بيع أصلية بعميل مجهول —
/// لا حساب يُخصم منه).
Future<bool> showReturnRefundSheet(
  BuildContext context, {
  required double refundTotal,
  required int decimals,
  required String? currencyCode,
  required String partyLabel,
  required bool cashOnly,
  required Future<Result<ReturnPostedReceipt, String>> Function(
    double refundCash,
    ReturnRefundMethod method,
  )
  onConfirm,
}) async {
  final posted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) => _ReturnRefundSheet(
      refundTotal: refundTotal,
      decimals: decimals,
      currencyCode: currencyCode,
      partyLabel: partyLabel,
      cashOnly: cashOnly,
      onConfirm: onConfirm,
    ),
  );
  return posted ?? false;
}

class _ReturnRefundSheet extends StatefulWidget {
  const _ReturnRefundSheet({
    required this.refundTotal,
    required this.decimals,
    required this.currencyCode,
    required this.partyLabel,
    required this.cashOnly,
    required this.onConfirm,
  });

  final double refundTotal;
  final int decimals;
  final String? currencyCode;
  final String partyLabel;
  final bool cashOnly;
  final Future<Result<ReturnPostedReceipt, String>> Function(
    double refundCash,
    ReturnRefundMethod method,
  )
  onConfirm;

  @override
  State<_ReturnRefundSheet> createState() => _ReturnRefundSheetState();
}

class _ReturnRefundSheetState extends State<_ReturnRefundSheet> {
  late _RefundMode _mode;
  late final TextEditingController _cashController;
  bool _posting = false;
  String? _error;
  ReturnPostedReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    _mode = widget.cashOnly ? _RefundMode.fullCash : _RefundMode.fullCash;
    _cashController = TextEditingController(text: _fmt(widget.refundTotal));
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  static String _fmt(double value) => value == value.truncateToDouble()
      ? value.truncate().toString()
      : value.toStringAsFixed(2);

  double? get _refundCash {
    switch (_mode) {
      case _RefundMode.fullCredit:
        return 0;
      case _RefundMode.fullCash:
      case _RefundMode.mixed:
        final raw = _cashController.text.trim().replaceAll(',', '.');
        if (raw.isEmpty) return null;
        return double.tryParse(raw);
    }
  }

  /// المبلغ الصالح — أو null مع سبب في [_error].
  double? _validatedRefundCash() {
    final l10n = AppLocalizations.of(context)!;
    final cash = _refundCash;
    if (cash == null || cash.isNaN || cash.isInfinite || cash < 0) {
      setState(() => _error = l10n.sellPayInvalidAmount);
      return null;
    }
    switch (_mode) {
      case _RefundMode.fullCash:
        if (cash + moneyEpsilon < widget.refundTotal) {
          setState(
            () => _error = l10n.retRefundCashShort(
              widget.refundTotal.toStringAsFixed(2),
            ),
          );
          return null;
        }
      case _RefundMode.fullCredit:
        break; // صفر نقدي — الخصم كله من الحساب.
      case _RefundMode.mixed:
        if (cash <= moneyEpsilon || cash + moneyEpsilon >= widget.refundTotal) {
          setState(
            () => _error = l10n.retRefundMixedRange(
              widget.refundTotal.toStringAsFixed(2),
            ),
          );
          return null;
        }
    }
    return cash;
  }

  Future<void> _confirm() async {
    final cash = _validatedRefundCash();
    if (cash == null) return;
    final method = switch (_mode) {
      _RefundMode.fullCash => ReturnRefundMethod.cash,
      _RefundMode.fullCredit => ReturnRefundMethod.credit,
      _RefundMode.mixed => ReturnRefundMethod.mixed,
    };
    setState(() {
      _posting = true;
      _error = null;
    });
    final result = await widget.onConfirm(cash, method);
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
              ? _buildRefundForm(context)
              : _buildReceipt(context),
        ),
      ),
    );
  }

  // ── نموذج الرد ─────────────────────────────────────────────────────

  Widget _buildRefundForm(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final cash = _refundCash ?? 0;
    final netCash = cash > widget.refundTotal ? widget.refundTotal : cash;
    final credit = widget.refundTotal - netCash;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _dragHandle(scheme)),
        const SizedBox(height: 12),
        Column(
          children: [
            Text(
              l10n.retRefundTotalLabel,
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
                  amount: widget.refundTotal,
                  size: AmountSize.display,
                  decimals: widget.decimals == 0 ? 0 : 2,
                ),
                if (widget.currencyCode != null &&
                    widget.currencyCode!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.currencyCode!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.partyLabel,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 18),
        SegmentedButton<_RefundMode>(
          segments: [
            ButtonSegment(
              value: _RefundMode.fullCash,
              label: Text(l10n.retRefundCash),
              icon: const Icon(Icons.payments_rounded),
            ),
            ButtonSegment(
              value: _RefundMode.fullCredit,
              label: Text(l10n.retRefundCredit),
              icon: const Icon(Icons.account_balance_wallet_rounded),
            ),
            if (!widget.cashOnly)
              ButtonSegment(
                value: _RefundMode.mixed,
                label: Text(l10n.sellPayMethodMixed),
                icon: const Icon(Icons.call_split_rounded),
              ),
          ],
          selected: {_mode},
          onSelectionChanged: widget.cashOnly
              ? null
              : (selection) {
                  setState(() {
                    _mode = selection.first;
                    _error = null;
                    if (_mode == _RefundMode.fullCash) {
                      _cashController.text = _fmt(widget.refundTotal);
                    } else if (_mode == _RefundMode.mixed) {
                      _cashController.text = _fmt(widget.refundTotal / 2);
                    }
                  });
                },
        ),
        const SizedBox(height: 8),
        if (widget.cashOnly)
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
                    l10n.retRefundCashOnlyNote,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_mode != _RefundMode.fullCredit) ...[
          const SizedBox(height: 10),
          TextField(
            key: const Key('ret_refund_cash_field'),
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
              labelText: l10n.retRefundCashFieldLabel,
              suffixText: widget.currencyCode ?? '',
            ),
          ),
        ],
        const SizedBox(height: 14),
        FinCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _PreviewRow(
                label: l10n.retReceiptRefundCash,
                value: _mode == _RefundMode.fullCredit ? 0 : netCash,
                decimals: widget.decimals == 0 ? 0 : 2,
              ),
              if (credit > 0)
                _PreviewRow(
                  label: l10n.retReceiptRefundCredit,
                  value: credit,
                  decimals: widget.decimals == 0 ? 0 : 2,
                ),
              if (credit <= 0)
                _PreviewRow(
                  label: l10n.sellPaySettledFully,
                  value: null,
                  decimals: widget.decimals == 0 ? 0 : 2,
                ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          FinErrorCard(message: _error!),
        ],
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('ret_refund_confirm'),
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
              : Text(l10n.retPostButton),
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
        PostedReturnReceiptCard(receipt: _receipt!),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('ret_receipt_new'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.post_add_rounded),
          label: Text(l10n.retNewReturn),
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

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    required this.decimals,
  });

  final String label;
  final double? value;
  final int decimals;

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
            const Icon(Icons.check_circle_rounded, size: 20),
        ],
      ),
    );
  }
}


/// إيصال نجاح ترحيل المرتجع — SRN/PRN/الفاتورة الأصلية/قيمة الرد نقدياً
/// ومن الحساب + شارة السعر التقديري عند fallback (FR-02-20).
class PostedReturnReceiptCard extends StatelessWidget {
  const PostedReturnReceiptCard({super.key, required this.receipt});

  final ReturnPostedReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final docLabel = receipt.docType == 'SRN'
        ? l10n.retSaleTitle
        : l10n.retPurchaseTitle;
    return FinCard(
      accent: colors.positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.positiveContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: colors.onPositiveContainer,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.retReceiptSuccessTitle,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${receipt.docNo} · $docLabel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFeatures: FinText.tabularNums,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (receipt.originalInvoiceNo != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.retReceiptOriginal(receipt.originalInvoiceNo!),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: FinText.tabularNums,
              ),
            ),
          ],
          if (receipt.rateIsFallback) ...[
            const SizedBox(height: 12),
            StatusChip(
              label: l10n.sellFallbackRateBadge,
              tone: ChipTone.warning,
              icon: Icons.price_change_rounded,
              dense: false,
            ),
          ],
          const SizedBox(height: 14),
          _ReceiptRow(
            label: l10n.retRefundTotalLabel,
            value: receipt.refundTotal,
          ),
          _ReceiptRow(
            label: l10n.retReceiptRefundCash,
            value: receipt.refundCash,
            sign: FinSign.outgoing,
          ),
          if (receipt.refundCredit > 0)
            _ReceiptRow(
              label: l10n.retReceiptRefundCredit,
              value: receipt.refundCredit,
              sign: FinSign.outgoing,
            ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
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
