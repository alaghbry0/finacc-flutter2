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
///   تحديث WAC، ثم `unitCostEffectiveBase = round4(netFinal × سعر يوم
///   الشراء / qty)` ثم
///   `new_cost = (qty_old×cost_old + qty_new×cost_new)/(qty_old+qty_new)`؛
///   وعند `qty_old ≤ 0` تُعتمد `cost_new` مباشرة (AC-03: شراء 10 @100
///   بخصم رأس 10% → التكلفة 90 لا 100).
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
library;

import 'package:sqflite/sqflite.dart';

import '../../core/storage/doc_sequence.dart';
import '../../domain/core/result.dart';
import '../../domain/models/purchase.dart';
import '../../domain/services/purchase_pricing.dart';
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
      _settings = SettingsRepository(db);

  final Database _db;
  final ExchangeRateRepository _rates;
  final SettingsRepository _settings;

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

        // 6-ج) الأسطر: تكلفة الوحدة الفعلية بالعملة الأساسية → WAC →
        //      الدفعة الواردة → السطر → المخزون وحركته — سطراً سطراً.
        var costTotal = 0.0;
        for (final pricedLine in priced.lines) {
          final info = products[pricedLine.line.productId]!;
          final lineQty = pricedLine.line.qty;

          // تكلفة الوحدة الفعلية بالعملة الأساسية — بسعر يوم الشراء
          // (AC-03)؛ الخدمي بلا تكلفة مخزونية (القرار 7).
          final unitCostBase = info.isService
              ? 0.0
              : roundCost(pricedLine.netFinal * exchangeRate / lineQty);
          final lineCost = roundCost(lineQty * unitCostBase);
          costTotal = roundCost(costTotal + lineCost);

          // WAC (5.4-3): يُقرأ ويُحدَّث داخل المعاملة — قلب الشراء.
          if (!info.isService) {
            await _applyWac(txn, productId: info.id, qtyNew: lineQty,
                costNew: unitCostBase, now: at);
          }

          // الدفعة الواردة (القرار 4): متتبع + رقم + صلاحية → صف batch
          // داخل المعاملة مباشرة (createBatch يكتب خارجها فلا يصلح).
          int? batchId;
          final batchNo = pricedLine.line.batchNo?.trim() ?? '';
          if (!info.isService && info.trackBatches && batchNo.isNotEmpty) {
            batchId = await txn.insert('batch', {
              'product_id': info.id,
              'warehouse_id': draft.warehouseId,
              'batch_number': batchNo,
              'expiry_date': _dateOnly(pricedLine.line.expiryDate!),
              'cost_price': unitCostBase,
              'qty': lineQty,
              'created_at': at.toUtc().toIso8601String(),
              'updated_at': at.toUtc().toIso8601String(),
            });
          }

          final lineNotes = [
            if ((pricedLine.line.notes ?? '').trim().isNotEmpty)
              pricedLine.line.notes!.trim(),
            if (batchId != null) 'دفعة: $batchNo×${_num(lineQty)}',
          ].join(' — ');

          await txn.insert('invoice_item', {
            'invoice_id': invoiceId,
            'product_id': info.id,
            'line_desc': info.name, // لقطة اسم الصنف للعرض/الطباعة.
            'qty': lineQty,
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

          // المخزون: زيادة مباشرة (الشراء وارد — لا حارس سالب needed)
          // + حركة واردة بتكلفة الوحدة الفعلية بالأساس.
          await txn.rawInsert(
            'INSERT OR IGNORE INTO stock_level(product_id, warehouse_id, qty) '
            'VALUES(?, ?, 0)',
            [info.id, draft.warehouseId],
          );
          await txn.rawUpdate(
            'UPDATE stock_level SET qty = qty + ? '
            'WHERE product_id = ? AND warehouse_id = ?',
            [lineQty, info.id, draft.warehouseId],
          );
          await txn.insert('stock_movement', {
            'product_id': info.id,
            'warehouse_id': draft.warehouseId,
            'movement_type': 'purchase',
            'qty': lineQty, // الوارد موجب (اتجاه المخطط — عكس البيع).
            'unit_cost': unitCostBase,
            'ref_type': 'invoice',
            'ref_id': invoiceId,
            'moved_at': issuedIso,
            'notes': batchId == null
                ? docNo
                : '$docNo — دفعة $batchNo (تنتهي '
                      '${_dateOnly(pricedLine.line.expiryDate!)})',
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
      items: [
        for (final row in itemRows) PurchaseInvoiceItemLine.fromRow(row),
      ],
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
      {
        'cost_price': newCost,
        'updated_at': now.toUtc().toIso8601String(),
      },
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
