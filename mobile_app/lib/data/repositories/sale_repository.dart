/// محرك ترحيل فاتورة البيع الذرّي — جداول `invoice` / `invoice_item` /
/// `stock_level` / `stock_movement` / `batch` / `cash_tx` /
/// `payment_allocation` / `quotation` — المرحلة 4 (FR-02 / FR-08-09).
///
/// **الخريطة الملزمة** (قاعدة 5.4-4 + ملحق و): الحفظ = (رقم INV ذرّي +
/// الفاتورة + بنودها بـ line_cost=WAC + خصم المخزون مع FEFO + حركات
/// المخزون + حركة الصندوق للجزء النقدي + تخصيص المدفوع + تعليم عرض
/// السعر المحوَّل + قيد التدقيق) داخل **Transaction واحدة** — فشل أي خطوة
/// يرجع الكل (AC-09-أ).
///
/// خطوط حمراء مطبَّقة هنا:
/// - **منع السالب المخزوني** (5.4-5): فحص مسبق قبل المعاملة + حارس
///   `WHERE qty >= ?` داخلها — رسالة الرفض تسمّي الصنف والكمية المتاحة.
/// - **فصل العملات** (5.4-7): الفاتورة وسندها النقدي وتخصيصها كلها بعملة
///   الفاتورة وسعر يومها (Snapshot FR-08-05)؛ الأساس بالعملة الأساسية
///   يُخزَّن في `total_base` فقط.
/// - **WAC** (5.4-3): البيع **يستهلك** `product.cost_price` ويخزنه في
///   `line_cost` ولا يغيّره أبداً.
/// - **سياسة FX المفقود** (FR-08-09 / AC-13): عملة غير أساس بلا سعر اليوم
///   → رفض، إلا إذا فُعّل `fx.fallback=last_known` فيُستخدم آخر سعر مع
///   `rate_is_fallback=1` (شارة FR-02-20).
///
/// ## قرارات موثقة (انظر worklog-parts/6-b.md للتفصيل):
/// 1. **الباقي للعميل** (`changeDue`): الزيادة النقدية فوق الصافي تُعاد في
///    الإيصال ولا تدخل الصندوق (`cash_tx.amount` = الصافي المدفوع حصراً
///    لأن عموده CHECK(amount > 0) ولا معنى لسند بمبلغ الباقي) ولا الدين.
/// 2. **payment_allocation**: العمود `cash_tx_id` NOT NULL فلا يمكن إدراجه
///    لجزء آجل بلا سند — التخصيص يوثّق **الجزء المدفوع نقداً** وقت
///    الإصدار (سند القبض ← الفاتورة)، والأثر الآجل محفوظ في
///    `invoice.due_amount` وفق اصطلاح CustomerRepository (لا يُنقصه أحد).
///    سند قبض الإصدار يُكتب بـ `customer_id = NULL` حتى لا تخصمه صيغة
///    رصيد العميل (FR-03-02) مرتين.
/// 3. **دفع متعدد الدفعات**: سطر فاتورة واحد لكل سطر سلة؛ تفصيل الدفعات
///    يُسجَّل حركة مخزون مستقلة لكل دفعة (راجعة بالفاتورة) +
///    `invoice_item.batch_id` = أول دفعة FEFO وملخص الدفعات في ملاحظة
///    السطر (AC-05: «أسطر الفاتورة أظهرت رقم الدفعة»).
/// 4. **المسودة (draft)** خارج نطاق هذا المحرك — البناء هنا للمكتملة فقط
///    (`status='completed'` وفق آلة الحالات 5.4-2).
/// 5. **الضريبة** 0% في V1 لهذا المحرك (`tax_rate=0`) — الأعمدة جاهزة
///    بالمخطط ووحدة الضريبة لاحقة.
/// 6. **userId** يُمرَّر صراحة (لا مساعد مستخدم حالي في طبقة البيانات —
///    الطلب مسجَّل في التسليم للمنسّق).
library;

import 'package:sqflite/sqflite.dart';

import '../../core/storage/doc_sequence.dart';
import '../../domain/core/result.dart';
import '../../domain/models/batch.dart';
import '../../domain/models/sale.dart';
import '../../domain/services/sale_pricing.dart';
import 'batch_repository.dart';
import 'customer_repository.dart';
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

