/// محرك ترحيل المرتجعات المرتبطة الذرّي — SRN (مرتجع بيع، FR-02-07) و
/// PRN (مرتجع شراء، FR-02-08) — جداول `invoice` (doc_type='sale_return'/
/// 'purchase_return' مع `original_invoice_id`) / `invoice_item` / `batch` /
/// `stock_level` / `stock_movement` / `cash_tx` / `payment_allocation`.
///
/// **الخريطة الملزمة** (قاعدة 5.4-4 + ملحق و): الحفظ = (رقم SRN/PRN ذرّي +
/// الفاتورة المرتبطة + بنودها بكميات وتكاليف **Snapshot من الفاتورة
/// الأصلية** + حركات المخزون + حركة الصندوق للجزء النقدي + التخصيص +
/// قيد التدقيق) داخل **Transaction واحدة** — فشل أي خطوة يرجع الكل.
///
/// خطوط حمراء مطبَّقة هنا:
/// - **الارتباط الحصري** (FR-02-07): لا مرتجع حر — `original_invoice_id`
///   إلزامي، والنوع يجب أن يطابق (SRN عن فاتورة بيع، PRN عن فاتورة شراء)،
///   والحالة `completed` حصراً (الملغاة `void` والمسودة `draft` مرفوضتان).
/// - **مرتجع البيع بتكلفة line_cost الأصلية** (قاعدة 5.4-3): الكمية تعود
///   للمخزون **بالتكلفة الأصلية المنقولة** — WAC الجاري لا يُلمس إطلاقاً.
/// - **مرتجع الشراء بسعر حركة الشراء الأصلية (Snapshot)** (FR-02-08): الخروج
///   بتكلفة الوحدة الأصلية (`line_cost الأصلي / الكمية`) ويُعاد حساب WAC
///   على المتبقي: `WAC = (qty_old×cost_old − qty_ret×cost_snapshot) /
///   (qty_old − qty_ret)` مع حماية القسمة (المتبقي ≤ 0 → التكلفة 0) وعدم
///   السماح بتكلفة سالبة.
/// - **سقف الكميات**: مجموع مرتجعات الفاتورة ≤ المباع/المشترى لكل بند —
///   يفحص قبل المعاملة ويعاد فحصه داخلها (حراسة التزامن).
/// - **منع السالب المخزوني** (5.4-5): PRN يرفض ما لا يغطيه المخزون
///   (stock_level للعادي، ومجموع الدفعات للمتتبع) برسالة تسمّي الصنف.
///
/// ## قرارات موثقة (انظر worklog-parts/7-b.md للتفصيل):
/// 1. **مرجع البند الأصلي**: المخطط المجمد بلا عمود `original_item_id` في
///    `invoice_item` — يُخزَّن المرجع بعلامة قياسية موثَّقة داخل عمود
///    `notes` بصيغة «أصل البند #معرّف» (يكتبها ويقرؤها هذا المحرك حصراً
///    بتعبير نمطي ثابت) — أساس حساب «المتبقي للإرجاع» لكل بند. طلب عمود
///    مخصص مسجَّل للمنسّق.
/// 2. **اتجاه المبلغ** (FR-02-07/08): `credit` = خصم من حساب الطرف عبر
///    `invoice.due_amount` للمستند المرتجع — صيغتا رصيد العميل (FR-03-02)
///    والمورد (FR-03-03) تطرحان `due_amount` لمستندات المرتجع تلقائياً
///    فتنقصان الدين بلا أي كتابة إضافية، وكشف الحساب يظهر قيد المرتجع
///    (−) صحيحاً. `cash` = رد نقدي من/إلى الصندوق (`cash_tx` باتجاه معاكس
///    للفاتورة الأصلية: SRN سند **صرف** للعميل، PRN سند **قبض** من
///    المورد) + **تخصيص مدفوعات عكسي** (`payment_allocation` يوثّق الجزء
///    النقدي المرتجع كما يوثّق نظيره وقت الإصدار). `mixed` بينهما. سند
///    SRN النقدي يُكتب بـ `customer_id = NULL` وسند PRN النقدي بـ
///    `supplier_id = NULL` — مرآة اصطلاح الإصدار (لا خصم مزدوج من رصيد
///    الطرف). لا رد زائد: المبلغ النقدي محصور بين 0 وقيمة المرتجع.
/// 3. **الدفعات في مرتجع البيع (SRN)**: الكمية تعود إلى **دفعات الفاتورة
///    الأصلية نفسها** — يُتبَّع الاستهلاك الأصلي من حركات مخزون البيع
///    (`stock_movement` بحركة لكل دفعة برجوع للفاتورة، وملاحظتها تحمل
///    «رقم الدفعة X (تنتهي Y)» — نفس صيغة `sale_repository` حرفياً)،
///    والسعة لكل دفعة = ما استُهلك منها في البيع الأصلي − ما أُعيد إليها
///    سابقاً (حركات SRN سابقة بنفس الصيغة) — فلا تتجاوز كمية أي دفعة ما
///    استُهلك منها أبداً، والبنود المتعددة لنفس الصنف في مرتجع واحد
///    تتقاسم السعات في الذاكرة. **أي كمية متبقية بلا دفعة قابلة للتتبع
///    (دفعة مؤرشفة/محذوفة أو استهلاك غير موثَّق) تضاف للمخزون العام بلا
///    دفعة** مع تعليق موثَّق في ملاحظة السطر (وفق التكليف) — ملاحظة:
///    رصيد المتتبعين بلا دفعة لا يظهر متاحاً للبيع (فحص توفر البيع يعدّ
///    الدفعات النشطة فقط) حتى شراء لاحق بدفعة.
/// 4. **الدفعات في مرتجع الشراء (PRN)**: الخصم من **الدفعة الواردة
///    الأصلية** أولاً (`invoice_item.batch_id` الذي خزّنه postPurchase لكل
///    بند) ثم أي متبقٍ بدفعات الصنف النشطة FEFO (`allocateFefo` بـ
///    includeExpired — إرجاع البضاعة المنتهية للمورد جائز)؛ وإن لم تكفِ
///    الدفعات فالعملية **تُرفض** (المتتبع مخزونه في دفعاته — خصم بلا
///    دفعة يفسد نسبة الدفعات إلى stock_level).
/// 5. **عملة المرتجع وسعره**: عملة المستند المرتجع = عملة الفاتورة
///    الأصلية حصراً (حتى يخصم/يرد على الرصيد الصحيح بعملته — 5.4-7)،
///    وسعر صرفه يُحل وفق FR-08-09 بتاريخ إصدار المرتجع (الرفض أو
///    `fx.fallback` بعلم) — **قيمة المخزون لا تُحوَّل بسعر يوم المرتجع**
///    بل تُنقل من `line_cost` الأصلي (Snapshot بالعملة الأساسية).
/// 6. **مبلغ المرتجع**: لكل بند — `gross = round2(qty_ret × unit_price
///    الأصلي)` وخصم تناسبي `round2(qty_ret × discount_amount الأصلي /
///    qty الأصلية)` فـ `line_total = gross − الخصم` — استرداد تناسبي
///    تام لما دُفع فعلاً عن الوحدات المرتجعة (بما فيها نصيبها من خصم
///    الرأس الموزَّع وقت الشراء/البيع المخزَّن في `discount_amount`).
/// 7. **المخزن**: حركات المرتجع على مخزن الفاتورة الأصلية حصراً (حيث
///    خرجت/دخلت البضاعة أصلاً).
library;

import 'package:sqflite/sqflite.dart';

import '../../core/storage/doc_sequence.dart';
import '../../domain/core/result.dart';
import '../../domain/services/purchase_pricing.dart';
import 'batch_repository.dart';
import 'exchange_rate_repository.dart';
import 'settings_repository.dart';

/// فشل تدفق داخلي برسالة عربية نظيفة — رميه داخل المعاملة يتراجعها
/// كاملة (لا `return Err` داخلها أبداً بعد أول كتابة).
class _FlowError implements Exception {
  const _FlowError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// علامة مرجع البند الأصلي داخل `invoice_item.notes` (القرار 1) —
/// تُقرأ/تُكتب بصيغة «أصل البند #&lt;id&gt;».
final RegExp _originItemPattern = RegExp(r'أصل البند #(\d+)');

/// صيغة ملاحظة حركة الدفعة — نفس صيغة `sale_repository` حرفياً (القرار 3).
final RegExp _batchNotePattern = RegExp(
  r'رقم الدفعة (.+?) \(تنتهي (\d{4}-\d{2}-\d{2})\)',
);

/// تفاوت الكميات (NUMERIC(12,3) بالمخطط).
const double _qtyEpsilon = 0.000001;

// ─────────────────────────────────────────────────────────────────────
// نماذج المرتجعات (مدخلات/مخرجات المستودع — نماذج نقية)
// ─────────────────────────────────────────────────────────────────────

/// اتجاه رد قيمة المرتجع (FR-02-07 / FR-02-08) — الرمز يطابق عمود
/// `invoice.pay_status` (cash/credit/mixed).
enum ReturnRefundMethod {
  /// رد نقدي كامل من/إلى الصندوق (SRN: صرف للعميل — PRN: قبض من المورد).
  cash('cash'),

