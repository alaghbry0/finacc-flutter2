/// محرك ترحيل فاتورة الشراء الذرّي — جداول `invoice` (doc_type='purchase') /
/// `invoice_item` / `batch` / `stock_level` / `stock_movement` / `cash_tx` /
/// `payment_allocation` — المرحلة 5 (FR-02-08 / قاعدة 5.4-3 / AC-03).
///
/// **الخريطة الملزمة** (قاعدة 5.4-4 + ملحق و): الحفظ = (رقم PUR ذرّي +
/// الفاتورة + بنودها بتكلفة الوحدة الفعلية بعد توزيع خصم الرأس pro-rata +
/// **تحديث WAC** + إنشاء الدفعات الواردة + زيادة المخزون وحركاته + حركة
/// الصندوق للجزء النقدي + تخصيص المدفوع + قيد التدقيق) داخل **Transaction
/// واحدة** — فشل أي خطوة يرجع الكل (AC-09-أ).
///
/// خطوط حمراء مطبَّقة هنا:
/// - **WAC بالعملة الأساسية** (قاعدة 5.4-3 + تعليق المخطط على
///   `product.cost_price`): خصم الرأس يوزَّع pro-rata على البنود **قبل**
///   تحديث WAC، ثم `unitCostBase = round4(netFinal × سعر يوم الشراء ÷
///   المستلم الكلي)` ثم
///   `new_cost = (qty_old×cost_old + qty_new×cost_new)/(qty_old+qty_new)`؛
///   وعند `qty_old ≤ 0` تُعتمد `cost_new` مباشرة (AC-03: شراء 10 @100
///   بخصم رأس 10% → التكلفة 90 لا 100).
/// - **بونص الشراء** (R16-a — قرار المالك الموثّق، مرآة «المنصرف
///   الكلي» للبيع): المستلم الكلي = `qty + free_qty` — الدفعة الواردة
///   و`stock_level` وحركة المخزون وWAC كلها على الكلي، و**WAC = إجمالي
///   التكلفة ÷ المستلم الكلي** فالبونص يخفّض التكلفة الوحدوية حرفياً
///   (شراء 10+2 مجاني بتكلفة 1200 → دفعة 12 وحدة بوحدة تكلفة 100).
///   المورد يُستحق من `qty` المدفوعة حصراً (subtotal/total/due_amount
///   بلا أي أثر للبونص) — فلا تضخيم لدين المورد، و`line_cost` =
///   المستلم الكلي × تكلفة الوحدة الفعلية (قيمة المخزون الوارد).
/// - **فصل العملات** (5.4-7): الفاتورة وسندها النقدي وتخصيصها كلها بعملة
///   الفاتورة وسعر يومها (Snapshot FR-08-05)؛ الأساس يُخزَّن في `total_base`
///   و`line_cost`/`cost_total` (بالعملة الأساسية — نفس اصطلاح البيع).
/// - **سياسة FX المفقود** (FR-08-09 / AC-13): عملة غير أساس بلا سعر اليوم
///   → رفض، إلا إذا فُعّل `fx.fallback=last_known` فيُستخدم آخر سعر مع
///   `rate_is_fallback=1` (شارة FR-02-20) — نفس نمط `sale_repository`.
/// - **اتجاه الصندوق معاكس للبيع** (ملحق و: شراء نقدي CASH → INV): الجزء
///   النقدي سند **صرف** (`tx_type='payment'`) من الصندوق الافتراضي، لا
///   قبض.
///
/// ## قرارات موثقة (انظر worklog-parts/7-b.md للتفصيل):
/// 1. **qty_old لصيغة WAC** = Σ(`stock_level.qty`) للصنف **عبر كل
///    المخازن** داخل المعاملة — التقييم (`product.cost_price`) عالميّ
///    للصنف لا لكل مخزن، فالمتوسط المرجّح يُحسب على المخزون الكلي.
///    والأسطر المتكررة لنفس الصنف تُحدَّث تتابعياً داخل المعاملة نفسها
///    (يُكافئ رياضياً دمجها في تحديث واحد).
/// 2. **الجزء الآجل** (`remainingCredit`) دين للمورد في `invoice.due_amount`
///    حصراً — صيغة رصيد المورد (FR-03-03) تقرأه منه. سند الصرف المصاحب
///    يُكتب بـ `supplier_id = NULL` حتى لا تخصمه صيغة الرصيد (التي تطرح
///    سندات الصرف المرتبطة بالمورد) مرتين — مرآة القرار 2 في
///    `sale_repository`.
/// 3. **payment_allocation** يوثّق الجزء المدفوع نقداً وقت الإصدار (سند
///    الصرف ← الفاتورة) — نفس اصطلاح البيع؛ العمود `cash_tx_id` NOT NULL
///    فلا تخصيص للجزء الآجل بلا سند.
/// 4. **الدفعات الواردة** (FR-01-10): صنف متتبع + رقم دفعة + صلاحية →
///    صف `batch` جديد بتكلفة الوحدة الفعلية **بالعملة الأساسية** (داخل
///    المعاملة مباشرة — `BatchRepository.createBatch` يكتب خارج المعاملة
///    فلا يصلح هنا؛ طلب نسخة تقبل txn مسجَّل للمنسّق). الصنف المتتبع **بلا
///    دفعة** يضاف للمخزون العام بلا دفعة (وفق التكليف) — **تنبيه موثَّق**:
///    فحص توفر البيع للمتتبعين يعدّ الدفعات النشطة فقط، فهذا الرصيد بلا
///    دفعة لا يظهر متاحاً للبيع حتى شراء لاحق بدفعة؛ الواجهة يجب أن تُلزم
///    رقم الدفعة للأصناف المتتبعة. الصنف غير المتتبع مع رقم دفعة → رفض.
/// 5. **رقم فاتورة المورد الورقي** (`supplierInvoiceRef`): لا عمود له في
///    المخطط المجمد — يُخزَّن كبادئة موثَّقة داخل `notes_internal` بصيغة
///    «فاتورة المورد: <الرقم>» (طلب عمود مخصص مسجَّل للمنسّق).
/// 6. **لا دفع زائد**: الشراء لا يعرف «الباقي» — `paidCash` محصور بين
///    0 والصافي (رفض واضح بخلاف البيع الذي يعيد الباقي للعميل).
/// 7. **الأصناف الخدمية** (FR-01-16): تدخل فاتورة الشراء بلا مخزون ولا
///    دفعات ولا WAC — `line_cost = 0` (كلفتها مصروف مستقبلي خارج V1).
/// 8. **المسودة (draft)** خارج نطاق هذا المحرك — البناء للمكتملة فقط
///    (`status='completed'` وفق آلة الحالات 5.4-2).
/// 9. **الضريبة** 0% في V1 لهذا المحرك (`tax_rate=0`) — الأعمدة جاهزة
///    بالمخطط ووحدة الضريبة لاحقة.
///
/// ## الإبطال (FR-02-15 — R17-c):
/// `voidInvoice` تُنشئ **حركات معاكسة كاملة** داخل Transaction واحدة —
/// لا حذف فيزيائي لأي صف (مرآة `sale_repository` § الإبطال):
/// - **المخزون**: **المستلم الكلي** (qty + freeQty — البونص دخل المخزون
///   وقت الشراء فيخرج كاملاً — قرار R16-a معكوساً) يُخصم من مخزن
///   الفاتورة **بسعر حركة الشراء الأصلية Snapshot** `line_cost ÷ الكلي`
///   (مرآة PRN — قاعدة 5.4-3)، من الدفعة الواردة الأصلية
///   (`invoice_item.batch_id`) أولاً ثم دفعات الصنف النشطة FEFO
///   (المنتهية مشمولة — إرجاعها للمورد جائز)؛ **رفض قاطع عند نقص
///   المخزون** (5.4-5 — فما بِيع من الوارد لا يُبطَل شراؤه).
/// - **WAC**: يُعاد حسابه على المتبقي بصيغة مرتجع الشراء حرفياً:
///   `(qty_old×cost_old − مستلم×snapshot) ÷ (qty_old − مستلم)` مع
///   حماية القسمة (المتبقي ≤ 0 → 0) ومنع السالب — فتعود التكلفة
///   الوحدوية لما قبل الفاتورة.
/// - **الصندوق**: سند صرف الإصدار يُبطَل بنمط `cash_repository.
///   voidMovement` (`is_voided=1` + سطر معاكس معفى بـ `reversal_of`)؛
///   تخصيصات سندات الصرف اللاحقة (PMT FIFO) تُسترد بحركة حقيقية
///   معاكسة + حذف روابط التخصيص + عكس نصيب fx — الصندوق يعود كاملاً.
/// - **رصيد المورد**: `status='void'` يستبعده من صيغة FR-03-03 (تعدّ
///   `status='completed'` حصراً) — لا `due_amount` يُمسّ.
/// - **الحارسان**: مكتملة حصراً + **رفض إن وُجدت مرتجعات شراء مكتملة
///   مرتبطة** (PRN يُلغى أولاً) + حرارة الحالة داخل المعاملة.
library;

