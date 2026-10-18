/// جزء من تقسيم R18-D3a لمستودع المشتريات — مستخرج حرفياً من
/// purchase_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/doc_sequence.dart';
import '../../../domain/core/dates.dart';
import '../../../domain/core/numbers.dart';
import '../../../domain/core/result.dart';
import '../../../domain/services/purchase_pricing.dart';
import '../../../domain/models/purchase.dart';
import '../exchange_rate_repository.dart' show ExchangeRateRepository;
import '../settings_repository.dart' show SettingsRepository;
import 'purchase_flow_types.dart';
import 'purchase_queries.dart';

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
Future<Result<PurchasePostedReceipt, String>> postPurchaseFlow(
  Database db,
  ExchangeRateRepository rates,
  SettingsRepository settings,

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
    final products = await loadPurchaseProducts(db, productIds);
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
    final supplierRows = await db.query(
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
      final boxRows = await db.query(
        'cashbox',
        columns: ['id'],
        where: 'is_default = 1 AND is_archived = 0',
        limit: 1,
      );
      if (boxRows.isEmpty) {
        return const Err('لا يوجد صندوق افتراضي للمنشأة — أنشئ صندوقاً أولاً.');
      }
      cashboxId = boxRows.first['id'] as int;
    }

    // (6) المعاملة الواحدة — كل الكتابات أو لا شيء (5.4-4).
    return await db.transaction((txn) async {
      // 6-أ) رقم PUR ذرّي داخل المعاملة نفسها (قاعدة 5.4-1).
      final year = issuedAt.year; // سنة يوم العمل المحلية.
      final seq = DocSequenceService(txn);
      final number = await seq.nextNumber(DocSequenceType.purchase, year);
      final docNo = formatDocNumber(DocSequenceType.purchase, year, number);

      // 6-ب) رأس الفاتورة (كل الأعمدة وفق §5.3) — رقم فاتورة المورد
      //      الورقي كبادئة موثَّقة داخل الملاحظة الداخلية (القرار 5).
      final totalBase = roundCost(totals.grandTotal * exchangeRate);
      final notesInternal = composeInternalNotes(
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
          await applyWac(
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
            'expiry_date': dateOnly(pricedLine.line.expiryDate!),
            'cost_price': unitCostBase,
            'qty': receivedQty,
            'created_at': at.toUtc().toIso8601String(),
            'updated_at': at.toUtc().toIso8601String(),
          });
        }

        final lineNotes = [
          if ((pricedLine.line.notes ?? '').trim().isNotEmpty)
            pricedLine.line.notes!.trim(),
          if (batchId != null) 'دفعة: $batchNo×${formatNum(receivedQty)}',
          if (freeQty > qtyEpsilon) 'بونص: ${formatNum(freeQty)}',
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
              ? (freeQty > qtyEpsilon
                    ? '$docNo — بونص: ${formatNum(freeQty)}'
                    : docNo)
              : '$docNo — دفعة $batchNo (تنتهي '
                    '${dateOnly(pricedLine.line.expiryDate!)})'
                    '${freeQty > qtyEpsilon ? ' — بونص: ${formatNum(freeQty)}' : ''}',
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
  } on PurchaseFlowError catch (e) {
    return Err(e.message);
  } on StateError catch (e) {
    // حراس المستودعات الشريكة — رسالتهم عربية جاهزة وتدحرج المعاملة.
    return Err(e.message);
  } on DatabaseException catch (e) {
    return Err(describePurchaseDbError(e));
  }
}

// ─────────────────────────────────────────────────────────────────────
// الإبطال (FR-02-15 — R17-c) — حركات معاكسة كاملة، لا حذف فيزيائي