  /// خصم كامل من حساب الطرف (SRN: رصيد العميل — PRN: دين المورد).
  credit('credit'),

  /// جزء نقدي وجزء على الحساب.
  mixed('mixed');

  const ReturnRefundMethod(this.code);
  final String code;
}

/// بند مرتجع واحد — مرجع مباشر لبند الفاتورة الأصلية + الكمية المرتجعة.
class ReturnLineInput {
  const ReturnLineInput({required this.invoiceItemId, required this.qty});

  /// بند الفاتورة الأصلية (`invoice_item.id`).
  final int invoiceItemId;

  /// الكمية المرجعة (> 0 وتقع ضمن المتبقي القابل للإرجاع).
  final double qty;
}

/// مسوّدة مرتجع بيع (SRN) — مرتبطة حصراً بفاتورة بيع أصلية.
class SaleReturnDraft {
  const SaleReturnDraft({
    required this.originalInvoiceId,
    required this.lines,
    this.refundCash = 0,
    this.refundMethod = ReturnRefundMethod.cash,
    required this.issuedAt,
    this.notesInternal,
    this.notesPrinted,
  });

  /// الفاتورة الأصلية (doc_type='sale' وحالة completed).
  final int originalInvoiceId;

  /// البنود المرتجعة (≥ 1).
  final List<ReturnLineInput> lines;

  /// المبلغ النقدي المردود فوراً (0 = كله على حساب العميل).
  final double refundCash;

  /// اتجاه رد القيمة المعلن (يجب أن يطابق الأرقام).
  final ReturnRefundMethod refundMethod;

  /// تاريخ إصدار المرتجع (يحدد سعر الصرف وسنة الترقيم).
  final DateTime issuedAt;

  final String? notesInternal;
  final String? notesPrinted;
}

/// مسوّدة مرتجع شراء (PRN) — مرتبطة حصراً بفاتورة شراء أصلية.
class PurchaseReturnDraft {
  const PurchaseReturnDraft({
    required this.originalInvoiceId,
    required this.lines,
    this.refundCash = 0,
    this.refundMethod = ReturnRefundMethod.cash,
    required this.issuedAt,
    this.notesInternal,
    this.notesPrinted,
  });

  /// الفاتورة الأصلية (doc_type='purchase' وحالة completed).
  final int originalInvoiceId;

  final List<ReturnLineInput> lines;

  /// المبلغ النقدي المسترد فوراً من المورد (0 = كله خصم من دينه).
  final double refundCash;

  final ReturnRefundMethod refundMethod;
  final DateTime issuedAt;
  final String? notesInternal;
  final String? notesPrinted;
}

/// إيصال مرتجع مُرحَّل — مخرج postSaleReturn/postPurchaseReturn.
class ReturnPostedReceipt {
  const ReturnPostedReceipt({
    required this.invoiceId,
    required this.docNo,
    required this.docType,
    required this.originalInvoiceId,
    required this.originalInvoiceNo,
    required this.refundTotal,
    required this.refundCash,
    required this.refundCredit,
    required this.payStatus,
    required this.exchangeRate,
    required this.rateIsFallback,
  });

  /// معرّف صف الفاتورة المرتجعة.
  final int invoiceId;

  /// الرقم الكامل `SRN-YYYY-NNNNN` / `PRN-YYYY-NNNNN`.
  final String docNo;

  /// 'SRN' أو 'PRN'.
  final String docType;

  final int originalInvoiceId;
  final String? originalInvoiceNo;

  /// قيمة المرتجع بعملة الفاتورة الأصلية.
  final double refundTotal;

  /// الجزء النقدي المردود الآن.
  final double refundCash;

  /// الجزء المخصوم من حساب الطرف (`invoice.due_amount`).
  final double refundCredit;

  /// حالة الرد المخزَّنة (cash/credit/mixed).
  final ReturnRefundMethod payStatus;

  final double exchangeRate;
  final bool rateIsFallback;
}

/// بند قابل للإرجاع — سطر جاهز لواجهة اختيار المرتجع لاحقاً.
class ReturnableLine {
  const ReturnableLine({
    required this.invoiceItemId,
    required this.productId,
    required this.lineDesc,
    required this.originalQty,
    required this.returnedQty,
    required this.availableQty,
    required this.unitPrice,
    required this.unitPriceEffective,
    required this.unitCostSnapshot,
    this.batchId,
  });

  /// بند الفاتورة الأصلية — مفتاح `ReturnLineInput.invoiceItemId`.
  final int invoiceItemId;
  final int? productId;
  final String? lineDesc;

  /// الكمية الأصلية (المباعة أو المشتراة).
  final double originalQty;

  /// ما أُرجع منها سابقاً (مرتجعات مكتملة).
  final double returnedQty;

  /// المتاح للإرجاع = originalQty − returnedQty.
  final double availableQty;

  /// سعر/تكلفة الوحدة الأصلية بعملة الفاتورة (`unit_price`).
  final double unitPrice;

  /// صافي ما دُفع عن الوحدة بعملة الفاتورة (line_total/qty) — أساس الرد.
  final double unitPriceEffective;

  /// تكلفة الوحدة Snapshot بالعملة الأساسية (line_cost/qty) — أساس
  /// تقييم حركة المخزون للمرتجع.
  final double unitCostSnapshot;

  /// الدفعة الأصلية للبند (للمشتريات المتتبعة).
  final int? batchId;
}

// ─────────────────────────────────────────────────────────────────────
// المستودع
// ─────────────────────────────────────────────────────────────────────

/// مستودع المرتجعات — SRN وPRN المرتبطة حصراً + بنود الإرجاع المتاحة.
class ReturnRepository {
  /// يبنى فوق قاعدة مفتوحة؛ يركّب المستودعات الشريكة فوق نفس القاعدة.
  ReturnRepository(Database db)
    : _db = db,
      _rates = ExchangeRateRepository(db),
      _settings = SettingsRepository(db),
      _batches = BatchRepository(db);

  final Database _db;
  final ExchangeRateRepository _rates;
  final SettingsRepository _settings;
  final BatchRepository _batches;

  // ───────────────────────────────────────────────────────────────────
  // مرتجع البيع (SRN) — FR-02-07
  // ───────────────────────────────────────────────────────────────────

