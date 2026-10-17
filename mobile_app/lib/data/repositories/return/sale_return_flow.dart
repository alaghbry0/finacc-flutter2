/// تدفق ترحيل مرتجع البيع (SRN) — المعاملة الواحدة الكاملة. مُستخرج
/// حرفياً من ReturnRepository.postSaleReturn ضمن تقسيم R18-D3a.

/// **ترحيل مرتجع بيع مرتبط** — معاملة واحدة (انظر رأس الملف).
///
/// الكمية تعود لمخزن الفاتورة الأصلية **بتكلفة line_cost الأصلية**
/// (لا WAC الجاري — قاعدة 5.4-3) وإلى دفعات البيع الأصلية عند تتبعها
/// (القرار 3)، والقيمة تُرد نقداً من الصندوق أو خصماً من حساب العميل
/// (القرار 2).
library;

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/doc_sequence.dart';
import '../../../domain/core/numbers.dart';
import '../../../domain/core/result.dart';
import '../../../domain/services/purchase_pricing.dart';
import '../exchange_rate_repository.dart' show ExchangeRateRepository;
import 'return_flow_types.dart';
import 'return_helpers.dart';
import 'return_models.dart';
import 'return_queries.dart';
import '../settings_repository.dart' show SettingsRepository;

Future<Result<ReturnPostedReceipt, String>> postSaleReturnFlow(
  Database db,
  ExchangeRateRepository rates,
  SettingsRepository settings,
  SaleReturnDraft draft, {
  required int userId,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final issuedAt = draft.issuedAt;
  final issuedIso = issuedAt.toUtc().toIso8601String();

  // (1) تحقق نقي من البنود — قبل أي قراءة/كتابة.
  final linesFailure = validateReturnLines(draft.lines);
  if (linesFailure != null) return Err(linesFailure);

  try {
    // (2) الفاتورة الأصلية: نوع + حالة + وجود (FR-02-07).
    final orig = await loadOriginalInvoice(db, draft.originalInvoiceId, 'sale');
    if (orig.error != null) return Err(orig.error!);

    // (3) البنود الأصلية + المنتسب + سقف الكميات (القرار 1).
    final membership = await checkMembershipAndCaps(
      db,
      draft.originalInvoiceId,
      'sale_return',
      draft.lines,
    );
    if (membership.error != null) return Err(membership.error!);
    final origItems = membership.items;

    // (4) قيمة المرتجع Snapshot من البنود الأصلية (القرار 6).
    final valued = valueReturnLines(origItems, draft.lines);
    final refundTotal = valued.refundTotal;

    // (5) اتجاه الرد مقابل الأرقام (القرار 2).
    final refundFailure = validateRefundDirection(
      refundTotal,
      draft.refundCash,
      draft.refundMethod,
    );
    if (refundFailure != null) return Err(refundFailure);
    final settlement = settleRefund(refundTotal, draft.refundCash);
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
    final fx = await resolveReturnRate(
      db,
      rates,
      settings,
      orig.row['currency_id'] as int,
      issuedAt,
    );
    if (fx.error != null) return Err(fx.error!);

    // (8) الصندوق الافتراضي — للجزء النقدي فقط.
    int? cashboxId;
    if (refundCash > moneyEpsilon) {
      final boxId = await defaultCashboxId(db);
      if (boxId == null) {
        return Err('لا يوجد صندوق افتراضي للمنشأة — أنشئ صندوقاً أولاً.');
      }
      cashboxId = boxId;
    }

    // (9) معلومات الأصناف (خدمي/متتبع).
    final products = await loadProductsForReturnItems(db, origItems);

    // (10) المعاملة الواحدة — كل الكتابات أو لا شيء (5.4-4).
    return await db.transaction((txn) async {
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
      await assertReturnCapsInside(
        txn,
        draft.originalInvoiceId,
        'sale_return',
        draft.lines,
      );

      // 10-د) البنود: تكلفة أصلية منقولة + عودة الكمية للمخزون
      //       (ودفعات البيع الأصلية — القرار 3). سعات الدفعات تُحمَّل
      //       مرة لكل صنف وتتقاسمها البنود في الذاكرة.
      final batchCaps = <int, List<ReturnBatchCap>>{};
      for (var i = 0; i < draft.lines.length; i++) {
        final input = draft.lines[i];
        final origItem = origItems[input.invoiceItemId]!;
        final productId = origItem['product_id'] as int?;
        final info = productId == null ? null : products[productId];
        final lineQty = input.qty;

        // Snapshot تكلفة الوحدة الأصلية (بالعملة الأساسية) — على
        // المنصرف الكلي (البونص داخل line_cost — القرار 8).
        final snapshotUnit = roundCost(
          (origItem['line_cost'] as num? ?? 0) / dispatchedDivisor(origItem),
        );
        final lineCost = roundCost(lineQty * snapshotUnit);

        // سعات دفعات الصنف (استهلاك البيع الأصلي − ما أُعيد سابقاً).
        List<ReturnBatchCap>? caps;
        if (info != null && info.trackBatches && productId != null) {
          var productCaps = batchCaps[productId];
          if (productCaps == null) {
            productCaps = await loadBatchReturnCaps(
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
        final entries = <ReturnBatchCap>[];
        var remaining = lineQty;
        if (caps != null) {
          for (final cap in caps) {
            if (remaining <= qtyEpsilon) break;
            if (cap.qty <= qtyEpsilon) continue;
            final take = cap.qty < remaining ? cap.qty : remaining;
            entries.add(
              ReturnBatchCap(
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
            : entries
                  .map((e) => '${e.batchNumber}×${formatNum(e.qty)}')
                  .join('، ');
        final lineNotes = [
          'أصل البند #${input.invoiceItemId}',
          if (batchSummary != null) 'دفعة: $batchSummary',
          if (residual > qtyEpsilon)
            'مرتجع بلا دفعة (${formatNum(residual)} أضيف للمخزون العام)',
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
        if (residual > qtyEpsilon) {
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
  } on ReturnFlowError catch (e) {
    return Err(e.message);
  } on StateError catch (e) {
    return Err(e.message);
  } on DatabaseException catch (e) {
    return Err(describeReturnDbError(e));
  }
}
