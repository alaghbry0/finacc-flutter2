/// PaymentSheet (DS-40 / §6.5) — نافذة الدفع السفلية الملزمة:
/// الصافي كبير أعلى + الطرق (نقدي كامل / آجل كامل / مختلط) + المدفوع
/// نقداً والباقي للعميل بوضوح + رفض الآجل لعميل نقدي مجهول (بإيقاف
/// زرّي آجل/مختلط لا برفض بعد الضغط) + تأكيد الترحيل + إيصال نجاح
/// بأزرار طباعة/مشاركة فورية (P0-2 — `invoicing.print_on_save`).
/// الرسوم (الرأس/المعاينة/النموذج/الإيصال/حوار الائتمان) بملفاتها
/// المركزّة بجوارها (R19-D3b) — هذا الملف: آلة الحالة والتحقق والترحيل.
///
/// **17-c / FR-03-05**: بوابة حد الائتمان عند التأكيد — [creditGate]
/// (اختياري) يُستدعى قبل الترحيل بالجزء الآجل حصراً؛ عند التجاوز:
/// warn → حوار «متابعة على أي حال / إلغاء»، block → «رجوع» حصراً.
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../../../domain/core/result.dart';
import '../../../../../domain/models/sale.dart';
import '../../../../../domain/services/credit_limit.dart';
import '../../../../../domain/services/sale_pricing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../view_models/print_on_save.dart';
import 'payment_credit_limit_dialog.dart';
import 'payment_pay_form.dart';
import 'payment_receipt_view.dart';
import 'sell_format.dart';