  /// **ترحيل مرتجع بيع مرتبط** — معاملة واحدة (انظر رأس الملف).
  ///
  /// الكمية تعود لمخزن الفاتورة الأصلية **بتكلفة line_cost الأصلية**
  /// (لا WAC الجاري — قاعدة 5.4-3) وإلى دفعات البيع الأصلية عند تتبعها
  /// (القرار 3)، والقيمة تُرد نقداً من الصندوق أو خصماً من حساب العميل
  /// (القرار 2).
  Future<Result<ReturnPostedReceipt, String>> postSaleReturn(
    SaleReturnDraft draft, {
    required int userId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final issuedAt = draft.issuedAt;
    final issuedIso = issuedAt.toUtc().toIso8601String();

    // (1) تحقق نقي من البنود — قبل أي قراءة/كتابة.
    final linesFailure = _validateLines(draft.lines);
    if (linesFailure != null) return Err(linesFailure);

    try {
      // (2) الفاتورة الأصلية: نوع + حالة + وجود (FR-02-07).
      final orig = await _loadOriginal(draft.originalInvoiceId, 'sale');
      if (orig.error != null) return Err(orig.error!);

      // (3) البنود الأصلية + المنتسب + سقف الكميات (القرار 1).
      final membership = await _checkMembershipAndCaps(
        draft.originalInvoiceId,
        'sale_return',
        draft.lines,
      );
      if (membership.error != null) return Err(membership.error!);
      final origItems = membership.items;

      // (4) قيمة المرتجع Snapshot من البنود الأصلية (القرار 6).
      final valued = _valueReturnLines(origItems, draft.lines);
      final refundTotal = valued.refundTotal;

      // (5) اتجاه الرد مقابل الأرقام (القرار 2).
      final refundFailure = _validateRefund(
        refundTotal,
        draft.refundCash,
        draft.refundMethod,
      );
      if (refundFailure != null) return Err(refundFailure);
      final settlement = _settleRefund(refundTotal, draft.refundCash);
      final refundCash = settlement.netCash;
      final refundCredit = settlement.credit;

      // (6) حساب العميل للجزء المخصوم (FR-02-07: اتجاه المبلغ).
      if (refundCredit > moneyEpsilon && orig.row['customer_id'] == null) {
        return Err(
          'الفاتورة الأصلية بلا عميل مسجَّل (بيع نقدي مجهول) — لا حساب '
          'يُخصم منه؛ اختر رد القيمة نقداً من الصندوق.',
        );
      }

      // (7) سياسة FX بعملة الفاتورة الأصلية بتاريخ المرتجع (القرار 5).
      final fx = await _resolveRate(
        orig.row['currency_id'] as int,
        issuedAt,
      );
      if (fx.error != null) return Err(fx.error!);

      // (8) الصندوق الافتراضي — للجزء النقدي فقط.
      int? cashboxId;
      if (refundCash > moneyEpsilon) {
        final boxId = await _defaultCashboxId();
        if (boxId == null) {
          return Err('لا يوجد صندوق افتراضي للمنشأة — أنشئ صندوقاً أولاً.');
        }
        cashboxId = boxId;
      }

      // (9) معلومات الأصناف (خدمي/متتبع).
      final products = await _loadProductsForItems(origItems);

      // (10) المعاملة الواحدة — كل الكتابات أو لا شيء (5.4-4).
      return await _db.transaction((txn) async {
        // 10-أ) رقم SRN ذرّي (قاعدة 5.4-1).
        final year = issuedAt.year;
        final seq = DocSequenceService(txn);
        final number = await seq.nextNumber(DocSequenceType.saleReturn, year);
        final docNo = formatDocNumber(DocSequenceType.saleReturn, year, number);

        // 10-ب) رأس المرتجع (كل الأعمدة وفق §5.3) — الارتباط الحصري.
        final invoiceId = await txn.insert('invoice', {
          'invoice_no': docNo,
          'doc_type': 'sale_return',
          'pay_status': settlement.method.code,
          'status': 'completed',
          'issued_at': issuedIso,
          'original_invoice_id': draft.originalInvoiceId,
          'customer_id': orig.row['customer_id'],
          'cashbox_id': cashboxId,
          'warehouse_id': orig.row['warehouse_id'],
          'currency_id': orig.row['currency_id'],
          'exchange_rate': fx.rate,
          'rate_is_fallback': fx.isFallback ? 1 : 0,
          'subtotal': valued.subtotal,
          'discount_amount': valued.discountTotal,
          'tax_rate': 0,
          'tax_amount': 0,
          'total': refundTotal,
          'total_base': roundCost(refundTotal * fx.rate),
          'paid_amount': refundCash,
          'due_amount': refundCredit,
          'cost_total': valued.costTotal,
          'notes_internal': draft.notesInternal,
          'notes_printed': draft.notesPrinted,
          'created_at': at.toUtc().toIso8601String(),
          'updated_at': at.toUtc().toIso8601String(),
          'created_by': userId,
        });

        // 10-ج) حرارة السقف داخل المعاملة (التزامن — القرار 1).
        await _assertCapsInside(
          txn,
          draft.originalInvoiceId,
          'sale_return',
          draft.lines,
        );

        // 10-د) البنود: تكلفة أصلية منقولة + عودة الكمية للمخزون
        //       (ودفعات البيع الأصلية — القرار 3). سعات الدفعات تُحمَّل
        //       مرة لكل صنف وتتقاسمها البنود في الذاكرة.
        final batchCaps = <int, List<_BatchCap>>{};
        for (var i = 0; i < draft.lines.length; i++) {
          final input = draft.lines[i];
          final origItem = origItems[input.invoiceItemId]!;
          final productId = origItem['product_id'] as int?;
          final info = productId == null ? null : products[productId];
          final lineQty = input.qty;

          // Snapshot تكلفة الوحدة الأصلية (بالعملة الأساسية).
          final snapshotUnit = roundCost(
            (origItem['line_cost'] as num? ?? 0) /
                (origItem['qty'] as num? ?? 1),
          );
          final lineCost = roundCost(lineQty * snapshotUnit);

          // سعات دفعات الصنف (استهلاك البيع الأصلي − ما أُعيد سابقاً).
          List<_BatchCap>? caps;
          if (info != null && info.trackBatches && productId != null) {
            var productCaps = batchCaps[productId];
            if (productCaps == null) {
              productCaps = await _loadBatchReturnCaps(
                txn,
                productId: productId,
                warehouseId: orig.row['warehouse_id'] as int,
                originalInvoiceId: draft.originalInvoiceId,
              );
              batchCaps[productId] = productCaps;
            }
            caps = productCaps;
          }

          // تخصيص عودة هذا البند على السعات.
          final entries = <_BatchCap>[];
          var remaining = lineQty;
          if (caps != null) {
            for (final cap in caps) {
              if (remaining <= _qtyEpsilon) break;
              if (cap.qty <= _qtyEpsilon) continue;
              final take = cap.qty < remaining ? cap.qty : remaining;
              entries.add(
                _BatchCap(
                  batchId: cap.batchId,
                  batchNumber: cap.batchNumber,
                  expiryDate: cap.expiryDate,
                  qty: take,
                ),
              );
              cap.qty = roundCost(cap.qty - take);
              remaining = roundCost(remaining - take);
            }
          }
          final residual = roundCost(remaining);

          final batchSummary = entries.isEmpty
              ? null
              : entries.map((e) => '${e.batchNumber}×${_num(e.qty)}').join('، ');
          final lineNotes = [
            'أصل البند #${input.invoiceItemId}',
            if (batchSummary != null) 'دفعة: $batchSummary',
            if (residual > _qtyEpsilon)
              'مرتجع بلا دفعة (${_num(residual)} أضيف للمخزون العام)',
          ].join(' — ');

          await txn.insert('invoice_item', {
            'invoice_id': invoiceId,
            'product_id': productId,
            'line_desc': origItem['line_desc'],
            'qty': lineQty,
            'unit_id': origItem['unit_id'],
            'unit_factor': 1,
            'unit_price': origItem['unit_price'],
            'discount_percent': origItem['discount_percent'],
            'discount_amount': valued.discounts[i],
            'tax_percent': 0,
            'line_total': valued.lineTotals[i],
            'line_cost': lineCost, // التكلفة الأصلية منقولة (5.4-3).
            'batch_id': entries.isNotEmpty ? entries.first.batchId : null,
            'notes': lineNotes,
            'created_at': at.toUtc().toIso8601String(),
          });

          // الخدمي: لا مخزون (FR-01-16).
          if (info == null || info.isService || productId == null) continue;

          // زيادة الدفعات + حركة لكل دفعة (القرار 3).
          for (final entry in entries) {
            await txn.rawUpdate(
              'UPDATE batch SET qty = qty + ?, updated_at = ? WHERE id = ?',
              [entry.qty, at.toUtc().toIso8601String(), entry.batchId],
            );
            await txn.insert('stock_movement', {
              'product_id': productId,
              'warehouse_id': orig.row['warehouse_id'],
              'movement_type': 'sale_return',
              'qty': entry.qty, // الوارد موجب.
              'unit_cost': snapshotUnit,
              'ref_type': 'invoice',
              'ref_id': invoiceId,
              'moved_at': issuedIso,
              'notes':
                  'رقم الدفعة ${entry.batchNumber} '
                  '(تنتهي ${entry.expiryDate}) — $docNo',
              'created_at': at.toUtc().toIso8601String(),
              'created_by': userId,
            });
          }
          // المتبقي بلا دفعة → مخزون عام (القرار 3) بحركة مستقلة.
          if (residual > _qtyEpsilon) {
            await txn.insert('stock_movement', {
              'product_id': productId,
              'warehouse_id': orig.row['warehouse_id'],
              'movement_type': 'sale_return',
              'qty': residual,
              'unit_cost': snapshotUnit,
              'ref_type': 'invoice',
              'ref_id': invoiceId,
              'moved_at': issuedIso,
              'notes': docNo,
              'created_at': at.toUtc().toIso8601String(),
              'created_by': userId,
            });
          }

          // دفتر stock_level للنوعين — زيادة مباشرة.
          await txn.rawInsert(
            'INSERT OR IGNORE INTO stock_level(product_id, warehouse_id, qty)'
            ' VALUES(?, ?, 0)',
            [productId, orig.row['warehouse_id']],
          );
          await txn.rawUpdate(
            'UPDATE stock_level SET qty = qty + ? '
            'WHERE product_id = ? AND warehouse_id = ?',
            [lineQty, productId, orig.row['warehouse_id']],
          );
        }

        // 10-هـ) الجزء النقدي: سند **صرف** للعميل + تخصيص عكسي (القرار 2)
        //        — customer_id = NULL حتى لا يُخصم من رصيد العميل مرتين.
        if (refundCash > moneyEpsilon) {
          final cashTxId = await txn.insert('cash_tx', {
            'tx_type': 'payment',
            'cashbox_id': cashboxId,
            'currency_id': orig.row['currency_id'],
            'amount': refundCash,
            'exchange_rate': fx.rate,
            'tx_date': issuedIso,
            'ref_type': 'invoice',
            'ref_id': invoiceId,
            'customer_id': null, // لا يُخصم من رصيد العميل (القرار 2).
            'description': 'إرجاع نقدي عند إصدار $docNo',
            'created_at': at.toUtc().toIso8601String(),
            'created_by': userId,
          });
          await txn.insert('payment_allocation', {
            'cash_tx_id': cashTxId,
            'invoice_id': invoiceId,
            'allocated_amount': refundCash,
            'allocated_at': at.toUtc().toIso8601String(),
            'created_by': userId,
          });
        }
        // الجزء المخصوم من الحساب لا يُدرج في payment_allocation — دينه في
        // invoice.due_amount للمستند المرتجع تطرحه صيغة رصيد العميل
        // (FR-03-02) وكشف الحساب يظهره قيداً سالباً.

        // 10-و) قيد التدقيق.
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': 'sale_return_post',
          'entity': 'invoice',
          'entity_id': invoiceId,
          'details':
              'no=$docNo original=${orig.row['invoice_no']} '
              'total=$refundTotal cash=$refundCash credit=$refundCredit '
              'currency=${orig.row['currency_id']} rate=${fx.rate}'
              '${fx.isFallback ? ' fallback=1' : ''}',
          'at': at.toUtc().toIso8601String(),
        });

        return Ok<ReturnPostedReceipt, String>(
          ReturnPostedReceipt(
            invoiceId: invoiceId,
            docNo: docNo,
            docType: 'SRN',
            originalInvoiceId: draft.originalInvoiceId,
            originalInvoiceNo: orig.row['invoice_no'] as String?,
            refundTotal: refundTotal,
            refundCash: refundCash,
            refundCredit: refundCredit,
            payStatus: settlement.method,
            exchangeRate: fx.rate,
            rateIsFallback: fx.isFallback,
          ),
        );
      });
    } on _FlowError catch (e) {
      return Err(e.message);
    } on StateError catch (e) {
      return Err(e.message);
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e));
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // مرتجع الشراء (PRN) — FR-02-08
  // ───────────────────────────────────────────────────────────────────