/// معلومات صنف مطلوبة للترحيل (حمولة قراءة خفيفة).
class _ProductInfo {
  const _ProductInfo({
    required this.id,
    required this.name,
    required this.costPrice,
    required this.isService,
    required this.trackBatches,
    required this.isArchived,
    this.unitId,
  });
  final int id;
  final String name;
  final double costPrice;
  final bool isService;
  final bool trackBatches;

  /// المؤرشف لا يُباع (البحث يستثنيه — نفس السلوك هنا عند الإدخال المباشر).
  final bool isArchived;
  final int? unitId;
}

/// مستودع المبيعات — ترحيل POS الذرّي وقراءات الفواتير.
class SaleRepository {
  /// يبنى فوق قاعدة مفتوحة؛ يركّب المستودعات الشريكة (تواقيعها ملزمة)
  /// فوق نفس القاعدة دون إعادة إنشاء.
  SaleRepository(Database db)
    : _db = db,
      _rates = ExchangeRateRepository(db),
      _settings = SettingsRepository(db),
      _customers = CustomerRepository(db),
      _batches = BatchRepository(db);

  final Database _db;
  final ExchangeRateRepository _rates;
  final SettingsRepository _settings;
  final CustomerRepository _customers;
  final BatchRepository _batches;

  // ─────────────────────────────────────────────────────────────────────
  // الترحيل الذرّي (FR-02-06 / 5.4-4)
  // ─────────────────────────────────────────────────────────────────────