/// يفتح PaymentSheet — يعيد `true` عند نجاح الترحيل.
///
/// [onConfirm] ينفّذ الترحيل الفعلي (postSale للسلة، أو convertToInvoice
/// لعرض السعر) ويعيد نتيجته كما هي — رسائل الرفض العربية تُعرض داخل
/// النافذة بلا فقد للسياق.
///
/// [creditGate] (FR-03-05، 17-c — اختياري): يُستدعى لحظة التأكيد عند
/// وجود جزء آجل ليجلب (الحد + الرصيد الجاري بعملة الفاتورة + سلوك
/// الإعداد `parties.credit_limit_action`)؛ قد يعيد null (لا عميل/
/// فشل قراءة) فتمر الفاتورة بلا فحص — المستودع يبقى الحارس الأخير.
///
/// [printOnSave] (P0-2 — إعداد `invoicing.print_on_save`): ask = زرا
/// الطباعة/المشاركة داخل بطاقة الإيصال؛ always = فتح المعاينة تلقائياً
/// بعد الترحيل؛ off = إخفاء الأزرار كلياً.
///
/// [openInvoicePreview] (اختياري): يفتح معاينة PDF للفاتورة المرحّلة
/// — المستدعي يمرر نمط الزر القائم (openInvoicePdfPreview من
/// invoice_pdf_preview.dart). غيابه يعني سلوك off للأزرار.
///
/// [initialPayMode] (UX-2a — `sale.default_payment`): الوضع الذي تُفتح
/// عليه النافذة (`cash`/`credit`/`mixed`) — آجل/مختلط بلا عميل يسقطان
/// إلى نقدي (P2-3)؛ الافتراضي cash (سلوك ما قبل التفضيل).
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
  Future<CreditLimitGate?> Function()? creditGate,
  PrintOnSaveMode printOnSave = PrintOnSaveMode.ask,
  String initialPayMode = 'cash',
  Future<void> Function(SalePostedReceipt receipt)? openInvoicePreview,
}) async {
  final posted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PaymentSheet(
      grandTotal: grandTotal,
      decimals: decimals,
      currencyCode: currencyCode,
      customerName: customerName,
      onConfirm: onConfirm,
      creditGate: creditGate,
      printOnSave: printOnSave,
      initialPayMode: initialPayMode,
      openInvoicePreview: openInvoicePreview,
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
    this.creditGate,
    this.printOnSave = PrintOnSaveMode.ask,
    this.initialPayMode = 'cash',
    this.openInvoicePreview,
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

  /// بوابة حد الائتمان (FR-03-05) — null بلا فحص (نقدي محض أو بلا عميل).
  final Future<CreditLimitGate?> Function()? creditGate;

  /// وضع الطباعة عند الحفظ (P0-2 — invoicing.print_on_save).
  final PrintOnSaveMode printOnSave;

  /// وضع الدفع الافتتاحي (UX-2a — sale.default_payment).
  final String initialPayMode;

  /// يفتح معاينة PDF للفاتورة المرحّلة (null = بلا طباعة).
  final Future<void> Function(SalePostedReceipt receipt)? openInvoicePreview;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  PaymentMode _mode = PaymentMode.fullCash;
  late final TextEditingController _cashController;
  bool _posting = false;
  String? _error;
  SalePostedReceipt? _receipt;

  /// منع فتح المعاينة تلقائياً أكثر من مرة (always — P0-2).
  bool _autoPreviewOpened = false;

  bool get _hasCustomer => widget.customerName != null;

  /// هل الطباعة متاحة أصلاً؟ (الوضع off أو غياب فاتح المعاينة = لا).
  bool get _printAvailable =>
      widget.printOnSave != PrintOnSaveMode.off &&
      widget.openInvoicePreview != null;

  @override
  void initState() {
    super.initState();
    // UX-2a — `sale.default_payment`: الوضع الافتتاحي من تفضيلات البيع؛
    // آجل/مختلط بلا عميل يسقطان إلى نقدي (P2-3 — النقدي المجهول يسدد
    // كاملاً حصراً فلا معنى لافتتاح معطّل).
    _mode = switch (widget.initialPayMode) {
      'credit' when widget.customerName != null => PaymentMode.fullCredit,
      'mixed' when widget.customerName != null => PaymentMode.mixed,
      _ => PaymentMode.fullCash,
    };
    // نقدي كامل يُملأ بالصافي؛ آجل/مختلط يبدآن من صفر (P2-2).
    _cashController = TextEditingController(
      text: _mode == PaymentMode.fullCash ? _fmt(widget.grandTotal) : '0',
    );
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
      case PaymentMode.fullCredit:
        return 0;
      case PaymentMode.fullCash:
      case PaymentMode.mixed:
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
      case PaymentMode.fullCash:
        if (paid + moneyEpsilon < widget.grandTotal) {
          setState(
            () => _error = l10n.sellPayCashShort(
              widget.grandTotal.toStringAsFixed(2),
            ),
          );
          return null;
        }
      case PaymentMode.fullCredit:
        if (!_hasCustomer) {
          setState(() => _error = l10n.sellPayCreditNeedsCustomer);
          return null;
        }
      case PaymentMode.mixed:
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
    // FR-03-05 (17-c): فحص حد الائتمان قبل الترحيل — **الجزء الآجل
    // حصراً** (الدفع المختلط يقيَّم بجزئه الآجل لا بكامل الصافي).
    if (!await _awaitCreditLimitApproval(paid)) return;
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
      _maybeAutoOpenPreview();
    } else {
      setState(() {
        _posting = false;
        _error = result.errorOrNull!;
      });
    }
  }

  /// always (P0-2): فتح معاينة PDF تلقائياً فور نجاح الترحيل — مرة
  /// واحدة لكل إيصال (الضغط اللاحق على الأزرار يعيد فتحها يدوياً).
  void _maybeAutoOpenPreview() {
    if (widget.printOnSave != PrintOnSaveMode.always) return;
    final opener = widget.openInvoicePreview;
    final receipt = _receipt;
    if (opener == null || receipt == null || _autoPreviewOpened) return;
    _autoPreviewOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(opener(receipt));
    });
  }

  /// يفتح معاينة PDF للإيصال الحالي (زرّا البطاقة + الزر الأساسي).
  Future<void> _openPreview() async {
    final opener = widget.openInvoicePreview;
    final receipt = _receipt;
    if (opener == null || receipt == null) return;
    await opener(receipt);
  }

  /// يشغّل بوابة الائتمان عند وجود جزء آجل — يعيد false إذا ألغى
  /// المستخدم أو كان السلوك block (لا متابعة). النقدي المحض يمر مباشرة.
  Future<bool> _awaitCreditLimitApproval(double paid) async {
    final gate = widget.creditGate;
    if (gate == null) return true;
    final settlement = settlePreview(widget.grandTotal, paid);
    final newDue = settlement.remainingCredit;
    if (newDue <= moneyEpsilon) return true;
    final CreditLimitGate? data;
    try {
      data = await gate();
    } catch (_) {
      // فشل قراءة البوابة لا يمنع البيع — المستودع حارس أخير.
      return true;
    }
    if (data == null) return true;
    final gateData = data;
    final decision = evaluateCreditLimit(
      creditLimit: gateData.creditLimit,
      action: gateData.action,
      currentBalance: gateData.currentBalance,
      newDue: newDue,
    );
    if (!decision.triggered) return true;
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: !decision.blocked,
          builder: (dialogContext) => PaymentCreditLimitDialog(
            decision: decision,
            gate: gateData,
            decimals: widget.decimals,
            currencyCode: widget.currencyCode,
            customerName: widget.customerName,
          ),
        ) ??
        false;
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

  // ── نموذج الدفع / إيصال النجاح (عرضٌ بملفات مركزّة — المنطق هنا) ────

  Widget _buildPayForm(BuildContext context) {
    final paid = _paidCash ?? 0;
    final settlement = settlePreview(widget.grandTotal, paid);

    return PaymentPayForm(
      mode: _mode,
      hasCustomer: _hasCustomer,
      cashController: _cashController,
      grandTotal: widget.grandTotal,
      decimals: widget.decimals,
      currencyCode: widget.currencyCode,
      customerName: widget.customerName,
      netPaid: _mode == PaymentMode.fullCredit ? 0 : settlement.netPaid,
      changeDue: _mode == PaymentMode.fullCredit ? 0 : settlement.changeDue,
      remainingCredit: _mode == PaymentMode.fullCredit
          ? widget.grandTotal
          : settlement.remainingCredit,
      error: _error,
      posting: _posting,
      onModeChanged: (mode) {
        setState(() {
          _mode = mode;
          _error = null;
          if (_mode == PaymentMode.fullCash) {
            _cashController.text = _fmt(widget.grandTotal);
          } else if (_mode == PaymentMode.mixed) {
            // P2-2: المختلط يبدأ من صفر لا من «نصف الصافي» الاعتباطي —
            // الكاشير يدخل المدفوع نقداً بنفسه والمعاينة الحية تتحدث معه.
            _cashController.text = '0';
          }
        });
      },
      onCashChanged: () {
        if (_error != null) setState(() => _error = null);
      },
      onConfirm: _confirm,
    );
  }

  // ── إيصال النجاح ───────────────────────────────────────────────────

  Widget _buildReceipt(BuildContext context) {
    return PaymentReceiptView(
      receipt: _receipt!,
      currencyCode: widget.currencyCode,
      printAvailable: _printAvailable,
      onOpenPreview: _openPreview,
    );
  }
}