  /// **ترحيل مرتجع شراء مرتبط** — معاملة واحدة (انظر رأس الملف).
  ///
  /// الكمية تخرج من مخزن الفاتورة الأصلية **بسعر حركة الشراء الأصلية
  /// (Snapshot)** من الدفعة الواردة أولاً (القرار 4)، وWAC يُعاد حسابه
  /// على المتبقي (قاعدة 5.4-3)، والقيمة تُسترد نقداً إلى الصندوق أو خصماً
  /// من دين المورد (القرار 2).
  Future<Result<ReturnPostedReceipt, String>> postPurchaseReturn(
    PurchaseReturnDraft draft, {
    required int userId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final issuedAt = draft.issuedAt;
    final issuedIso = issuedAt.toUtc().toIso8601String();

    // (1) تحقق نقي من البنود.
    final linesFailure = _validateLines(draft.lines);
    if (linesFailure != null) return Err(linesFailure);

    try {
      // (2) الفاتورة الأصلية: نوع + حالة + وجود.
      final orig = await _loadOriginal(draft.originalInvoiceId, 'purchase');
      if (orig.error != null) return Err(orig.error!);

      // (3) البنود + المنتسب + السقف (المشترى − المرتجع سابقاً).
      final membership = await _checkMembershipAndCaps(
        draft.originalInvoiceId,
        'purchase_return',
        draft.lines,
      );
      if (membership.error != null) return Err(membership.error!);
      final origItems = membership.items;

      // (4) قيمة الاسترداد Snapshot (القرار 6).
      final valued = _valueReturnLines(origItems, draft.lines);
      final refundTotal = valued.refundTotal;

      // (5) اتجاه الرد (القرار 2).
      final refundFailure = _validateRefund(
        refundTotal,
        draft.refundCash,
        draft.refundMethod,
      );
      if (refundFailure != null) return Err(refundFailure);
      final settlement = _settleRefund(refundTotal, draft.refundCash);
      final refundCash = settlement.netCash;
      final refundCredit = settlement.credit;

      // (6) المورد للجزء المخصوم من دينه.
      if (refundCredit > moneyEpsilon && orig.row['supplier_id'] == null) {
        return Err(
          'فاتورة الشراء الأصلية بلا مورد مسجَّل — لا حساب يُخصم منه؛ '
          'اختر الاسترداد نقداً إلى الصندوق.',
        );
      }

      // (7) سياسة FX بعملة الفاتورة الأصلية بتاريخ المرتجع (القرار 5).
      final fx = await _resolveRate(
        orig.row['currency_id'] as int,
        issuedAt,
      );
      if (fx.error != null) return Err(fx.error!);

      // (8) الصندوق الافتراضي — للجزء النقدي فقط.
      int? cashboxId;
      if (refundCash > moneyEpsilon) {
        final boxId = await _defaultCashboxId();
        if (boxId == null) {
          return Err('لا يوجد صندوق افتراضي للمنشأة — أنشئ صندوقاً أولاً.');
        }
        cashboxId = boxId;
      }

      // (9) معلومات الأصناف + فحص توفر المخزون مسبقاً (5.4-5).
      final products = await _loadProductsForItems(origItems);
      final stockFailure = await _checkReturnStock(
        origItems,
        products,
        draft.lines,
        orig.row['warehouse_id'] as int,
      );
      if (stockFailure != null) return Err(stockFailure);

      // (10) المعاملة الواحدة — كل الكتابات أو لا شيء (5.4-4).
      return await _db.transaction((txn) async {
        // 10-أ) رقم PRN ذرّي (قاعدة 5.4-1).
        final year = issuedAt.year;
        final seq = DocSequenceService(txn);
        final number = await seq.nextNumber(
          DocSequenceType.purchaseReturn,
          year,
        );
        final docNo = formatDocNumber(
          DocSequenceType.purchaseReturn,
          year,
          number,
        );

        // 10-ب) رأس المرتجع — الارتباط الحصري بالمورد الأصلي.
        final invoiceId = await txn.insert('invoice', {
          'invoice_no': docNo,
          'doc_type': 'purchase_return',
          'pay_status': settlement.method.code,
          'status': 'completed',
          'issued_at': issuedIso,
          'original_invoice_id': draft.originalInvoiceId,
          'supplier_id': orig.row['supplier_id'],
          'cashbox_id': cashboxId,
          'warehouse_id': orig.row['warehouse_id'],
          'currency_id': orig.row['currency_id'],
          'exchange_rate': fx.rate,
          'rate_is_fallback': fx.isFallback ? 1 : 0,
          'subtotal': valued.subtotal,
          'discount_amount': valued.discountTotal,
          'tax_rate': 0,
          'tax_amount': 0,
          'total': refundTotal,
          'total_base': roundCost(refundTotal * fx.rate),
          'paid_amount': refundCash,
          'due_amount': refundCredit,
          'cost_total': valued.costTotal,
          'notes_internal': draft.notesInternal,
          'notes_printed': draft.notesPrinted,
          'created_at': at.toUtc().toIso8601String(),
          'updated_at': at.toUtc().toIso8601String(),
          'created_by': userId,
        });

        // 10-ج) حراسة السقف داخل المعاملة.
        await _assertCapsInside(
          txn,
          draft.originalInvoiceId,
          'purchase_return',
          draft.lines,
        );

        // 10-د) البنود: خروج Snapshot + خصم الدفعات + إعادة حساب WAC.
        for (var i = 0; i < draft.lines.length; i++) {
          final input = draft.lines[i];
          final origItem = origItems[input.invoiceItemId]!;
          final productId = origItem['product_id'] as int?;
          final info = productId == null ? null : products[productId];
          final lineQty = input.qty;

          // Snapshot تكلفة الوحدة الأصلية (بالعملة الأساسية).
          final snapshotUnit = roundCost(
            (origItem['line_cost'] as num? ?? 0) /
                (origItem['qty'] as num? ?? 1),
          );
          final lineCost = roundCost(lineQty * snapshotUnit);

          // WAC قبل الخصم: يُقرأ المخزون الكلي والتكلفة داخل المعاملة.
          final wacBefore = (info == null || info.isService || productId == null)
              ? null
              : await _readWacState(txn, productId);

          // خصم الدفعات (القرار 4): الواردة الأصلية أولاً ثم FEFO للمتبقي.
          final deductions = <_BatchCap>[];
          if (info != null && info.trackBatches && productId != null) {
            var remaining = lineQty;
            // الواردة الأصلية (بمعرّفها المخزَّن وقت الشراء) — خصم محروس.
            final originalBatchId = origItem['batch_id'] as int?;
            if (originalBatchId != null) {
              final batchRows = await txn.query(
                'batch',
                columns: ['id', 'batch_number', 'expiry_date', 'qty'],
                where: 'id = ?',
                whereArgs: [originalBatchId],
                limit: 1,
              );
              if (batchRows.isNotEmpty) {
                final available =
                    (batchRows.first['qty'] as num?)?.toDouble() ?? 0;
                final take = available < remaining ? available : remaining;
                if (take > _qtyEpsilon) {
                  final affected = await txn.rawUpdate(
                    'UPDATE batch SET qty = qty - ?, updated_at = ? '
                    'WHERE id = ? AND qty >= ?',
                    [take, at.toUtc().toIso8601String(), originalBatchId, take],
                  );
                  if (affected > 0) {
                    deductions.add(
                      _BatchCap(
                        batchId: originalBatchId,
                        batchNumber: batchRows.first['batch_number'] as String,
                        expiryDate: batchRows.first['expiry_date'] as String,
                        qty: take,
                      ),
                    );
                    remaining = roundCost(remaining - take);
                  }
                }
              }
            }
            // المتبقي بدفعات الصنف النشطة FEFO (المنتهية مشمولة — إرجاعها
            // للمورد جائز) — أحراس السالب بداخلها ترمي فتتراجع المعاملة.
            if (remaining > _qtyEpsilon) {
              final fefo = await _batches.allocateFefo(
                txn,
                productId: productId,
                warehouseId: orig.row['warehouse_id'] as int,
                qty: remaining,
                asOf: issuedAt,
                includeExpired: true,
              );
              if (fefo.shorted) {
                throw _FlowError(
                  'الكمية غير متوفرة بدفعات الصنف '
                  '«${info.name}»: المتاح '
                  '${_num(lineQty - remaining + fefo.allocatedQty)} '
                  'والمطلوب ${_num(lineQty)} — لا يسمح النظام بمخزون سالب.',
                );
              }
              await _batches.applyAllocation(txn, fefo.allocations, now: at);
              for (final a in fefo.allocations) {
                deductions.add(
                  _BatchCap(
                    batchId: a.batchId,
                    batchNumber: a.batchNumber,
                    expiryDate: _dateOnly(a.expiryDate),
                    qty: a.qty,
                  ),
                );
              }
            }
          }

          final batchSummary = deductions.isEmpty
              ? null
              : deductions
                    .map((d) => '${d.batchNumber}×${_num(d.qty)}')
                    .join('، ');
          final lineNotes = [
            'أصل البند #${input.invoiceItemId}',
            if (batchSummary != null) 'دفعة: $batchSummary',
          ].join(' — ');

          await txn.insert('invoice_item', {
            'invoice_id': invoiceId,
            'product_id': productId,
            'line_desc': origItem['line_desc'],
            'qty': lineQty,
            'unit_id': origItem['unit_id'],
            'unit_factor': 1,
            'unit_price': origItem['unit_price'],
            'discount_percent': origItem['discount_percent'],
            'discount_amount': valued.discounts[i],
            'tax_percent': 0,
            'line_total': valued.lineTotals[i],
            'line_cost': lineCost, // Snapshot بالعملة الأساسية (5.4-3).
            'batch_id': deductions.isNotEmpty ? deductions.first.batchId : null,
            'notes': lineNotes,
            'created_at': at.toUtc().toIso8601String(),
          });

          // الخدمي: لا مخزون ولا WAC (FR-01-16).
          if (info == null || info.isService || productId == null) continue;

          // حركات الخروج: لكل دفعة خصماً (بسعر Snapshot) أو واحدة للعادي.
          if (deductions.isNotEmpty) {
            for (final d in deductions) {
              await txn.insert('stock_movement', {
                'product_id': productId,
                'warehouse_id': orig.row['warehouse_id'],
                'movement_type': 'purchase_return',
                'qty': -d.qty, // الخروج سالب (اتجاه المخطط).
                'unit_cost': snapshotUnit,
                'ref_type': 'invoice',
                'ref_id': invoiceId,
                'moved_at': issuedIso,
                'notes':
                    'رقم الدفعة ${d.batchNumber} '
                    '(تنتهي ${d.expiryDate}) — $docNo',
                'created_at': at.toUtc().toIso8601String(),
                'created_by': userId,
              });
            }
          } else {
            await txn.insert('stock_movement', {
              'product_id': productId,
              'warehouse_id': orig.row['warehouse_id'],
              'movement_type': 'purchase_return',
              'qty': -lineQty,
              'unit_cost': snapshotUnit,
              'ref_type': 'invoice',
              'ref_id': invoiceId,
              'moved_at': issuedIso,
              'notes': docNo,
              'created_at': at.toUtc().toIso8601String(),
              'created_by': userId,
            });
          }

          // خصم دفتر stock_level — حارس السالب الصارم (5.4-5).
          final consumed = await txn.rawUpdate(
            'UPDATE stock_level SET qty = qty - ? '
            'WHERE product_id = ? AND warehouse_id = ? AND qty >= ?',
            [lineQty, productId, orig.row['warehouse_id'], lineQty],
          );
          if (consumed == 0) {
            throw _FlowError(
              'الكمية غير متوفرة للصنف «${info.name}» بالمخزن — '
              'الرصيد الدفتري أقل من المطلوب (${_num(lineQty)}) — '
              'لا يسمح النظام بمخزون سالب.',
            );
          }

          // إعادة حساب WAC على المتبقي (قاعدة 5.4-3 — Snapshot).
          if (wacBefore != null) {
            final remainingQty = wacBefore.qty - lineQty;
            double newCost;
            if (remainingQty <= _qtyEpsilon) {
              newCost = 0; // أُرجع كل المخزون — قيمة المخزون صفر.
            } else {
              newCost = roundCost(
                (wacBefore.qty * wacBefore.cost - lineQty * snapshotUnit) /
                    remainingQty,
              );
              if (newCost < 0) newCost = 0; // حارس نظرية نادرة.
            }
            await txn.update(
              'product',
              {
                'cost_price': newCost,
                'updated_at': at.toUtc().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [productId],
            );
          }
        }

        // 10-هـ) الجزء النقدي: سند **قبض** من المورد + تخصيص عكسي
        //        (القرار 2) — supplier_id = NULL حتى لا يُخصم من رصيد
        //        المورد مرتين (صيغة FR-03-03 تطرح سندات الصرف فقط).
        if (refundCash > moneyEpsilon) {
          final cashTxId = await txn.insert('cash_tx', {
            'tx_type': 'receipt',
            'cashbox_id': cashboxId,
            'currency_id': orig.row['currency_id'],
            'amount': refundCash,
            'exchange_rate': fx.rate,
            'tx_date': issuedIso,
            'ref_type': 'invoice',
            'ref_id': invoiceId,
            'supplier_id': null, // لا يُخصم من رصيد المورد (القرار 2).
            'description': 'استرداد نقدي عند إصدار $docNo',
            'created_at': at.toUtc().toIso8601String(),
            'created_by': userId,
          });
          await txn.insert('payment_allocation', {
            'cash_tx_id': cashTxId,
            'invoice_id': invoiceId,
            'allocated_amount': refundCash,
            'allocated_at': at.toUtc().toIso8601String(),
            'created_by': userId,
          });
        }
        // الجزء المخصوم من دين المورد في invoice.due_amount للمستند
        // المرتجع — تطرحه صيغة رصيد المورد (FR-03-03) وكشفه يظهر قيداً.

        // 10-و) قيد التدقيق.
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': 'purchase_return_post',
          'entity': 'invoice',
          'entity_id': invoiceId,
          'details':
              'no=$docNo original=${orig.row['invoice_no']} '
              'total=$refundTotal cash=$refundCash credit=$refundCredit '
              'currency=${orig.row['currency_id']} rate=${fx.rate}'
              '${fx.isFallback ? ' fallback=1' : ''}',
          'at': at.toUtc().toIso8601String(),
        });

        return Ok<ReturnPostedReceipt, String>(
          ReturnPostedReceipt(
            invoiceId: invoiceId,
            docNo: docNo,
            docType: 'PRN',
            originalInvoiceId: draft.originalInvoiceId,
            originalInvoiceNo: orig.row['invoice_no'] as String?,
            refundTotal: refundTotal,
            refundCash: refundCash,
            refundCredit: refundCredit,
            payStatus: settlement.method,
            exchangeRate: fx.rate,
            rateIsFallback: fx.isFallback,
          ),
        );
      });
    } on _FlowError catch (e) {
      return Err(e.message);
    } on StateError catch (e) {
      return Err(e.message);
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e));
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // البنود المتاحة للإرجاع (لواجهة المرحلة 5 لاحقاً)
  // ───────────────────────────────────────────────────────────────────