import 'package:sqflite/sqflite.dart';

import '../../core/storage/doc_sequence.dart';
import '../../domain/core/result.dart';
import '../../domain/models/invoice_void.dart';
import '../../domain/models/purchase.dart';
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

/// معلومات صنف مطلوبة للترحيل (حمولة قراءة خفيفة) — مرآة البيع.
class _ProductInfo {
  const _ProductInfo({
    required this.id,
    required this.name,
    required this.isService,
    required this.trackBatches,
    required this.isArchived,
    this.unitId,
  });
  final int id;
  final String name;
  final bool isService;
  final bool trackBatches;

  /// المؤرشف لا يُشترى (نفس سلوك البيع مع الأرشفة — FR-01-15).
  final bool isArchived;
  final int? unitId;
}

/// مستودع المشتريات — ترحيل PUR الذرّي وقراءات فواتير الشراء.
class PurchaseRepository {
  /// يبنى فوق قاعدة مفتوحة؛ يركّب المستودعات الشريكة (تواقيعها ملزمة)
  /// فوق نفس القاعدة دون إعادة إنشاء.
  PurchaseRepository(Database db)
    : _db = db,
      _rates = ExchangeRateRepository(db),
      _settings = SettingsRepository(db),
      _batches = BatchRepository(db);

  final Database _db;
  final ExchangeRateRepository _rates;
  final SettingsRepository _settings;

  /// دفعات FEFO — لخصم الوارد عند الإبطال (نفس تركيبة محرك المرتجعات).
  final BatchRepository _batches;

  // ─────────────────────────────────────────────────────────────────────
  // الترحيل الذرّي (FR-02-08 / 5.4-3 / 5.4-4)
  // ─────────────────────────────────────────────────────────────────────