  /// **ترحيل فاتورة بيع مكتملة** — معاملة واحدة (انظر رأس الملف للخريطة).
  ///
  /// [userId] منفّذ العملية (يُخزَّن في created_by والتدقيق).
  /// [now] لحظة الكتابة الفعلية (created_at/updated_at/audit) — تاريخ
  /// العمل `draft.issuedAt` وحده يحدد سنة الترقيم وسعر الصرف.
  ///
  /// الترتيب: تحقّق نقّي → تحميلات مسبقة (عملة/سياسة FX/أصناف/مخزون/
  /// ائتمان/صندوق) → معاملة واحدة (رقم ← فاتورة ← بنود + WAC + FEFO +
  /// مخزون ← نقدي ← تخصيص ← ربط عرض السعر ← تدقيق) → إيصال.
  Future<Result<SalePostedReceipt, String>> postSale(
    SaleDraft draft, {
    required int userId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final issuedAt = draft.issuedAt;
    final issuedIso = issuedAt.toUtc().toIso8601String();

    // (1) التسعير والتحقق النقي (خصومات/كميات/دفع) — قبل أي كتابة.
    final cartFailure = SalePricing.validateCart(
      draft.lines,
      invoiceDiscountType: draft.invoiceDiscountType,
      invoiceDiscountValue: draft.invoiceDiscountValue,
    );
    if (cartFailure != null) return Err(cartFailure);
    final priced = SalePricing.priceCart(
      draft.lines,
      invoiceDiscountType: draft.invoiceDiscountType,
      invoiceDiscountValue: draft.invoiceDiscountValue,
    );
    final totals = priced.totals;
    final payFailure = SalePricing.validatePayment(
      totals.grandTotal,
      draft.paidCash,
      draft.paymentMethod,
    );
    if (payFailure != null) return Err(payFailure);
    final settlement = SalePricing.settlePayment(
      totals.grandTotal,
      draft.paidCash,
    );
    final netPaid = settlement.netPaid;
    final changeDue = settlement.changeDue;
    final remainingCredit = settlement.remainingCredit;
    final payStatus = settlement.payStatus;

    try {
      // (2) العملة + سياسة FX (FR-08-09) — قراءة خارج المعاملة.
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
              'أدخل سعراً واحداً على الأقل قبل البيع بها.',
            );
          }
          exchangeRate = lastKnown;
          rateIsFallback = true; // شارة «سعر صرف تقديري» (FR-02-20).
        }
      }

      // (3) الأصناف — تحميل واحد مجمّع + رفض المفقود/المؤرشف.
      final productIds = draft.lines.map((l) => l.productId).toSet();
      final products = await _loadProducts(productIds);
      for (final id in productIds) {
        final info = products[id];
        if (info == null) {
          return Err('الصنف رقم #$id غير موجود.');
        }
        if (info.isArchived) {
          return Err('الصنف «${info.name}» مؤرشف — لا يُباع (FR-01-15).');
        }
      }

      // (4) فحص المخزون المسبق (5.4-5): لكل صنف غير خدمي — المتاح من
      //     stock_level (العادي) أو دفعات FEFO النشطة (المتتبع).
      final stockFailure = await _checkAvailability(
        draft.lines,
        products,
        draft.warehouseId,
        issuedAt,
      );
      if (stockFailure != null) return Err(stockFailure);

      // (5) العميل + حد الائتمان (FR-03-05) — الآجل فقط.
      if (draft.customerId != null) {
        final customerRows = await _db.query(
          'customer',
          columns: ['name', 'is_archived'],
          where: 'id = ?',
          whereArgs: [draft.customerId],
          limit: 1,
        );
        if (customerRows.isEmpty) {
          return Err('العميل رقم #${draft.customerId} غير موجود.');
        }
        if ((customerRows.first['is_archived'] as int? ?? 0) == 1) {
          return Err(
            'العميل «${customerRows.first['name']}» مؤرشف — '
            'أزل الأرشفة أولاً أو اختر عميلاً آخر.',
          );
        }
        if (remainingCredit > moneyEpsilon) {
          final credit = await _customers.checkCredit(
            draft.customerId!,
            draft.currencyId,
            remainingCredit,
          );
          if (credit.overLimit) {
            // FR-03-05 (17-c): السلوك من إعداد parties.credit_limit_action
            // — 'block' يرفض هنا نهائياً؛ 'warn' (الافتراضي) حواره في
            // PaymentSheet («متابعة على أي حال») وقد أقرّه المستخدم،
            // فلا يمنع الترحيل — هذا المستودع حارس 'block' حصراً.
            final action = await _settings.getString(
              'parties.credit_limit_action',
              'warn',
            );
            if (action == 'block') {
              return Err(
                'تجاوز حد الائتمان: رصيد العميل الحالي ${_num(credit.balance)} '
                '+ الآجل الجديد ${_num(remainingCredit)} يتجاوز الحد '
                '${_num(credit.creditLimit ?? 0)} — قلّل الآجل أو استوفِ أولاً.',
              );
            }
          }
        }
      }

      // (6) الصندوق الافتراضي للمنشأة — للجزء النقدي فقط.
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

      // (7) عرض السعر المصدر — تحقق مسبق (الحراسة النهائية داخل المعاملة).
      if (draft.fromQuotationId != null) {
        final quoteRows = await _db.query(
          'quotation',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [draft.fromQuotationId],
          limit: 1,
        );
        if (quoteRows.isEmpty) {
          return Err('عرض السعر رقم #${draft.fromQuotationId} غير موجود.');
        }
        final status = quoteRows.first['status'] as String;
        if (status != 'draft' && status != 'sent') {
          return Err('عرض السعر غير قابل للتحويل — حالته الحالية «$status».');
        }
      }

      // (8) المعاملة الواحدة — كل الكتابات أو لا شيء (5.4-4).
      return await _db.transaction((txn) async {
        // 8-أ) رقم INV ذرّي داخل المعاملة نفسها (قاعدة 5.4-1).
        final year = issuedAt.year; // سنة يوم العمل المحلية.
        final seq = DocSequenceService(txn);
        final number = await seq.nextNumber(DocSequenceType.invoice, year);
        final invoiceNo = formatDocNumber(
          DocSequenceType.invoice,
          year,
          number,
        );

        // 8-ب) رأس الفاتورة (كل الأعمدة وفق §5.3).
        final totalBase = roundCost(totals.grandTotal * exchangeRate);
        final invoiceId = await txn.insert('invoice', {
          'invoice_no': invoiceNo,
          'doc_type': 'sale',
          'pay_status': payStatus.code,
          'status': 'completed',
          'issued_at': issuedIso,
          'quotation_id': draft.fromQuotationId,
          'customer_id': draft.customerId,
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
          'notes_internal': draft.notesInternal,
          'notes_printed': draft.notesPrinted,
          'created_at': at.toUtc().toIso8601String(),
          'updated_at': at.toUtc().toIso8601String(),
          'created_by': userId,
        });

        // 8-ج) الأسطر: WAC داخل المعاملة قبل الاستهلاك (5.4-3) + FEFO +
        //      المخزون + حركاته — سطراً سطراً.
        var costTotal = 0.0;
        for (var i = 0; i < priced.lines.length; i++) {
          final pricedLine = priced.lines[i];
          final info = products[pricedLine.line.productId]!;
          final lineQty = pricedLine.line.qty;

          // WAC الحالي يُقرأ داخل المعاملة (Snapshot لحظة البيع).
          final costNow = await _readCostInside(txn, info.id);
          final lineCost = info.isService ? 0.0 : roundCost(lineQty * costNow);
          costTotal = roundCost(costTotal + lineCost);

          // تخصيص FEFO للصنوف المتتبعة (AC-05) قبل كتابة السطر.
          FefoResult? fefo;
          if (!info.isService && info.trackBatches) {
            fefo = await _batches.allocateFefo(
              txn,
              productId: info.id,
              warehouseId: draft.warehouseId,
              qty: lineQty,
              asOf: issuedAt,
            );
            if (fefo.shorted) {
              throw _FlowError(
                'الكمية غير متوفرة للصنف «${info.name}»: المتاح '
                '${_num(fefo.allocatedQty)} والمطلوب ${_num(lineQty)} — '
                'لا يسمح النظام بمخزون سالب.',
              );
            }
          }

          final batchSummary = fefo == null || fefo.allocations.isEmpty
              ? null
              : fefo.allocations
                    .map((a) => '${a.batchNumber}×${_num(a.qty)}')
                    .join('، ');
          final lineNotes = [
            if ((pricedLine.line.notes ?? '').trim().isNotEmpty)
              pricedLine.line.notes!.trim(),
            if (batchSummary != null) 'دفعة: $batchSummary',
          ].join(' — ');

          await txn.insert('invoice_item', {
            'invoice_id': invoiceId,
            'product_id': info.id,
            'line_desc': info.name, // لقطة اسم الصنف للعرض/الطباعة.
            'qty': lineQty,
            'unit_id': info.unitId,
            'unit_factor': 1,
            'unit_price': pricedLine.line.unitPrice,
            'discount_percent':
                pricedLine.line.lineDiscountType == SaleDiscountType.percent
                ? pricedLine.line.lineDiscountValue
                : 0,
            'discount_amount': pricedLine.effectiveDiscount,
            'tax_percent': 0,
            'line_total': pricedLine.netFinal,
            'line_cost': lineCost,
            'batch_id': (fefo != null && fefo.allocations.isNotEmpty)
                ? fefo.allocations.first.batchId
                : null,
            'notes': lineNotes.isEmpty ? null : lineNotes,
            'created_at': at.toUtc().toIso8601String(),
          });

          // الأصناف الخدمية: لا مخزون ولا دفعات (التكلفة صفر أعلاه).
          if (info.isService) continue;

          if (fefo != null) {
            // المتتبع: تطبيق الحصص على الدفعات (حارس السالب بداخلها
            // يرمي فتتراجع المعاملة كاملة) + حركة لكل دفعة.
            await _batches.applyAllocation(txn, fefo.allocations, now: at);
            for (final allocation in fefo.allocations) {
              await txn.insert('stock_movement', {
                'product_id': info.id,
                'warehouse_id': draft.warehouseId,
                'movement_type': 'sale',
                'qty': -allocation.qty, // الخروج سالب (اتجاه المخطط).
                'unit_cost': costNow,
                'ref_type': 'invoice',
                'ref_id': invoiceId,
                'moved_at': issuedIso,
                'notes':
                    'رقم الدفعة ${allocation.batchNumber} (تنتهي '
                    '${_dateOnly(allocation.expiryDate)})',
                'created_at': at.toUtc().toIso8601String(),
                'created_by': userId,
              });
            }
          } else {
            // العادي: حركة واحدة للسطر.
            await txn.insert('stock_movement', {
              'product_id': info.id,
              'warehouse_id': draft.warehouseId,
              'movement_type': 'sale',
              'qty': -lineQty,
              'unit_cost': costNow,
              'ref_type': 'invoice',
              'ref_id': invoiceId,
              'moved_at': issuedIso,
              'notes': invoiceNo,
              'created_at': at.toUtc().toIso8601String(),
              'created_by': userId,
            });
          }

          // دفتر stock_level مشترك للنوعين — حارس السالب الصارم:
          // (INSERT OR IGNORE يهيئ صفاً معدوماً ثم الشرط qty >= ? يمنع
          // أي خصم تحت الصفر — بلا استثناء).
          await txn.rawInsert(
            'INSERT OR IGNORE INTO stock_level(product_id, warehouse_id, qty) '
            'VALUES(?, ?, 0)',
            [info.id, draft.warehouseId],
          );
          final consumed = await txn.rawUpdate(
            'UPDATE stock_level SET qty = qty - ? '
            'WHERE product_id = ? AND warehouse_id = ? AND qty >= ?',
            [lineQty, info.id, draft.warehouseId, lineQty],
          );
          if (consumed == 0) {
            throw _FlowError(
              'الكمية غير متوفرة للصنف «${info.name}» بالمخزن — '
              'الرصيد الدفتري أقل من المطلوب (${_num(lineQty)}) — '
              'لا يسمح النظام بمخزون سالب.',
            );
          }
        }

        // 8-د) تجميع التكلفة على رأس الفاتورة (COGS — ملحق و).
        await txn.update(
          'invoice',
          {'cost_total': costTotal},
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        // 8-هـ) الجزء النقدي: سند قبض بالصندوق الافتراضي بعملة الفاتورة
        //       وسعرها + تخصيصه للفاتورة (القرار 2 برأس الملف).
        if (netPaid > moneyEpsilon) {
          final cashTxId = await txn.insert('cash_tx', {
            'tx_type': 'receipt',
            'cashbox_id': cashboxId,
            'currency_id': draft.currencyId,
            'amount': netPaid, // الصافي فقط — الباقي خارج الصندوق.
            'exchange_rate': exchangeRate,
            'tx_date': issuedIso,
            'ref_type': 'invoice',
            'ref_id': invoiceId,
            'customer_id': null, // لا يخصم من رصيد العميل (القرار 2).
            'description': 'تحصيل نقدي عند إصدار $invoiceNo',
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
        // في invoice.due_amount تقرأه صيغة رصيد العميل (FR-03-02).

        // 8-و) تحويل عرض السعر — ذرّياً داخل نفس المعاملة (FR-02-11).
        if (draft.fromQuotationId != null) {
          final converted = await txn.update(
            'quotation',
            {
              'status': 'converted',
              'converted_invoice_id': invoiceId,
              'updated_at': at.toUtc().toIso8601String(),
            },
            where: "id = ? AND status IN ('draft','sent')",
            whereArgs: [draft.fromQuotationId],
          );
          if (converted == 0) {
            throw _FlowError(
              'عرض السعر غير قابل للتحويل — حُوِّل أو أُلغي للتو من جهة أخرى.',
            );
          }
        }

        // 8-ز) قيد التدقيق (append-only — نمط المستودعات القائمة).
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': 'sale_post',
          'entity': 'invoice',
          'entity_id': invoiceId,
          'details':
              'no=$invoiceNo total=${totals.grandTotal} '
              'paid=$netPaid due=$remainingCredit '
              'currency=$currencyCode rate=$exchangeRate'
              '${rateIsFallback ? ' fallback=1' : ''}',
          'at': at.toUtc().toIso8601String(),
        });

        return Ok<SalePostedReceipt, String>(
          SalePostedReceipt(
            invoiceId: invoiceId,
            invoiceNo: invoiceNo,
            totals: totals,
            payStatus: payStatus,
            exchangeRate: exchangeRate,
            rateIsFallback: rateIsFallback,
            changeDue: changeDue,
            remainingCredit: remainingCredit,
          ),
        );
      });
    } on _FlowError catch (e) {
      return Err(e.message);
    } on StateError catch (e) {
      // حراس المستودعات الشريكة (applyAllocation وغيره) — رسالتهم عربية
      // جاهزة وتدحرج المعاملة قبل الوصول هنا.
      return Err(e.message);
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e));
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // القراءات
  // ─────────────────────────────────────────────────────────────────────

  /// تفاصيل فاتورة بيع كاملة: الرأس + البنود + اسم العميل + العملة.
  ///
  /// `null` إن لم توجد (أو ليست فاتورة بيع).
  Future<SaleInvoiceDetail?> invoiceDetail(int invoiceId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT i.*, c.name AS customer_name, c.phone AS customer_phone,
             cu.code AS currency_code, cu.symbol_svg AS currency_symbol
      FROM invoice i
      LEFT JOIN customer c ON c.id = i.customer_id
      JOIN currency cu ON cu.id = i.currency_id
      WHERE i.id = ? AND i.doc_type = 'sale'
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
    return SaleInvoiceDetail(
      invoice: SaleInvoice.fromRow(rows.first),
      items: [for (final row in itemRows) SaleInvoiceItemLine.fromRow(row)],
      customerName: rows.first['customer_name'] as String?,
      customerPhone: rows.first['customer_phone'] as String?,
      currencyCode: rows.first['currency_code'] as String?,
      currencySymbol: rows.first['currency_symbol'] as String?,
    );
  }

  /// آخر فواتير البيع (الأحدث أولاً) — لتقرير/بحث الشاشات.
  Future<List<SaleInvoiceSummary>> recentSales({
    int limit = 50,
    int? customerId,
  }) async {
    final where = [
      "i.doc_type = 'sale'",
      if (customerId != null) 'i.customer_id = ?',
    ].join(' AND ');
    final rows = await _db.rawQuery(
      '''
      SELECT i.id, i.invoice_no, i.issued_at, i.customer_id, i.total,
             i.paid_amount, i.due_amount, i.pay_status, i.status,
             c.name AS customer_name, cu.code AS currency_code
      FROM invoice i
      LEFT JOIN customer c ON c.id = i.customer_id
      JOIN currency cu ON cu.id = i.currency_id
      WHERE $where
      ORDER BY i.issued_at DESC, i.id DESC
      LIMIT ?
    ''',
      [?customerId, limit],
    );
    return [
      for (final row in rows)
        SaleInvoiceSummary(
          id: row['id'] as int,
          invoiceNo: row['invoice_no'] as String,
          issuedAt: DateTime.parse(row['issued_at'] as String),
          customerId: row['customer_id'] as int?,
          customerName: row['customer_name'] as String?,
          currencyCode: row['currency_code'] as String?,
          total: (row['total'] as num?)?.toDouble() ?? 0,
          paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
          dueAmount: (row['due_amount'] as num?)?.toDouble() ?? 0,
          payStatus: SalePaymentMethod.values.firstWhere(
            (m) => m.code == (row['pay_status'] as String),
          ),
          status: row['status'] as String,
        ),
    ];
  }

  /// إجماليات مبيعات فترة (شاملة الطرفين) — بالعملة الأساسية عبر
  /// `total_base` (نفس أساس DashboardRepository — FR-09-01).
  Future<SalesPeriodTotals> salesTotals(DateTime from, DateTime to) async {
    final salesRows = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS n, COALESCE(SUM(total_base), 0) AS s,
             COALESCE(SUM(cost_total), 0) AS c
      FROM invoice
      WHERE doc_type = 'sale' AND status = 'completed'
        AND date(issued_at) >= ? AND date(issued_at) <= ?
    ''',
      [_dateOnly(from), _dateOnly(to)],
    );
    final cashRows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(t.amount), 0) AS a
      FROM cash_tx t
      WHERE t.tx_type = 'receipt' AND t.is_voided = 0
        AND t.ref_type = 'invoice'
        AND EXISTS (
          SELECT 1 FROM invoice i
          WHERE i.id = t.ref_id AND i.doc_type = 'sale'
            AND i.status = 'completed'
            AND date(i.issued_at) >= ? AND date(i.issued_at) <= ?
        )
    ''',
      [_dateOnly(from), _dateOnly(to)],
    );
    return SalesPeriodTotals(
      invoiceCount: (salesRows.first['n'] as int?) ?? 0,
      salesBase: (salesRows.first['s'] as num?)?.toDouble() ?? 0,
      costTotal: (salesRows.first['c'] as num?)?.toDouble() ?? 0,
      cashCollected: (cashRows.first['a'] as num?)?.toDouble() ?? 0,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // مساعدات خاصة
  // ─────────────────────────────────────────────────────────────────────

  /// يحمل معلومات الأصناف المطلوبة (استعلام واحد).
  Future<Map<int, _ProductInfo>> _loadProducts(Set<int> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _db.rawQuery(
      'SELECT id, name, cost_price, is_service, track_batches, is_archived, '
      'unit_id FROM product '
      'WHERE id IN (${List.filled(ids.length, '?').join(',')})',
      ids.toList(),
    );
    return {
      for (final row in rows)
        row['id'] as int: _ProductInfo(
          id: row['id'] as int,
          name: row['name'] as String,
          costPrice: (row['cost_price'] as num?)?.toDouble() ?? 0,
          isService: (row['is_service'] as int? ?? 0) == 1,
          trackBatches: (row['track_batches'] as int? ?? 0) == 1,
          isArchived: (row['is_archived'] as int? ?? 0) == 1,
          unitId: row['unit_id'] as int?,
        ),
    };
  }

  /// يقرأ WAC (cost_price) داخل المعاملة — لحظة الاستهلاك (5.4-3).
  Future<double> _readCostInside(DatabaseExecutor txn, int productId) async {
    final rows = await txn.query(
      'product',
      columns: ['cost_price'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    return (rows.first['cost_price'] as num?)?.toDouble() ?? 0;
  }

  /// فحص توفر المخزون المسبق (قاعدة 5.4-5): يجمع المطلوب لكل صنف غير
  /// خدمي عبر الأسطر (الأسطر المكررة تُجمع) ويقارنه بالمتاح:
  /// العادي من `stock_level`، والمتتبع من دفعات FEFO النشطة غير المنتهية.
  Future<String?> _checkAvailability(
    List<CartLine> lines,
    Map<int, _ProductInfo> products,
    int warehouseId,
    DateTime asOf,
  ) async {
    final requested = <int, double>{};
    for (final line in lines) {
      final info = products[line.productId]!;
      if (info.isService) continue;
      requested[info.id] = (requested[info.id] ?? 0) + line.qty;
    }
    if (requested.isEmpty) return null;

    final cutoff = _dateOnly(asOf);
    final ids = requested.keys.toList();
    final inClause = List.filled(ids.length, '?').join(',');

    // العادي: دفتر stock_level هو الحقيقة.
    final plainRows = await _db.rawQuery(
      'SELECT product_id, qty FROM stock_level '
      'WHERE warehouse_id = ? AND product_id IN ($inClause)',
      [warehouseId, ...ids],
    );
    final plainQty = {
      for (final row in plainRows)
        row['product_id'] as int: (row['qty'] as num?)?.toDouble() ?? 0,
    };

    // المتتبع: مجموع الدفعات النشطة غير المنتهية (نفس شرط FEFO).
    final batchRows = await _db.rawQuery(
      'SELECT product_id, SUM(qty) AS q FROM batch '
      'WHERE warehouse_id = ? AND product_id IN ($inClause) '
      '  AND qty > 0 AND is_archived = 0 AND expiry_date >= ? '
      'GROUP BY product_id',
      [warehouseId, ...ids, cutoff],
    );
    final batchQty = {
      for (final row in batchRows)
        row['product_id'] as int: (row['q'] as num?)?.toDouble() ?? 0,
    };

    for (final entry in requested.entries) {
      final info = products[entry.key]!;
      final available = info.trackBatches
          ? (batchQty[entry.key] ?? 0)
          : (plainQty[entry.key] ?? 0);
      if (available + _qtyEpsilon < entry.value) {
        return 'الكمية غير متوفرة للصنف «${info.name}»: المتاح '
            '${_num(available)} والمطلوب ${_num(entry.value)} — '
            'لا يسمح النظام بمخزون سالب.';
      }
    }
    return null;
  }

  /// يصوغ خطأ قاعدة البيانات بكلمات المستخدم (نمط item_repository).
  String _describeDbError(DatabaseException e) {
    if (e.isUniqueConstraintError()) {
      final text = e.toString();
      if (text.contains('invoice_no')) {
        return 'تعارض في رقم الفاتورة — أعد الحفظ';
      }
      if (text.contains('payment_allocation')) {
        return 'تخصيص مدفوعات مكرر لنفس السند والفاتورة';
      }
      return 'قيمة مكررة تخالف قيد التفرد في القاعدة';
    }
    if (_isCheckFailure(e)) {
      final text = e.toString();
      if (text.contains('stock_level')) {
        return 'المخزون لا يسمح بخصم بهذه الكمية (رصيد سالب ممنوع)';
      }
      if (text.contains('due_amount') || text.contains('paid_amount')) {
        return 'مبالغ الدفع غير متسقة مع إجمالي الفاتورة';
      }
      return 'قيمة تخالف قيد سلامة محاسبي في القاعدة';
    }
    return 'تعذر حفظ الفاتورة في القاعدة: $e';
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

/// `YYYY-MM-DD` بتاريخ التقويم المحلي ليوم العمل (نمط المستودعات).
String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
