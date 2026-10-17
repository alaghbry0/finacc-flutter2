/// جزء من تقسيم R18-D3a لمستودع المبيعات — مستخرج حرفياً من
/// sale_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/doc_sequence.dart';
import '../../../domain/core/dates.dart';
import '../../../domain/core/numbers.dart';
import '../../../domain/core/result.dart';
import '../../../domain/services/sale_pricing.dart';
import '../../../domain/models/batch.dart';
import '../../../domain/models/sale.dart';
import '../batch_repository.dart' show BatchRepository;
import '../customer_repository.dart' show CustomerRepository;
import '../exchange_rate_repository.dart' show ExchangeRateRepository;
import '../settings_repository.dart' show SettingsRepository;
import 'sale_flow_types.dart';
import 'sale_queries.dart';

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
Future<Result<SalePostedReceipt, String>> postSaleFlow(
  Database db,
  ExchangeRateRepository rates,
  SettingsRepository settings,
  CustomerRepository customers,
  BatchRepository batches,

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
    final currency = await db.query(
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
      final todayRate = await rates.rateFor(draft.currencyId, issuedAt);
      if (todayRate != null && todayRate > 0) {
        exchangeRate = todayRate;
      } else {
        final fallbackOn =
            (await settings.getString('fx.fallback', 'off')) == 'last_known';
        if (!fallbackOn) {
          return Err(
            'لا يوجد سعر صرف لعملة $currencyCode بتاريخ اليوم — '
            'أدخل سعر اليوم أولاً ثم احفظ (لا يُحفظ بسعر افتراضي).',
          );
        }
        final lastKnown = await rates.latestBefore(draft.currencyId, issuedAt);
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
    final products = await loadSaleProducts(db, productIds);
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
    final stockFailure = await checkSaleAvailability(
      db,
      draft.lines,
      products,
      draft.warehouseId,
      issuedAt,
    );
    if (stockFailure != null) return Err(stockFailure);

    // (5) العميل + حد الائتمان (FR-03-05) — الآجل فقط.
    if (draft.customerId != null) {
      final customerRows = await db.query(
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
        final credit = await customers.checkCredit(
          draft.customerId!,
          draft.currencyId,
          remainingCredit,
        );
        if (credit.overLimit) {
          // FR-03-05 (17-c): السلوك من إعداد parties.credit_limit_action
          // — 'block' يرفض هنا نهائياً؛ 'warn' (الافتراضي) حواره في
          // PaymentSheet («متابعة على أي حال») وقد أقرّه المستخدم،
          // فلا يمنع الترحيل — هذا المستودع حارس 'block' حصراً.
          final action = await settings.getString(
            'parties.credit_limit_action',
            'warn',
          );
          if (action == 'block') {
            return Err(
              'تجاوز حد الائتمان: رصيد العميل الحالي ${formatNum(credit.balance)} '
              '+ الآجل الجديد ${formatNum(remainingCredit)} يتجاوز الحد '
              '${formatNum(credit.creditLimit ?? 0)} — قلّل الآجل أو استوفِ أولاً.',
            );
          }
        }
      }
    }

    // (6) الصندوق الافتراضي للمنشأة — للجزء النقدي فقط.
    int? cashboxId;
    if (netPaid > moneyEpsilon) {
      final boxRows = await db.query(
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
      final quoteRows = await db.query(
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
    return await db.transaction((txn) async {
      // 8-أ) رقم INV ذرّي داخل المعاملة نفسها (قاعدة 5.4-1).
      final year = issuedAt.year; // سنة يوم العمل المحلية.
      final seq = DocSequenceService(txn);
      final number = await seq.nextNumber(DocSequenceType.invoice, year);
      final invoiceNo = formatDocNumber(DocSequenceType.invoice, year, number);

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
      //      المخزون + حركاته — سطراً سطراً. البونص (UX-4): المنصرف
      //      الكلي = المدفوع + المجاني على المخزون/الدفعات/التكلفة.
      var costTotal = 0.0;
      var freeTotal = 0.0;
      for (var i = 0; i < priced.lines.length; i++) {
        final pricedLine = priced.lines[i];
        final info = products[pricedLine.line.productId]!;
        final lineQty = pricedLine.line.qty;
        final freeQty = pricedLine.line.freeQty;
        freeTotal += freeQty;
        // المنصرف الكلي (القرار 7) — البونص وحدات حقيقية تخرج من
        // المخزون وتكلفتها تدخل COGS.
        final dispatchedQty = lineQty + freeQty;

        // WAC الحالي يُقرأ داخل المعاملة (Snapshot لحظة البيع) — على
        // المنصرف الكلي.
        final costNow = await readCostInside(txn, info.id);
        final lineCost = info.isService
            ? 0.0
            : roundCost(dispatchedQty * costNow);
        costTotal = roundCost(costTotal + lineCost);

        // تخصيص FEFO للصنوف المتتبعة (AC-05) قبل كتابة السطر — على
        // المنصرف الكلي.
        FefoResult? fefo;
        if (!info.isService && info.trackBatches) {
          fefo = await batches.allocateFefo(
            txn,
            productId: info.id,
            warehouseId: draft.warehouseId,
            qty: dispatchedQty,
            asOf: issuedAt,
          );
          if (fefo.shorted) {
            throw SaleFlowError(
              'الكمية غير متوفرة للصنف «${info.name}»: المتاح '
              '${formatNum(fefo.allocatedQty)} والمطلوب ${formatNum(dispatchedQty)}'
              '${freeQty > qtyEpsilon ? ' (منها ${formatNum(freeQty)} مجاني)' : ''} — '
              'لا يسمح النظام بمخزون سالب.',
            );
          }
        }

        final batchSummary = fefo == null || fefo.allocations.isEmpty
            ? null
            : fefo.allocations
                  .map((a) => '${a.batchNumber}×${formatNum(a.qty)}')
                  .join('، ');
        final lineNotes = [
          if ((pricedLine.line.notes ?? '').trim().isNotEmpty)
            pricedLine.line.notes!.trim(),
          if (freeQty > qtyEpsilon) 'بونص: ${formatNum(freeQty)}',
          if (batchSummary != null) 'دفعة: $batchSummary',
        ].join(' — ');

        await txn.insert('invoice_item', {
          'invoice_id': invoiceId,
          'product_id': info.id,
          'line_desc': info.name, // لقطة اسم الصنف للعرض/الطباعة.
          'qty': lineQty,
          'free_qty': freeQty, // البونص مستقل (UX-4 — القرار 7).
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
          await batches.applyAllocation(txn, fefo.allocations, now: at);
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
                  '${dateOnly(allocation.expiryDate)})'
                  '${freeQty > qtyEpsilon ? ' — بونص: ${formatNum(freeQty)}' : ''}',
              'created_at': at.toUtc().toIso8601String(),
              'created_by': userId,
            });
          }
        } else {
          // العادي: حركة واحدة للسطر — بمنصرفه الكلي وبوسم البونص.
          await txn.insert('stock_movement', {
            'product_id': info.id,
            'warehouse_id': draft.warehouseId,
            'movement_type': 'sale',
            'qty': -dispatchedQty,
            'unit_cost': costNow,
            'ref_type': 'invoice',
            'ref_id': invoiceId,
            'moved_at': issuedIso,
            'notes': freeQty > qtyEpsilon
                ? '$invoiceNo — بونص: ${formatNum(freeQty)}'
                : invoiceNo,
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
          [dispatchedQty, info.id, draft.warehouseId, dispatchedQty],
        );
        if (consumed == 0) {
          throw SaleFlowError(
            'الكمية غير متوفرة للصنف «${info.name}» بالمخزن — '
            'الرصيد الدفتري أقل من المطلوب (${formatNum(dispatchedQty)}'
            '${freeQty > qtyEpsilon ? ' منها ${formatNum(freeQty)} مجاني' : ''}) — '
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
          throw SaleFlowError(
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
            '${rateIsFallback ? ' fallback=1' : ''}'
            '${freeTotal > qtyEpsilon ? ' free=${formatNum(freeTotal)}' : ''}',
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
  } on SaleFlowError catch (e) {
    return Err(e.message);
  } on StateError catch (e) {
    // حراس المستودعات الشريكة (applyAllocation وغيره) — رسالتهم عربية
    // جاهزة وتدحرج المعاملة قبل الوصول هنا.
    return Err(e.message);
  } on DatabaseException catch (e) {
    return Err(describeSaleDbError(e));
  }
}

// ─────────────────────────────────────────────────────────────────────
// الإبطال (FR-02-15 — R17-c) — حركات معاكسة كاملة، لا حذف فيزيائي
