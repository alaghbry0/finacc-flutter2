/// نافذة رد قيمة المرتجع (SRN/PRN — FR-02-07/08) + إيصال نجاح المرتجع:
/// قيمة المرتجع كبيرة أعلى + اتجاه الرد (نقدي من الصندوق / خصم من حساب
/// الطرف / مختلط) + المبلغ النقدي المحدود بقيمة المرتجع (لا رد زائد) +
/// تأكيد الترحيل عبر `ReturnRepository` الذرّي.
/// الرسوم (النموذج/الإيصال/بطاقة النجاح) بملفاتها المركزّة بجوارها
/// (R20-D3b) — هذا الملف: آلة الحالة والتحقق والترحيل.
library;

import 'package:flutter/material.dart';

import '../../../../../data/repositories/return_repository.dart';
import '../../../../../domain/core/result.dart';
import '../../../../../domain/services/purchase_pricing.dart';
import '../../../../../l10n/app_localizations.dart';
import 'return_refund_form.dart';
import 'return_refund_receipt_view.dart';

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
  late ReturnRefundMode _mode;
  late final TextEditingController _cashController;
  bool _posting = false;
  String? _error;
  ReturnPostedReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    _mode = widget.cashOnly
        ? ReturnRefundMode.fullCash
        : ReturnRefundMode.fullCash;
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
      case ReturnRefundMode.fullCredit:
        return 0;
      case ReturnRefundMode.fullCash:
      case ReturnRefundMode.mixed:
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
      case ReturnRefundMode.fullCash:
        if (cash + moneyEpsilon < widget.refundTotal) {
          setState(
            () => _error = l10n.retRefundCashShort(
              widget.refundTotal.toStringAsFixed(2),
            ),
          );
          return null;
        }
      case ReturnRefundMode.fullCredit:
        break; // صفر نقدي — الخصم كله من الحساب.
      case ReturnRefundMode.mixed:
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
      ReturnRefundMode.fullCash => ReturnRefundMethod.cash,
      ReturnRefundMode.fullCredit => ReturnRefundMethod.credit,
      ReturnRefundMode.mixed => ReturnRefundMethod.mixed,
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

  // ── نموذج الرد / إيصال النجاح (عرضٌ بملفات مركزّة — المنطق هنا) ────

  Widget _buildRefundForm(BuildContext context) {
    final cash = _refundCash ?? 0;
    final netCash = cash > widget.refundTotal ? widget.refundTotal : cash;
    final credit = widget.refundTotal - netCash;

    return ReturnRefundForm(
      mode: _mode,
      cashController: _cashController,
      refundTotal: widget.refundTotal,
      decimals: widget.decimals,
      currencyCode: widget.currencyCode,
      partyLabel: widget.partyLabel,
      cashOnly: widget.cashOnly,
      netCash: netCash,
      credit: credit,
      error: _error,
      posting: _posting,
      onModeChanged: (mode) {
        setState(() {
          _mode = mode;
          _error = null;
          if (_mode == ReturnRefundMode.fullCash) {
            _cashController.text = _fmt(widget.refundTotal);
          } else if (_mode == ReturnRefundMode.mixed) {
            _cashController.text = _fmt(widget.refundTotal / 2);
          }
        });
      },
      onCashChanged: () {
        if (_error != null) setState(() => _error = null);
      },
      onConfirm: _confirm,
    );
  }

  Widget _buildReceipt(BuildContext context) {
    return ReturnRefundReceiptView(receipt: _receipt!);
  }
}