  /// بنود فاتورة بيع القابلة للإرجاع مع المتاح لكل بند — قائمة فارغة إن
  /// لم تكن الفاتورة بيعاً مكتملاً (أو غير موجودة).
  Future<List<ReturnableLine>> saleReturnableLines(int invoiceId) async {
    return _returnableLines(invoiceId, 'sale', 'sale_return');
  }

  /// بنود فاتورة شراء القابلة للإرجاع مع المتاح لكل بند — قائمة فارغة إن
  /// لم تكن الفاتورة شراءً مكتملاً (أو غير موجودة).
  Future<List<ReturnableLine>> purchaseReturnableLines(int invoiceId) async {
    return _returnableLines(invoiceId, 'purchase', 'purchase_return');
  }

  Future<List<ReturnableLine>> _returnableLines(
    int invoiceId,
    String originalType,
    String returnType,
  ) async {
    final origRows = await _db.query(
      'invoice',
      columns: ['id'],
      where: 'id = ? AND doc_type = ? AND status = ?',
      whereArgs: [invoiceId, originalType, 'completed'],
      limit: 1,
    );
    if (origRows.isEmpty) return const [];
    final items = await _db.query(
      'invoice_item',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'id ASC',
    );
    final returned = await _returnedByLine(invoiceId, returnType);
    return [
      for (final item in items)
        ReturnableLine(
          invoiceItemId: item['id'] as int,
          productId: item['product_id'] as int?,
          lineDesc: item['line_desc'] as String?,
          originalQty: (item['qty'] as num?)?.toDouble() ?? 0,
          returnedQty: returned[item['id'] as int] ?? 0,
          availableQty: _available(
            (item['qty'] as num?)?.toDouble() ?? 0,
            returned[item['id'] as int] ?? 0,
          ),
          unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0,
          unitPriceEffective: roundMoney(
            ((item['line_total'] as num?)?.toDouble() ?? 0) /
                ((item['qty'] as num?)?.toDouble() ?? 1),
          ),
          unitCostSnapshot: roundCost(
            ((item['line_cost'] as num?)?.toDouble() ?? 0) /
                ((item['qty'] as num?)?.toDouble() ?? 1),
          ),
          batchId: item['batch_id'] as int?,
        ),
    ];
  }