  /// **ترحيل فاتورة شراء مكتملة** — معاملة واحدة (انظر رأس الملف
  /// للخريطة).
  ///
  /// [userId] منفّذ العملية (يُخزَّن في created_by والتدقيق).
  /// [now] لحظة الكتابة الفعلية (created_at/updated_at/audit) — تاريخ
  /// العمل `draft.issuedAt` وحده يحدد سنة الترقيم وسعر الصرف.
  ///
  /// الترتيب: تحقّق نقّي → تحميلات مسبقة (عملة/سياسة FX/أصناف/مورد/
  /// صندوق) → معاملة واحدة (رقم ← فاتورة ← بنود + WAC + دفعات واردة +
  /// مخزون ← نقدي ← تخصيص ← تدقيق) → إيصال.
  Future<Result<PurchasePostedReceipt, String>> postPurchase(
    PurchaseDraft draft, {
    required int userId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final issuedAt = draft.issuedAt;
    final issuedIso = issuedAt.toUtc().toIso8601String();

    // (1) التسعير والتحقق النقي (خصومات/كميات/دفع/دفعات واردة) — قبل
    //     أي كتابة.
    final cartFailure = PurchasePricing.validateCart(
      draft.lines,
      invoiceDiscountType: draft.invoiceDiscountType,
      invoiceDiscountValue: draft.invoiceDiscountValue,
    );
    if (cartFailure != null) return Err(cartFailure);
    final priced = PurchasePricing.priceCart(
      draft.lines,
      invoiceDiscountType: draft.invoiceDiscountType,
      invoiceDiscountValue: draft.invoiceDiscountValue,
    );
    final totals = priced.totals;
    final payFailure = PurchasePricing.validatePayment(
      totals.grandTotal,
      draft.paidCash,
      draft.paymentMethod,
    );
    if (payFailure != null) return Err(payFailure);
    final settlement = PurchasePricing.settlePayment(
      totals.grandTotal,
      draft.paidCash,
    );
    final netPaid = settlement.netPaid;
    final remainingCredit = settlement.remainingCredit;
    final payStatus = settlement.payStatus;

    try {
      // (2) العملة + سياسة FX (FR-08-09) — قراءة خارج المعاملة (نمط
      //     البيع حرفياً).
      final currency = await _db.query(
        'currency',
        columns: ['id', 'code', 'is_base'],
        where: 'id = ?',
        whereArgs: [draft.currencyId],
        limit: 1,
      );
      if (currency.isEmpty) {
        return Err('العملة رقم #${draft.currencyId} غير موجودة.');
      }
      final isBase = (currency.first['is_base'] as int? ?? 0) == 1;
      final currencyCode = currency.first['code'] as String;
      var exchangeRate = 1.0;
      var rateIsFallback = false;
      if (!isBase) {
        final todayRate = await _rates.rateFor(draft.currencyId, issuedAt);
        if (todayRate != null && todayRate > 0) {
          exchangeRate = todayRate;
        } else {
          final fallbackOn =
              (await _settings.getString('fx.fallback', 'off')) == 'last_known';
          if (!fallbackOn) {
            return Err(
              'لا يوجد سعر صرف لعملة $currencyCode بتاريخ اليوم — '
              'أدخل سعر اليوم أولاً ثم احفظ (لا يُحفظ بسعر افتراضي).',
            );
          }
          final lastKnown = await _rates.latestBefore(
            draft.currencyId,
            issuedAt,
          );
          if (lastKnown == null || lastKnown <= 0) {
            return Err(
              'لا يوجد أي سعر صرف معروف لعملة $currencyCode — '
              'أدخل سعراً واحداً على الأقل قبل الشراء بها.',
            );
          }
          exchangeRate = lastKnown;
          rateIsFallback = true; // شارة «سعر صرف تقديري» (FR-02-20).
        }
      }

      // (3) الأصناف — تحميل واحد مجمّع + رفض المفقود/المؤرشف + فحص
      //     حقول الدفعة الواردة مقابل تتبع الصنف (القرار 4).
      final productIds = draft.lines.map((l) => l.productId).toSet();
      final products = await _loadProducts(productIds);
      for (var i = 0; i < draft.lines.length; i++) {
        final line = draft.lines[i];
        final info = products[line.productId];
        if (info == null) {
          return Err('الصنف رقم #${line.productId} غير موجود.');
        }
        if (info.isArchived) {
          return Err('الصنف «${info.name}» مؤرشف — لا يُشترى (FR-01-15).');
        }
        final batchNo = line.batchNo?.trim() ?? '';
        if (batchNo.isNotEmpty && !info.trackBatches) {
          return Err(
            'الصنف «${info.name}» لا يتتبع الدفعات — احذف رقم الدفعة '
            '«$batchNo» من البند ${i + 1} أو فعّل تتبع الدفعات للصنف.',
          );
        }
      }

      // (4) المورد (إلزامي للشراء) — وجود + عدم أرشفة.
      final supplierRows = await _db.query(
        'supplier',
        columns: ['name', 'is_archived'],
        where: 'id = ?',
        whereArgs: [draft.supplierId],
        limit: 1,
      );
      if (supplierRows.isEmpty) {
        return Err('المورد رقم #${draft.supplierId} غير موجود.');
      }
      if ((supplierRows.first['is_archived'] as int? ?? 0) == 1) {
        return Err(
          'المورد «${supplierRows.first['name']}» مؤرشف — أزل الأرشفة '
          'أولاً أو اختر مورداً آخر.',
        );
      }

      // (5) الصندوق الافتراضي للمنشأة — للجزء النقدي فقط.
      int? cashboxId;
      if (netPaid > moneyEpsilon) {
        final boxRows = await _db.query(
          'cashbox',
          columns: ['id'],
          where: 'is_default = 1 AND is_archived = 0',
          limit: 1,
        );
        if (boxRows.isEmpty) {
          return Err('لا يوجد صندوق افتراضي للمنشأة — أنشئ صندوقاً أولاً.');
        }
        cashboxId = boxRows.first['id'] as int;
      }

      // (6) المعاملة الواحدة — كل الكتابات أو لا شيء (5.4-4).
      return await _db.transaction((txn) async {
        // 6-أ) رقم PUR ذرّي داخل المعاملة نفسها (قاعدة 5.4-1).
        final year = issuedAt.year; // سنة يوم العمل المحلية.
        final seq = DocSequenceService(txn);
        final number = await seq.nextNumber(DocSequenceType.purchase, year);
        final docNo = formatDocNumber(DocSequenceType.purchase, year, number);

        // 6-ب) رأس الفاتورة (كل الأعمدة وفق §5.3) — رقم فاتورة المورد
        //      الورقي كبادئة موثَّقة داخل الملاحظة الداخلية (القرار 5).
        final totalBase = roundCost(totals.grandTotal * exchangeRate);
        final notesInternal = _composeInternalNotes(
          draft.supplierInvoiceRef,
          draft.notesInternal,
        );
        final invoiceId = await txn.insert('invoice', {
          'invoice_no': docNo,
          'doc_type': 'purchase',
          'pay_status': payStatus.code,
          'status': 'completed',
          'issued_at': issuedIso,
          'supplier_id': draft.supplierId,
          'cashbox_id': cashboxId,
          'warehouse_id': draft.warehouseId,
          'currency_id': draft.currencyId,
          'exchange_rate': exchangeRate,
          'rate_is_fallback': rateIsFallback ? 1 : 0,
          'subtotal': totals.subtotal,
          'discount_amount': roundMoney(totals.totalDiscount),
          'tax_rate': 0,
          'tax_amount': 0,
          'total': totals.grandTotal,
          'total_base': totalBase,
          'paid_amount': netPaid,
          'due_amount': remainingCredit,
          'cost_total': 0, // يُجمَّع من الأسطر ثم يُحدَّث أدناه.
          'notes_internal': notesInternal,
          'notes_printed': draft.notesPrinted,
          'created_at': at.toUtc().toIso8601String(),
          'updated_at': at.toUtc().toIso8601String(),
          'created_by': userId,
        });

        // 6-ج) الأسطر: تكلفة الوحدة الفعلية بالعملة الأساسية ÷ المستلم
        //      الكلي (بونص R16-a) → WAC → الدفعة الواردة → السطر →
        //      المخزون وحركته — سطراً سطراً.
        var costTotal = 0.0;
        for (final pricedLine in priced.lines) {
          final info = products[pricedLine.line.productId]!;
          final lineQty = pricedLine.line.qty;
          // المستلم الكلي (بونص R16-a): المدفوع + المجاني يدخلان المخزون
          // معاً — > 0 دائماً لأن qty > 0 مُتحقَّق في PurchasePricing.
          final freeQty = pricedLine.line.freeQty;
          final receivedQty = lineQty + freeQty;

          // تكلفة الوحدة الفعلية بالعملة الأساسية بسعر يوم الشراء (AC-03)
          // — **بالقسمة على المستلم الكلي** (قرار تحاسبي موثّق R16-a:
          // إجمالي التكلفة ÷ إجمالي الكمية المستلمة — البونص يخفّض
          // التكلفة الوحدوية: 10+2 مجاني بتكلفة 1200 → 100)؛ الخدمي بلا
          // تكلفة مخزونية (القرار 7).
          final unitCostBase = info.isService
              ? 0.0
              : roundCost(pricedLine.netFinal * exchangeRate / receivedQty);
          final lineCost = roundCost(receivedQty * unitCostBase);
          costTotal = roundCost(costTotal + lineCost);

          // WAC (5.4-3): يُقرأ ويُحدَّث داخل المعاملة على المستلم الكلي —
          // قلب الشراء (بونص R16-a: الكمية الجديدة بالكلي).
          if (!info.isService) {
            await _applyWac(
              txn,
              productId: info.id,
              qtyNew: receivedQty,
              costNew: unitCostBase,
              now: at,
            );
          }

          // الدفعة الواردة (القرار 4): متتبع + رقم + صلاحية → صف batch
          // داخل المعاملة مباشرة (createBatch يكتب خارجها فلا يصلح).
          // بونص R16-a: الدفعة تستقبل الكلي بتكلفة الوحدة الوحدوية.
          int? batchId;
          final batchNo = pricedLine.line.batchNo?.trim() ?? '';
          if (!info.isService && info.trackBatches && batchNo.isNotEmpty) {
            batchId = await txn.insert('batch', {
              'product_id': info.id,
              'warehouse_id': draft.warehouseId,
              'batch_number': batchNo,
              'expiry_date': _dateOnly(pricedLine.line.expiryDate!),
              'cost_price': unitCostBase,
              'qty': receivedQty,
              'created_at': at.toUtc().toIso8601String(),
              'updated_at': at.toUtc().toIso8601String(),
            });
          }

          final lineNotes = [
            if ((pricedLine.line.notes ?? '').trim().isNotEmpty)
              pricedLine.line.notes!.trim(),
            if (batchId != null) 'دفعة: $batchNo×${_num(receivedQty)}',
            if (freeQty > _qtyEpsilon) 'بونص: ${_num(freeQty)}',
          ].join(' — ');

          await txn.insert('invoice_item', {
            'invoice_id': invoiceId,
            'product_id': info.id,
            'line_desc': info.name, // لقطة اسم الصنف للعرض/الطباعة.
            'qty': lineQty,
            'free_qty': freeQty, // البونص مستقل (R16-a — مرآة البيع).
            'unit_id': info.unitId,
            'unit_factor': 1,
            'unit_price': pricedLine.line.unitCost,
            'discount_percent':
                pricedLine.line.lineDiscountType == PurchaseDiscountType.percent
                ? pricedLine.line.lineDiscountValue
                : 0,
            'discount_amount': pricedLine.effectiveDiscount,
            'tax_percent': 0,
            'line_total': pricedLine.netFinal,
            'line_cost': lineCost, // بالعملة الأساسية (اصطلاح البيع).
            'batch_id': batchId,
            'notes': lineNotes.isEmpty ? null : lineNotes,
            'created_at': at.toUtc().toIso8601String(),
          });

          // الخدمي: لا مخزون ولا دفعات (القرار 7).
          if (info.isService) continue;

          // المخزون: زيادة مباشرة بالمستلم الكلي (الشراء وارد — بونص
          // R16-a يدخل المخزون كالمدفوع) + حركة واردة بتكلفة الوحدة
          // الفعلية بالأساس.
          await txn.rawInsert(
            'INSERT OR IGNORE INTO stock_level(product_id, warehouse_id, qty) '
            'VALUES(?, ?, 0)',
            [info.id, draft.warehouseId],
          );
          await txn.rawUpdate(
            'UPDATE stock_level SET qty = qty + ? '
            'WHERE product_id = ? AND warehouse_id = ?',
            [receivedQty, info.id, draft.warehouseId],
          );
          await txn.insert('stock_movement', {
            'product_id': info.id,
            'warehouse_id': draft.warehouseId,
            'movement_type': 'purchase',
            'qty': receivedQty, // الوارد الكلي موجب (بونص داخل).
            'unit_cost': unitCostBase,
            'ref_type': 'invoice',
            'ref_id': invoiceId,
            'moved_at': issuedIso,
            'notes': batchId == null
                ? (freeQty > _qtyEpsilon
                      ? '$docNo — بونص: ${_num(freeQty)}'
                      : docNo)
                : '$docNo — دفعة $batchNo (تنتهي '
                      '${_dateOnly(pricedLine.line.expiryDate!)})'
                      '${freeQty > _qtyEpsilon ? ' — بونص: ${_num(freeQty)}' : ''}',
            'created_at': at.toUtc().toIso8601String(),
            'created_by': userId,
          });
        }

        // 6-د) تجميع قيمة المخزون الوارد على رأس الفاتورة (بالأساس).
        await txn.update(
          'invoice',
          {'cost_total': costTotal},
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        // 6-هـ) الجزء النقدي: سند **صرف** من الصندوق الافتراضي بعملة
        //       الفاتورة وسعرها (اتجاه معاكس للبيع — ملحق و) + تخصيصه
        //       للفاتورة (القراران 2 و3). `supplier_id = NULL` حتى لا
        //       يُخصم من رصيد المورد مرتين.
        if (netPaid > moneyEpsilon) {
          final cashTxId = await txn.insert('cash_tx', {
            'tx_type': 'payment',
            'cashbox_id': cashboxId,
            'currency_id': draft.currencyId,
            'amount': netPaid,
            'exchange_rate': exchangeRate,
            'tx_date': issuedIso,
            'ref_type': 'invoice',
            'ref_id': invoiceId,
            'supplier_id': null, // لا يُخصم من رصيد المورد (القرار 2).
            'description': 'دفع نقدي عند إصدار $docNo',
            'created_at': at.toUtc().toIso8601String(),
            'created_by': userId,
          });
          await txn.insert('payment_allocation', {
            'cash_tx_id': cashTxId,
            'invoice_id': invoiceId,
            'allocated_amount': netPaid,
            'allocated_at': at.toUtc().toIso8601String(),
            'created_by': userId,
          });
        }
        // الجزء الآجل لا يُدرج في payment_allocation (لا سند له) — دينه
        // في invoice.due_amount تقرأه صيغة رصيد المورد (FR-03-03).

        // 6-و) قيد التدقيق (append-only — نمط المستودعات القائمة).
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': 'purchase_post',
          'entity': 'invoice',
          'entity_id': invoiceId,
          'details':
              'no=$docNo total=${totals.grandTotal} '
              'paid=$netPaid due=$remainingCredit '
              'currency=$currencyCode rate=$exchangeRate'
              '${rateIsFallback ? ' fallback=1' : ''}',
          'at': at.toUtc().toIso8601String(),
        });

        return Ok<PurchasePostedReceipt, String>(
          PurchasePostedReceipt(
            invoiceId: invoiceId,
            docNo: docNo,
            totals: totals,
            payStatus: payStatus,
            exchangeRate: exchangeRate,
            rateIsFallback: rateIsFallback,
            remainingCredit: remainingCredit,
          ),
        );
      });
    } on _FlowError catch (e) {
      return Err(e.message);
    } on StateError catch (e) {
      // حراس المستودعات الشريكة — رسالتهم عربية جاهزة وتدحرج المعاملة.
      return Err(e.message);
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e));
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // الإبطال (FR-02-15 — R17-c) — حركات معاكسة كاملة، لا حذف فيزيائي
  // ─────────────────────────────────────────────────────────────────────