  // ───────────────────────────────────────────────────────────────────
  // مساعدات خاصة — التحميل والتحقق المشترك
  // ───────────────────────────────────────────────────────────────────

  /// تحقق نقي من بنود المرتجع (كميات وأرقام).
  String? _validateLines(List<ReturnLineInput> lines) {
    if (lines.isEmpty) {
      return 'أضف بنداً واحداً على الأقل إلى المرتجع.';
    }
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final no = i + 1;
      if (line.qty.isNaN || line.qty.isInfinite) {
        return 'كمية البند $no غير صالحة — أدخل رقماً سليماً.';
      }
      if (line.qty <= 0) {
        return 'كمية البند $no يجب أن تكون أكبر من صفر.';
      }
    }
    return null;
  }

  /// يحمل الفاتورة الأصلية ويتحقق من نوعها وحالتها (FR-02-07).
  Future<({Map<String, Object?> row, String? error})> _loadOriginal(
    int invoiceId,
    String expectedType,
  ) async {
    final rows = await _db.query(
      'invoice',
      where: 'id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return (
        row: const <String, Object?>{},
        error: 'الفاتورة رقم #$invoiceId غير موجودة.',
      );
    }
    final row = rows.first;
    final docType = row['doc_type'] as String;
    if (docType != expectedType) {
      final label = expectedType == 'sale' ? 'بيع' : 'شراء';
      return (
        row: row,
        error: 'الفاتورة رقم #$invoiceId ليست فاتورة $label (نوعها '
            '«$docType») — لا يُنشأ مرتجع إلا عن النوع المطابق.',
      );
    }
    final status = row['status'] as String;
    if (status == 'void') {
      return (
        row: row,
        error: 'الفاتورة ${row['invoice_no']} ملغاة — لا يُنشأ مرتجع عن '
            'فاتورة ملغاة (FR-02-07).',
      );
    }
    if (status != 'completed') {
      return (
        row: row,
        error: 'الفاتورة ${row['invoice_no']} ليست مكتملة (حالتها '
            '«$status») — لا يُنشأ مرتجع إلا عن فاتورة مكتملة.',
      );
    }
    return (row: row, error: null);
  }

  /// فحص انتساب البنود للفاتورة الأصلية + سقف الكميات لكل بند
  /// (المباع/المشترى − المرتجع سابقاً) — القرار 1.
  Future<({Map<int, Map<String, Object?>> items, String? error})>
  _checkMembershipAndCaps(
    int originalInvoiceId,
    String returnType,
    List<ReturnLineInput> lines,
  ) async {
    final itemRows = await _db.query(
      'invoice_item',
      where: 'invoice_id = ?',
      whereArgs: [originalInvoiceId],
      orderBy: 'id ASC',
    );
    final items = {for (final row in itemRows) row['id'] as int: row};
    final returned = await _returnedByLine(originalInvoiceId, returnType);
    final requested = <int, double>{};
    for (final line in lines) {
      final item = items[line.invoiceItemId];
      if (item == null) {
        return (
          items: items,
          error: 'البند رقم #${line.invoiceItemId} لا ينتمي إلى الفاتورة '
              'الأصلية — اختر بنوداً من الفاتورة نفسها.',
        );
      }
      requested[line.invoiceItemId] =
          (requested[line.invoiceItemId] ?? 0) + line.qty;
    }
    for (final entry in requested.entries) {
      final item = items[entry.key]!;
      final origQty = (item['qty'] as num?)?.toDouble() ?? 0;
      final alreadyReturned = returned[entry.key] ?? 0;
      final available = _available(origQty, alreadyReturned);
      if (entry.value > available + _qtyEpsilon) {
        return (
          items: items,
          error: 'الكمية المطلوب إرجاعها من البند '
              '«${item['line_desc'] ?? entry.key}» (${_num(entry.value)}) '
              'تتجاوز المتاح للإرجاع (${_num(available)}) — الأصلي '
              '${_num(origQty)} والمرتجع سابقاً ${_num(alreadyReturned)}.',
        );
      }
    }
    return (items: items, error: null);
  }

  /// حراسة السقف داخل المعاملة (كتابات متوازية) — القرار 1.
  Future<void> _assertCapsInside(
    DatabaseExecutor txn,
    int originalInvoiceId,
    String returnType,
    List<ReturnLineInput> lines,
  ) async {
    final itemRows = await txn.query(
      'invoice_item',
      columns: ['id', 'qty', 'line_desc'],
      where: 'invoice_id = ?',
      whereArgs: [originalInvoiceId],
    );
    final origQty = {
      for (final row in itemRows)
        row['id'] as int: (row['qty'] as num?)?.toDouble() ?? 0,
    };
    final names = {
      for (final row in itemRows)
        row['id'] as int: row['line_desc'] as String?,
    };
    final returned = await _returnedByLineInside(
      txn,
      originalInvoiceId,
      returnType,
    );
    final requested = <int, double>{};
    for (final line in lines) {
      requested[line.invoiceItemId] =
          (requested[line.invoiceItemId] ?? 0) + line.qty;
    }
    for (final entry in requested.entries) {
      final available = _available(
        origQty[entry.key] ?? 0,
        returned[entry.key] ?? 0,
      );
      if (entry.value > available + _qtyEpsilon) {
        throw _FlowError(
          'تغيّر المتبقي للإرجاع من البند '
          '«${names[entry.key] ?? entry.key}» قبل الحفظ — المتاح الآن '
          '${_num(available)} والمطلوب ${_num(entry.value)}. أعد المحاولة.',
        );
      }
    }
  }

  /// قيمة بنود المرتجع Snapshot من البنود الأصلية (القرار 6):
  /// gross = round2(qty_ret × unit_price الأصلي)، خصم تناسبي،
  /// line_total = gross − الخصم — والتكلفة الأصلية منقولة تناسبياً.
  _ValuedReturn _valueReturnLines(
    Map<int, Map<String, Object?>> origItems,
    List<ReturnLineInput> lines,
  ) {
    var subtotal = 0.0;
    var discountTotal = 0.0;
    var refundTotal = 0.0;
    var costTotal = 0.0;
    final lineTotals = <double>[];
    final discounts = <double>[];
    for (final line in lines) {
      final item = origItems[line.invoiceItemId]!;
      final origQty = (item['qty'] as num?)?.toDouble() ?? 1;
      final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
      final origDiscount = (item['discount_amount'] as num?)?.toDouble() ?? 0;
      final origLineCost = (item['line_cost'] as num?)?.toDouble() ?? 0;

      final gross = roundMoney(line.qty * unitPrice);
      final discount = roundMoney(line.qty * origDiscount / origQty);
      final lineTotal = roundMoney(gross - discount);
      final lineCost = roundCost(
        line.qty * roundCost(origLineCost / origQty),
      );

      lineTotals.add(lineTotal);
      discounts.add(discount);
      subtotal = roundMoney(subtotal + gross);
      discountTotal = roundMoney(discountTotal + discount);
      refundTotal = roundMoney(refundTotal + lineTotal);
      costTotal = roundCost(costTotal + lineCost);
    }
    return _ValuedReturn(
      subtotal: subtotal,
      discountTotal: discountTotal,
      refundTotal: refundTotal,
      costTotal: costTotal,
      lineTotals: lineTotals,
      discounts: discounts,
    );
  }

  /// يتحقق من اتجاه رد القيمة مقابل الأرقام (القرار 2) — مرآة نمط
  /// `PurchasePricing.validatePayment` بصياغة المرتجع.
  String? _validateRefund(
    double refundTotal,
    double refundCash,
    ReturnRefundMethod declared,
  ) {
    if (refundCash.isNaN || refundCash.isInfinite || refundCash < 0) {
      return 'المبلغ النقدي المرتجع لا يمكن أن يكون سالباً.';
    }
    if (refundCash > refundTotal + moneyEpsilon) {
      return 'المبلغ النقدي المرتجع ($refundCash) يتجاوز قيمة المرتجع '
          '($refundTotal) — المرتجع لا يقبل الرد الزائد؛ اترك الباقي على '
          'الحساب.';
    }
    final derived = _deriveMethod(refundTotal, refundCash);
    if (derived == declared) return null;
    switch (declared) {
      case ReturnRefundMethod.cash:
        return 'الرد النقدي يتطلب رد قيمة المرتجع كاملة نقداً '
            '($refundTotal) — أو اختر الخصم من الحساب/المختلط.';
      case ReturnRefundMethod.credit:
        return 'الخصم من الحساب يتطلب عدم إدخال أي مبلغ نقدي — المدخل '
            '$refundCash.';
      case ReturnRefundMethod.mixed:
        return 'الرد المختلط يتطلب مبلغاً نقدياً بين صفر وقيمة المرتجع '
            '($refundTotal) حصراً — المدخل $refundCash.';
    }
  }

  /// يستنتج اتجاه الرد من الأرقام: نقدي عند رد الكامل، على الحساب عند
  /// الصفر، مختلط بينهما.
  ReturnRefundMethod _deriveMethod(double refundTotal, double refundCash) {
    if (refundCash <= moneyEpsilon) return ReturnRefundMethod.credit;
    if (refundCash >= refundTotal - moneyEpsilon) {
      return ReturnRefundMethod.cash;
    }
    return ReturnRefundMethod.mixed;
  }

  /// يفصل الرد: الجزء النقدي + الجزء المخصوم من حساب الطرف.
  ({double netCash, double credit, ReturnRefundMethod method}) _settleRefund(
    double refundTotal,
    double refundCash,
  ) {
    final netCash = roundMoney(
      refundCash < refundTotal ? refundCash : refundTotal,
    );
    final credit = roundMoney(refundTotal - netCash);
    return (
      netCash: netCash,
      credit: credit,
      method: _deriveMethod(refundTotal, refundCash),
    );
  }

  /// يحل سعر الصرف وفق FR-08-09 (نفس نمط البيع/الشراء حرفياً).
  Future<({double rate, bool isFallback, String? error})> _resolveRate(
    int currencyId,
    DateTime issuedAt,
  ) async {
    final currencyRows = await _db.query(
      'currency',
      columns: ['code', 'is_base'],
      where: 'id = ?',
      whereArgs: [currencyId],
      limit: 1,
    );
    if (currencyRows.isEmpty) {
      return (
        rate: 1.0,
        isFallback: false,
        error: 'عملة الفاتورة غير موجودة.',
      );
    }
    if ((currencyRows.first['is_base'] as int? ?? 0) == 1) {
      return (rate: 1.0, isFallback: false, error: null);
    }
    final code = currencyRows.first['code'] as String;
    final todayRate = await _rates.rateFor(currencyId, issuedAt);
    if (todayRate != null && todayRate > 0) {
      return (rate: todayRate, isFallback: false, error: null);
    }
    final fallbackOn =
        (await _settings.getString('fx.fallback', 'off')) == 'last_known';
    if (!fallbackOn) {
      return (
        rate: 1.0,
        isFallback: false,
        error: 'لا يوجد سعر صرف لعملة $code بتاريخ اليوم — أدخل سعر اليوم '
            'أولاً ثم احفظ (لا يُحفظ بسعر افتراضي).',
      );
    }
    final lastKnown = await _rates.latestBefore(currencyId, issuedAt);
    if (lastKnown == null || lastKnown <= 0) {
      return (
        rate: 1.0,
        isFallback: false,
        error: 'لا يوجد أي سعر صرف معروف لعملة $code — أدخل سعراً واحداً '
            'على الأقل قبل الحفظ بها.',
      );
    }
    return (rate: lastKnown, isFallback: true, error: null);
  }

  /// الصندوق الافتراضي أو null.
  Future<int?> _defaultCashboxId() async {
    final rows = await _db.query(
      'cashbox',
      columns: ['id'],
      where: 'is_default = 1 AND is_archived = 0',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  /// معلومات الأصناف لبنود الفاتورة الأصلية (خدمي/متتبع).
  Future<Map<int, _ReturnProductInfo>> _loadProductsForItems(
    Map<int, Map<String, Object?>> items,
  ) async {
    final ids = {
      for (final item in items.values)
        if (item['product_id'] != null) item['product_id'] as int,
    };
    if (ids.isEmpty) return const {};
    final rows = await _db.rawQuery(
      'SELECT id, name, is_service, track_batches FROM product '
      'WHERE id IN (${List.filled(ids.length, '?').join(',')})',
      ids.toList(),
    );
    return {
      for (final row in rows)
        row['id'] as int: _ReturnProductInfo(
          id: row['id'] as int,
          name: row['name'] as String,
          isService: (row['is_service'] as int? ?? 0) == 1,
          trackBatches: (row['track_batches'] as int? ?? 0) == 1,
        ),
    };
  }

  /// فحص توفر المخزون مسبقاً لمرتجع الشراء (5.4-5): العادي من
  /// `stock_level` والمتتبع من مجموع دفعاته غير المؤرشفة.
  Future<String?> _checkReturnStock(
    Map<int, Map<String, Object?>> origItems,
    Map<int, _ReturnProductInfo> products,
    List<ReturnLineInput> lines,
    int warehouseId,
  ) async {
    final requested = <int, double>{};
    final names = <int, String>{};
    for (final line in lines) {
      final item = origItems[line.invoiceItemId]!;
      final productId = item['product_id'] as int?;
      if (productId == null) continue;
      final info = products[productId];
      if (info == null || info.isService) continue;
      requested[productId] = (requested[productId] ?? 0) + line.qty;
      names[productId] = info.name;
    }
    if (requested.isEmpty) return null;
    final ids = requested.keys.toList();
    final inClause = List.filled(ids.length, '?').join(',');

    final plainRows = await _db.rawQuery(
      'SELECT product_id, qty FROM stock_level '
      'WHERE warehouse_id = ? AND product_id IN ($inClause)',
      [warehouseId, ...ids],
    );
    final plainQty = {
      for (final row in plainRows)
        row['product_id'] as int: (row['qty'] as num?)?.toDouble() ?? 0,
    };
    final batchRows = await _db.rawQuery(
      'SELECT product_id, SUM(qty) AS q FROM batch '
      'WHERE warehouse_id = ? AND product_id IN ($inClause) '
      '  AND qty > 0 AND is_archived = 0 GROUP BY product_id',
      [warehouseId, ...ids],
    );
    final batchQty = {
      for (final row in batchRows)
        row['product_id'] as int: (row['q'] as num?)?.toDouble() ?? 0,
    };
    for (final entry in requested.entries) {
      final tracked = products[entry.key]!.trackBatches;
      final available = tracked
          ? (batchQty[entry.key] ?? 0)
          : (plainQty[entry.key] ?? 0);
      if (available + _qtyEpsilon < entry.value) {
        return 'الكمية غير متوفرة للصنف «${names[entry.key]}»: المتاح '
            '${_num(available)} والمطلوب إرجاعه ${_num(entry.value)} — '
            'لا يسمح النظام بمخزون سالب.';
      }
    }
    return null;
  }

  /// يقرأ حالة WAC (التكلفة + الكمية الكلية عبر المخازن) داخل المعاملة.
  Future<({double cost, double qty})> _readWacState(
    DatabaseExecutor txn,
    int productId,
  ) async {
    final rows = await txn.rawQuery(
      'SELECT p.cost_price AS cost, '
      '       COALESCE((SELECT SUM(sl.qty) FROM stock_level sl '
      '                 WHERE sl.product_id = p.id), 0) AS qty '
      'FROM product p WHERE p.id = ?',
      [productId],
    );
    return (
      cost: (rows.first['cost'] as num?)?.toDouble() ?? 0,
      qty: (rows.first['qty'] as num?)?.toDouble() ?? 0,
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // مساعدات الدفعات
  // ───────────────────────────────────────────────────────────────────

  /// **سعات عودة دفعات مرتجع البيع** (القرار 3): لكل دفعة استُهلكت في
  /// البيع الأصلي — السعة = ما استُهلك منها − ما أُعيد إليها سابقاً
  /// (حركات SRN سابقة بنفس صيغة الملاحظة)، مع مطابقة صف `batch` الحي
  /// بالرقم والتاريخ معاً؛ الدفعات غير القابلة للتتبع تُتخطى (كميتها
  /// تذهب للمخزون العام عبر «المتبقي»).
  Future<List<_BatchCap>> _loadBatchReturnCaps(
    DatabaseExecutor txn, {
    required int productId,
    required int warehouseId,
    required int originalInvoiceId,
  }) async {
    // استهلاك البيع الأصلي لكل دفعة (حركة لكل دفعة برجوع للفاتورة).
    final saleMoves = await txn.rawQuery(
      'SELECT notes, qty FROM stock_movement '
      "WHERE movement_type = 'sale' AND ref_type = 'invoice' AND ref_id = ? "
      'AND product_id = ? AND warehouse_id = ? ORDER BY id ASC',
      [originalInvoiceId, productId, warehouseId],
    );
    // (رقم الدفعة، تاريخ الصلاحية) → الكمية المستهلكة.
    final consumed = <String, double>{};
    final order = <String>[];
    for (final move in saleMoves) {
      final match = _batchNotePattern.firstMatch(
        (move['notes'] as String?) ?? '',
      );
      if (match == null) continue; // حركة غير دفعية (مخزون عام).
      final key = '${match.group(1)!.trim()}|${match.group(2)!}';
      consumed[key] =
          (consumed[key] ?? 0) - ((move['qty'] as num?)?.toDouble() ?? 0);
      if (!order.contains(key)) order.add(key);
    }
    // ما أُعيد سابقاً لكل دفعة (حركات SRN مكتملة سابقة بنفس الصيغة).
    final priorMoves = await txn.rawQuery(
      'SELECT sm.notes AS notes, sm.qty AS qty FROM stock_movement sm '
      "WHERE sm.movement_type = 'sale_return' AND sm.ref_type = 'invoice' "
      'AND sm.ref_id IN (SELECT id FROM invoice '
      "  WHERE doc_type = 'sale_return' AND status = 'completed' "
      '    AND original_invoice_id = ?) '
      'AND sm.product_id = ? AND sm.warehouse_id = ?',
      [originalInvoiceId, productId, warehouseId],
    );
    final priorReturned = <String, double>{};
    for (final move in priorMoves) {
      final match = _batchNotePattern.firstMatch(
        (move['notes'] as String?) ?? '',
      );
      if (match == null) continue; // عودة سابقة بلا دفعة (مخزون عام).
      final key = '${match.group(1)!.trim()}|${match.group(2)!}';
      priorReturned[key] =
          (priorReturned[key] ?? 0) + ((move['qty'] as num?)?.toDouble() ?? 0);
    }

    // السعة الفعالة لكل دفعة (بترتيب استهلاك FEFO الأصلي) مع مطابقة
    // الصف الحي — نفس ترتيب allocateFefo الأصلي (id ASC) عند التكرار.
    final caps = <_BatchCap>[];
    for (final key in order) {
      final effective = (consumed[key] ?? 0) - (priorReturned[key] ?? 0);
      if (effective <= _qtyEpsilon) continue;
      final parts = key.split('|');
      final batchRows = await txn.query(
        'batch',
        columns: ['id'],
        where:
            'product_id = ? AND warehouse_id = ? AND batch_number = ? '
            'AND expiry_date = ? AND is_archived = 0',
        whereArgs: [productId, warehouseId, parts[0], parts[1]],
        orderBy: 'id ASC',
        limit: 1,
      );
      if (batchRows.isEmpty) continue; // غير قابلة للتتبع → متبقٍ عام.
      caps.add(
        _BatchCap(
          batchId: batchRows.first['id'] as int,
          batchNumber: parts[0],
          expiryDate: parts[1],
          qty: effective,
        ),
      );
    }
    return caps;
  }

  // ───────────────────────────────────────────────────────────────────
  // مساعدات العلامة والعدّ
  // ───────────────────────────────────────────────────────────────────

  /// المرتجع سابقاً لكل بند أصلي (خارج المعاملة) — عبر علامة «أصل البند».
  Future<Map<int, double>> _returnedByLine(
    int originalInvoiceId,
    String returnType,
  ) async {
    final rows = await _db.rawQuery(
      'SELECT ii.notes AS notes, ii.qty AS qty '
      'FROM invoice_item ii JOIN invoice i ON i.id = ii.invoice_id '
      'WHERE i.doc_type = ? AND i.status = ? AND i.original_invoice_id = ?',
      [returnType, 'completed', originalInvoiceId],
    );
    return _sumByOriginMarker(rows);
  }

  /// مثلها داخل معاملة نشطة (حراسة التزامن).
  Future<Map<int, double>> _returnedByLineInside(
    DatabaseExecutor txn,
    int originalInvoiceId,
    String returnType,
  ) async {
    final rows = await txn.rawQuery(
      'SELECT ii.notes AS notes, ii.qty AS qty '
      'FROM invoice_item ii JOIN invoice i ON i.id = ii.invoice_id '
      'WHERE i.doc_type = ? AND i.status = ? AND i.original_invoice_id = ?',
      [returnType, 'completed', originalInvoiceId],
    );
    return _sumByOriginMarker(rows);
  }

  static Map<int, double> _sumByOriginMarker(List<Map<String, Object?>> rows) {
    final sums = <int, double>{};
    for (final row in rows) {
      final match = _originItemPattern.firstMatch(
        (row['notes'] as String?) ?? '',
      );
      if (match == null) continue;
      final id = int.parse(match.group(1)!);
      sums[id] = (sums[id] ?? 0) + ((row['qty'] as num?)?.toDouble() ?? 0);
    }
    return sums;
  }

  /// المتاح للإرجاع مع تثبيت التجاذب العددي (لا سالب أبداً).
  static double _available(double originalQty, double returnedQty) {
    final available = originalQty - returnedQty;
    if (available <= 0) return 0;
    if ((available * 1000).round() / 1000 <= 0) return 0;
    return available;
  }

  /// يصوغ خطأ قاعدة البيانات بكلمات المستخدم (نمط المستودعات القائمة).
  String _describeDbError(DatabaseException e) {
    if (e.isUniqueConstraintError()) {
      final text = e.toString();
      if (text.contains('invoice_no')) {
        return 'تعارض في رقم المرتجع — أعد الحفظ';
      }
      if (text.contains('payment_allocation')) {
        return 'تخصيص مدفوعات مكرر لنفس السند والمرتجع';
      }
      return 'قيمة مكررة تخالف قيد التفرد في القاعدة';
    }
    if (_isCheckFailure(e)) {
      final text = e.toString();
      if (text.contains('stock_level')) {
        return 'المخزون لا يسمح بهذه الكمية (رصيد سالب ممنوع)';
      }
      if (text.contains('due_amount') || text.contains('paid_amount')) {
        return 'مبالغ الرد غير متسقة مع قيمة المرتجع';
      }
      return 'قيمة تخالف قيد سلامة محاسبي في القاعدة';
    }
    return 'تعذر حفظ المرتجع في القاعدة: $e';
  }
}

/// هل الخطأ خرقاً لقيد CHECK؟
bool _isCheckFailure(DatabaseException e) =>
    e.toString().toUpperCase().contains('CHECK');

// ─────────────────────────────────────────────────────────────────────
// أنواع داخلية
// ─────────────────────────────────────────────────────────────────────

/// معلومات صنف داخل مستودع المرتجعات.
class _ReturnProductInfo {
  const _ReturnProductInfo({
    required this.id,
    required this.name,
    required this.isService,
    required this.trackBatches,
  });
  final int id;
  final String name;
  final bool isService;
  final bool trackBatches;
}

/// قيمة بنود المرتجع المحسوبة (Snapshot).
class _ValuedReturn {
  const _ValuedReturn({
    required this.subtotal,
    required this.discountTotal,
    required this.refundTotal,
    required this.costTotal,
    required this.lineTotals,
    required this.discounts,
  });
  final double subtotal;
  final double discountTotal;
  final double refundTotal;
  final double costTotal;
  final List<double> lineTotals;
  final List<double> discounts;
}

/// حصة/سعة دفعة — رقم الدفعة وتاريخ صلاحيتها بصيغة القاعدة (YYYY-MM-DD).
class _BatchCap {
  _BatchCap({
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.qty,
  });
  final int batchId;
  final String batchNumber;
  final String expiryDate;
  double qty;
}

/// يصيغ رقماً للعرض في الرسائل بلا أصفار زائدة.
String _num(double v) {
  if (v.isNaN || v.isInfinite) {
    return v.toString();
  }
  final rounded = (v * 1000).round() / 1000;
  if (rounded == rounded.round()) {
    return rounded.toInt().toString();
  }
  return rounded.toStringAsFixed(3);
}

/// `YYYY-MM-DD` (صيغة `batch.expiry_date`).
String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