  /// **إبطال فاتورة شراء مكتملة** — معاملة واحدة (انظر رأس الملف
  /// § الإبطال). [userId] منفّذ الإبطال و[reason] سبب اختياري للتدقيق.
  ///
  /// الترتيب: تحققات مسبقة (نوع/حالة/مرتجعات/توفر المخزون) → معاملة
  /// واحدة (حرارة الحالة ← خصم الوارد الكلي ودفعاته Snapshot ← إعادة
  /// حساب WAC ← إبطال سند الإصدار وسطره المعاكس ← استرداد تخصيصات
  /// السندات اللاحقة ← `status='void'` ← تدقيق) → إيصال.
  Future<Result<VoidInvoiceReceipt, String>> voidInvoice(
    int invoiceId, {
    required int userId,
    String? reason,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final atIso = at.toUtc().toIso8601String();
    final cleanReason = (reason ?? '').trim();

    try {
      // (1) الفاتورة: وجود + نوع + حالة (آلة الحالات 5.4-2).
      final rows = await _db.query(
        'invoice',
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return Err('الفاتورة رقم #$invoiceId غير موجودة.');
      }
      final orig = rows.first;
      final docType = orig['doc_type'] as String;
      if (docType != 'purchase') {
        return Err(
          'الفاتورة رقم #$invoiceId ليست فاتورة شراء (نوعها «$docType») — '
          'لا يُبطَل من محرك المشتريات إلا شراء.',
        );
      }
      final status = orig['status'] as String;
      if (status == 'void') {
        return Err(
          'الفاتورة ${orig['invoice_no']} ملغاة سابقاً — لا تُبطل مرتين '
          '(FR-02-15).',
        );
      }
      if (status != 'completed') {
        return Err(
          'الفاتورة ${orig['invoice_no']} ليست مكتملة (حالتها «$status») — '
          'لا يُبطَل إلا فاتورة مكتملة.',
        );
      }

      // (2) الحارس الملزم: لا إبطال لفاتورة عليها مرتجعات شراء مكتملة.
      final returnCount =
          Sqflite.firstIntValue(
            await _db.rawQuery(
              "SELECT COUNT(*) FROM invoice WHERE original_invoice_id = ? "
              "AND doc_type = 'purchase_return' AND status = 'completed'",
              [invoiceId],
            ),
          ) ??
          0;
      if (returnCount > 0) {
        return Err(
          'على الفاتورة ${orig['invoice_no']} مرتجعات شراء مكتملة '
          '($returnCount مرتجع PRN) — عالِج المرتجعات أولاً ثم أبطل '
          'الفاتورة (لا يُبطل مستند وعليه مرتجعات — FR-02-15).',
        );
      }

      // (3) البنود + الأصناف + فحص توفر المخزون مسبقاً (5.4-5 — مرآة
      //     PRN: العادي من stock_level والمتتبع من مجموع دفعاته).
      final itemRows = await _db.query(
        'invoice_item',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
        orderBy: 'id ASC',
      );
      final productIds = {
        for (final item in itemRows)
          if (item['product_id'] != null) item['product_id'] as int,
      };
      final products = await _loadProducts(productIds);
      final warehouseId = orig['warehouse_id'] as int;
      final stockFailure = await _checkVoidStock(
        itemRows,
        products,
        warehouseId,
      );
      if (stockFailure != null) return Err(stockFailure);

      // (4) المعاملة الواحدة — كل الكتابات أو لا شيء (5.4-4).
      return await _db.transaction((txn) async {
        // 4-أ) حرارة الحالة داخل المعاملة (التزامن — لا إبطال مزدوج).
        final guard = await txn.rawQuery(
          'SELECT status, invoice_no FROM invoice WHERE id = ? LIMIT 1',
          [invoiceId],
        );
        final liveStatus = guard.first['status'] as String;
        if (liveStatus != 'completed') {
          throw _FlowError(
            'الفاتورة ${guard.first['invoice_no']} تغيّرت حالتها إلى '
            '«$liveStatus» قبل الإبطال — أعد المحاولة.',
          );
        }
        final invoiceNo = guard.first['invoice_no'] as String;

        var stockMoves = 0;
        var reversedQtyTotal = 0.0;
        var reversalCash = 0.0;
        var cashReversals = 0;
        var voucherRefunds = 0;

        // 4-ب) عكس المخزون بنداً بنداً: المستلم الكلي (qty + freeQty)
        //      يخرج بسعر حركة الشراء الأصلية + إعادة حساب WAC (مرآة PRN).
        for (final item in itemRows) {
          final productId = item['product_id'] as int?;
          if (productId == null) continue;
          final info = products[productId];
          if (info == null || info.isService) continue;

          final qty = (item['qty'] as num?)?.toDouble() ?? 0;
          final freeQty = (item['free_qty'] as num?)?.toDouble() ?? 0;
          final received = roundCost(qty + freeQty);
          if (received <= _qtyEpsilon) continue;
          final divisor = received > 0 ? received : 1;
          final snapshotUnit = roundCost(
            ((item['line_cost'] as num?)?.toDouble() ?? 0) / divisor,
          );
          reversedQtyTotal = roundCost(reversedQtyTotal + received);

          // WAC قبل الخصم: المخزون الكلي والتكلفة داخل المعاملة (القرار 1).
          final wacBefore = await _readWacState(txn, productId);

          // خصم الدفعات (مرآة PRN — القرار 4): الواردة الأصلية أولاً
          // (بمعرّفها المخزَّن وقت الشراء) ثم FEFO للمتبقي (المنتهية
          // مشمولة — إرجاعها للمورد جائز) — حارس السالب بداخلها يرمي.
          final deductions =
              <
                ({
                  int batchId,
                  String batchNumber,
                  String expiryDate,
                  double qty,
                })
              >[];
          if (info.trackBatches) {
            var remaining = received;
            final originalBatchId = item['batch_id'] as int?;
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
                    [take, atIso, originalBatchId, take],
                  );
                  if (affected > 0) {
                    deductions.add((
                      batchId: originalBatchId,
                      batchNumber: batchRows.first['batch_number'] as String,
                      expiryDate: batchRows.first['expiry_date'] as String,
                      qty: take,
                    ));
                    remaining = roundCost(remaining - take);
                  }
                }
              }
            }
            if (remaining > _qtyEpsilon) {
              final fefo = await _batches.allocateFefo(
                txn,
                productId: productId,
                warehouseId: warehouseId,
                qty: remaining,
                asOf: at,
                includeExpired: true,
              );
              if (fefo.shorted) {
                throw _FlowError(
                  'الكمية غير متوفرة بدفعات الصنف «${info.name}»: المتاح '
                  '${_num(received - remaining + fefo.allocatedQty)} '
                  'والمطلوب ${_num(received)} — لا يسمح النظام بمخزون سالب.',
                );
              }
              await _batches.applyAllocation(txn, fefo.allocations, now: at);
              for (final a in fefo.allocations) {
                deductions.add((
                  batchId: a.batchId,
                  batchNumber: a.batchNumber,
                  expiryDate: _dateOnly(a.expiryDate),
                  qty: a.qty,
                ));
              }
            }
          }

          // حركات الخروج: لكل دفعة خصماً (بسعر Snapshot) أو واحدة للعادي.
          if (deductions.isNotEmpty) {
            for (final d in deductions) {
              await txn.insert('stock_movement', {
                'product_id': productId,
                'warehouse_id': warehouseId,
                'movement_type': 'purchase_return',
                'qty': -d.qty, // الخروج سالب (اتجاه المخطط).
                'unit_cost': snapshotUnit,
                'ref_type': 'invoice',
                'ref_id': invoiceId,
                'moved_at': atIso,
                'notes':
                    'رقم الدفعة ${d.batchNumber} '
                    '(تنتهي ${d.expiryDate}) — إبطال $invoiceNo',
                'created_at': atIso,
                'created_by': userId,
              });
              stockMoves++;
            }
          } else {
            await txn.insert('stock_movement', {
              'product_id': productId,
              'warehouse_id': warehouseId,
              'movement_type': 'purchase_return',
              'qty': -received,
              'unit_cost': snapshotUnit,
              'ref_type': 'invoice',
              'ref_id': invoiceId,
              'moved_at': atIso,
              'notes':
                  '$invoiceNo — إبطال'
                  '${freeQty > _qtyEpsilon ? ' (بونص خارج: ${_num(freeQty)})' : ''}',
              'created_at': atIso,
              'created_by': userId,
            });
            stockMoves++;
          }

          // خصم دفتر stock_level — حارس السالب الصارم (5.4-5).
          final consumed = await txn.rawUpdate(
            'UPDATE stock_level SET qty = qty - ? '
            'WHERE product_id = ? AND warehouse_id = ? AND qty >= ?',
            [received, productId, warehouseId, received],
          );
          if (consumed == 0) {
            throw _FlowError(
              'الكمية غير متوفرة للصنف «${info.name}» بالمخزن — الرصيد '
              'الدفتري أقل من المطلوب إخراجه (${_num(received)}) — لا '
              'يسمح النظام بمخزون سالب (ما بِيع من الوارد لا يُبطَل شراؤه).',
            );
          }

          // إعادة حساب WAC على المتبقي (بصيغة PRN حرفياً — قاعدة 5.4-3).
          final remainingQty = wacBefore.qty - received;
          double newCost;
          if (remainingQty <= _qtyEpsilon) {
            newCost = 0; // خرج كل المخزون — قيمة المخزون صفر.
          } else {
            newCost = roundCost(
              (wacBefore.qty * wacBefore.cost - received * snapshotUnit) /
                  remainingQty,
            );
            if (newCost < 0) newCost = 0; // حارس نظرية نادرة.
          }
          await txn.update(
            'product',
            {'cost_price': newCost, 'updated_at': atIso},
            where: 'id = ?',
            whereArgs: [productId],
          );
        }

        // 4-ج) عكس الصندوق (أ) سند الإصدار: نمط voidMovement حرفياً —
        //      is_voided=1 على الأصل + سطر معاكس معفى من الأرصدة عبر
        //      reversal_of + حذف روابط التخصيص (رابط لا حركة).
        final issuanceTxs = await txn.rawQuery(
          "SELECT * FROM cash_tx WHERE ref_type = 'invoice' AND ref_id = ? "
          'AND voucher_no IS NULL AND is_voided = 0 AND reversal_of IS NULL',
          [invoiceId],
        );
        for (final tx in issuanceTxs) {
          final txId = tx['id'] as int;
          final isReceipt = tx['tx_type'] == 'receipt';
          await txn.rawUpdate(
            'UPDATE cash_tx SET is_voided = 1 WHERE id = ? AND is_voided = 0',
            [txId],
          );
          await txn.rawDelete(
            'DELETE FROM payment_allocation WHERE cash_tx_id = ?',
            [txId],
          );
          await txn.insert('cash_tx', {
            'tx_type': isReceipt ? 'payment' : 'receipt',
            'cashbox_id': tx['cashbox_id'],
            'currency_id': tx['currency_id'],
            'amount': tx['amount'],
            'exchange_rate': tx['exchange_rate'],
            'settlement_rate': tx['settlement_rate'],
            'fx_gain_loss': -((tx['fx_gain_loss'] as num?)?.toDouble() ?? 0),
            'voucher_no': null, // رقم الأصل لا يُنسخ (استمرارية الترقيم).
            'tx_date': atIso,
            'ref_type': 'invoice',
            'ref_id': null,
            'customer_id': tx['customer_id'],
            'supplier_id': tx['supplier_id'],
            'is_voided': 0,
            'reversal_of': txId,
            'description':
                'إبطال دفع $invoiceNo'
                '${cleanReason.isEmpty ? '' : ' — $cleanReason'}',
            'created_at': atIso,
            'created_by': userId,
          });
          reversalCash = roundMoney(
            reversalCash + ((tx['amount'] as num?)?.toDouble() ?? 0),
          );
          cashReversals++;
        }

        // 4-د) عكس الصندوق (ب) تخصيصات سندات الصرف اللاحقة (PMT FIFO):
        //      حركة استرداد حقيقية معاكسة (محسوبة في الأرصدة) + حذف
        //      رابط التخصيص + عكس نصيب الفاتورة من فرق الصرف.
        final invoiceRate = (orig['exchange_rate'] as num?)?.toDouble() ?? 1;
        final allocations = await txn.rawQuery(
          'SELECT pa.cash_tx_id AS tx_id, pa.allocated_amount AS alloc, '
          '       ct.tx_type, ct.cashbox_id, ct.currency_id, ct.exchange_rate, '
          '       ct.settlement_rate, ct.voucher_no '
          'FROM payment_allocation pa '
          'JOIN cash_tx ct ON ct.id = pa.cash_tx_id '
          'WHERE pa.invoice_id = ? AND ct.voucher_no IS NOT NULL '
          '  AND ct.is_voided = 0 AND ct.reversal_of IS NULL',
          [invoiceId],
        );
        for (final alloc in allocations) {
          final amount = (alloc['alloc'] as num?)?.toDouble() ?? 0;
          if (amount <= moneyEpsilon) continue;
          final isReceipt = alloc['tx_type'] == 'receipt';
          final voucherRate = (alloc['exchange_rate'] as num?)?.toDouble() ?? 1;
          final fxShare = roundMoney(
            amount *
                (isReceipt
                    ? voucherRate - invoiceRate
                    : invoiceRate - voucherRate),
          );
          await txn.insert('cash_tx', {
            'tx_type': isReceipt ? 'payment' : 'receipt',
            'cashbox_id': alloc['cashbox_id'],
            'currency_id': alloc['currency_id'],
            'amount': amount,
            'exchange_rate': voucherRate,
            'settlement_rate': alloc['settlement_rate'],
            'fx_gain_loss': roundMoney(-fxShare),
            'voucher_no': null,
            'tx_date': atIso,
            'ref_type': 'invoice',
            'ref_id': invoiceId,
            'customer_id': null,
            'supplier_id': null,
            'is_voided': 0,
            'reversal_of': null, // حركة حقيقية — تحسب في الأرصدة.
            'description':
                'استرداد تخصيص سند ${alloc['voucher_no']} '
                '— إبطال $invoiceNo',
            'created_at': atIso,
            'created_by': userId,
          });
          await txn.rawDelete(
            'DELETE FROM payment_allocation '
            'WHERE cash_tx_id = ? AND invoice_id = ?',
            [alloc['tx_id'], invoiceId],
          );
          reversalCash = roundMoney(reversalCash + amount);
          voucherRefunds++;
        }

        // 4-هـ) الحالة: completed → void (السجل يبقى — لا حذف فيزيائي).
        await txn.rawUpdate(
          "UPDATE invoice SET status = 'void', updated_at = ? WHERE id = ?",
          [atIso, invoiceId],
        );

        // 4-و) قيد التدقيق (append-only — نمط المستودعات القائمة).
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': 'void_invoice',
          'entity': 'invoice',
          'entity_id': invoiceId,
          'details':
              'no=$invoiceNo doc_type=purchase '
              'reason=${cleanReason.isEmpty ? '-' : cleanReason} '
              'reversed_cash=${_num(reversalCash)} '
              'reversed_qty=${_num(reversedQtyTotal)} '
              'stock_moves=$stockMoves cash_reversals=$cashReversals '
              'voucher_refunds=$voucherRefunds total=${orig['total']} '
              'paid=${orig['paid_amount']} due=${orig['due_amount']}',
          'at': atIso,
        });

        return Ok<VoidInvoiceReceipt, String>(
          VoidInvoiceReceipt(
            invoiceId: invoiceId,
            invoiceNo: invoiceNo,
            docType: 'purchase',
            stockMovementCount: stockMoves,
            cashReversalCount: cashReversals,
            voucherRefundCount: voucherRefunds,
            reversedCash: reversalCash,
            reversedQty: reversedQtyTotal,
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

  // ─────────────────────────────────────────────────────────────────────
  // القراءات
  // ─────────────────────────────────────────────────────────────────────

  /// تفاصيل فاتورة شراء كاملة: الرأس + البنود + اسم المورد + العملة.
  ///
  /// `null` إن لم توجد (أو ليست فاتورة شراء).
  Future<PurchaseInvoiceDetail?> purchaseDetail(int invoiceId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT i.*, s.name AS supplier_name, s.phone AS supplier_phone,
             cu.code AS currency_code, cu.symbol_svg AS currency_symbol
      FROM invoice i
      LEFT JOIN supplier s ON s.id = i.supplier_id
      JOIN currency cu ON cu.id = i.currency_id
      WHERE i.id = ? AND i.doc_type = 'purchase'
      LIMIT 1
    ''',
      [invoiceId],
    );
    if (rows.isEmpty) return null;
    final itemRows = await _db.query(
      'invoice_item',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'id ASC',
    );
    return PurchaseInvoiceDetail(
      invoice: PurchaseInvoice.fromRow(rows.first),
      items: [for (final row in itemRows) PurchaseInvoiceItemLine.fromRow(row)],
      supplierName: rows.first['supplier_name'] as String?,
      supplierPhone: rows.first['supplier_phone'] as String?,
      currencyCode: rows.first['currency_code'] as String?,
      currencySymbol: rows.first['currency_symbol'] as String?,
    );
  }

  /// آخر فواتير الشراء (الأحدث أولاً) — لتقرير/بحث الشاشات.
  Future<List<PurchaseInvoiceSummary>> recentPurchases({
    int limit = 50,
    int? supplierId,
  }) async {
    final where = [
      "i.doc_type = 'purchase'",
      if (supplierId != null) 'i.supplier_id = ?',
    ].join(' AND ');
    final rows = await _db.rawQuery(
      '''
      SELECT i.id, i.invoice_no, i.issued_at, i.supplier_id, i.total,
             i.paid_amount, i.due_amount, i.pay_status, i.status,
             s.name AS supplier_name, cu.code AS currency_code
      FROM invoice i
      LEFT JOIN supplier s ON s.id = i.supplier_id
      JOIN currency cu ON cu.id = i.currency_id
      WHERE $where
      ORDER BY i.issued_at DESC, i.id DESC
      LIMIT ?
    ''',
      [?supplierId, limit],
    );
    return [
      for (final row in rows)
        PurchaseInvoiceSummary(
          id: row['id'] as int,
          invoiceNo: row['invoice_no'] as String,
          issuedAt: DateTime.parse(row['issued_at'] as String),
          supplierId: row['supplier_id'] as int?,
          supplierName: row['supplier_name'] as String?,
          currencyCode: row['currency_code'] as String?,
          total: (row['total'] as num?)?.toDouble() ?? 0,
          paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
          dueAmount: (row['due_amount'] as num?)?.toDouble() ?? 0,
          payStatus: PurchasePaymentMethod.values.firstWhere(
            (m) => m.code == (row['pay_status'] as String),
          ),
          status: row['status'] as String,
        ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────
  // مساعدات خاصة
  // ─────────────────────────────────────────────────────────────────────

  /// **WAC (قاعدة 5.4-3)** — يقرأ التكلفة والكمية الكلية داخل المعاملة
  /// ثم يحدّث `product.cost_price` بدقة أربع منازل:
  ///
  /// - `qty_old > 0`:
  ///   `new = (qty_old×cost_old + qty_new×cost_new)/(qty_old + qty_new)`
  /// - `qty_old ≤ 0`: `new = cost_new` مباشرة (لا متوسط على مخزون معدوم).
  ///
  /// `qty_old` = Σ stock_level.qty عبر كل المخازن (القرار 1 بالرأس).
  Future<void> _applyWac(
    DatabaseExecutor txn, {
    required int productId,
    required double qtyNew,
    required double costNew,
    required DateTime now,
  }) async {
    final rows = await txn.rawQuery(
      'SELECT p.cost_price AS cost, '
      '       COALESCE((SELECT SUM(sl.qty) FROM stock_level sl '
      '                 WHERE sl.product_id = p.id), 0) AS qty '
      'FROM product p WHERE p.id = ?',
      [productId],
    );
    if (rows.isEmpty) {
      throw _FlowError('الصنف رقم #$productId غير موجود.');
    }
    final costOld = (rows.first['cost'] as num?)?.toDouble() ?? 0;
    final qtyOld = (rows.first['qty'] as num?)?.toDouble() ?? 0;
    double newCost;
    if (qtyOld <= _qtyEpsilon) {
      newCost = costNew; // المخزون معدوم/سالب دفترياً → التكلفة الجديدة.
    } else {
      newCost = roundCost(
        (qtyOld * costOld + qtyNew * costNew) / (qtyOld + qtyNew),
      );
    }
    if (newCost < 0) newCost = 0; // حارس نظري (لا تكلفة سالبة).
    await txn.update(
      'product',
      {'cost_price': newCost, 'updated_at': now.toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  /// يحمل معلومات الأصناف المطلوبة (استعلام واحد) — مرآة البيع.
  Future<Map<int, _ProductInfo>> _loadProducts(Set<int> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _db.rawQuery(
      'SELECT id, name, is_service, track_batches, is_archived, unit_id '
      'FROM product '
      'WHERE id IN (${List.filled(ids.length, '?').join(',')})',
      ids.toList(),
    );
    return {
      for (final row in rows)
        row['id'] as int: _ProductInfo(
          id: row['id'] as int,
          name: row['name'] as String,
          isService: (row['is_service'] as int? ?? 0) == 1,
          trackBatches: (row['track_batches'] as int? ?? 0) == 1,
          isArchived: (row['is_archived'] as int? ?? 0) == 1,
          unitId: row['unit_id'] as int?,
        ),
    };
  }

  /// فحص توفر المخزون مسبقاً لإبطال الشراء (5.4-5 — مرآة PRN): لكل صنف
  /// غير خدمي، المستلم الكلي (qty + free_qty) لا يتجاوز المتاح بمخزن
  /// الفاتورة: العادي من `stock_level` والمتتبع من مجموع دفعاته غير
  /// المؤرشفة (المنتهية مشمولة — الخروج منها جائز للمورد).
  Future<String?> _checkVoidStock(
    List<Map<String, Object?>> itemRows,
    Map<int, _ProductInfo> products,
    int warehouseId,
  ) async {
    final requested = <int, double>{};
    final names = <int, String>{};
    for (final item in itemRows) {
      final productId = item['product_id'] as int?;
      if (productId == null) continue;
      final info = products[productId];
      if (info == null || info.isService) continue;
      final qty = (item['qty'] as num?)?.toDouble() ?? 0;
      final free = (item['free_qty'] as num?)?.toDouble() ?? 0;
      requested[productId] = (requested[productId] ?? 0) + qty + free;
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
        return 'لا يمكن إبطال الفاتورة: الكمية غير متوفرة للصنف '
            '«${names[entry.key]}» — المتاح ${_num(available)} والمطلوب '
            'إخراجه ${_num(entry.value)} (ما بِيع من الوارد لا يُبطَل '
            'شراؤه — لا يسمح النظام بمخزون سالب).';
      }
    }
    return null;
  }

  /// يقرأ حالة WAC (التكلفة + الكمية الكلية عبر المخازن) داخل المعاملة —
  /// نفس استعلام `_applyWac` (القرار 1) بصيغة `return_repository`.
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

  /// يركّب الملاحظة الداخلية: مرجع فاتورة المورد كبادئة موثَّقة ثم ملاحظة
  /// المستخدم (القرار 5).
  static String? _composeInternalNotes(String? supplierRef, String? notes) {
    final ref = supplierRef?.trim() ?? '';
    final body = notes?.trim() ?? '';
    if (ref.isEmpty && body.isEmpty) return null;
    if (ref.isEmpty) return body;
    if (body.isEmpty) return 'فاتورة المورد: $ref';
    return 'فاتورة المورد: $ref — $body';
  }

  /// يصوغ خطأ قاعدة البيانات بكلمات المستخدم (نمط sale_repository).
  String _describeDbError(DatabaseException e) {
    if (e.isUniqueConstraintError()) {
      final text = e.toString();
      if (text.contains('invoice_no')) {
        return 'تعارض في رقم فاتورة الشراء — أعد الحفظ';
      }
      if (text.contains('payment_allocation')) {
        return 'تخصيص مدفوعات مكرر لنفس السند والفاتورة';
      }
      return 'قيمة مكررة تخالف قيد التفرد في القاعدة';
    }
    if (_isCheckFailure(e)) {
      final text = e.toString();
      if (text.contains('stock_level')) {
        return 'المخزون لا يسمح بهذه الكمية (رصيد سالب ممنوع)';
      }
      if (text.contains('due_amount') || text.contains('paid_amount')) {
        return 'مبالغ الدفع غير متسقة مع إجمالي فاتورة الشراء';
      }
      return 'قيمة تخالف قيد سلامة محاسبي في القاعدة';
    }
    return 'تعذر حفظ فاتورة الشراء في القاعدة: $e';
  }
}

/// هل الخطأ خرقاً لقيد CHECK؟ (لا مساعد جاهز في sqflite — نقرأ الرسالة).
bool _isCheckFailure(DatabaseException e) =>
    e.toString().toUpperCase().contains('CHECK');

/// تفاوت الكميات (NUMERIC(12,3) بالمخطط).
const double _qtyEpsilon = 0.000001;

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

/// `YYYY-MM-DD` بتاريخ التقويم المحلي (صيغة `batch.expiry_date` الموحدة).
String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
