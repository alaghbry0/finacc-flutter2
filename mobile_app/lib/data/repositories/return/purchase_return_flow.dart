/// تدفق ترحيل مرتجع الشراء (PRN) — المعاملة الواحدة الكاملة. مُستخرج
/// حرفياً من ReturnRepository.postPurchaseReturn ضمن تقسيم R18-D3a.

/// **ترحيل مرتجع شراء مرتبط** — معاملة واحدة (انظر رأس الملف).
///
/// الكمية تخرج من مخزن الفاتورة الأصلية **بسعر حركة الشراء الأصلية
/// (Snapshot)** من الدفعة الواردة أولاً (القرار 4)، وWAC يُعاد حسابه
/// على المتبقي (قاعدة 5.4-3)، والقيمة تُسترد نقداً إلى الصندوق أو خصماً
/// من دين المورد (القرار 2).
library;

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/doc_sequence.dart';
import '../../../domain/core/dates.dart';
import '../../../domain/core/numbers.dart';
import '../../../domain/core/result.dart';
import '../../../domain/services/purchase_pricing.dart';
import '../batch_repository.dart' show BatchRepository;
import '../exchange_rate_repository.dart' show ExchangeRateRepository;
import 'return_flow_types.dart';
import 'return_helpers.dart';
import 'return_models.dart';
import 'return_queries.dart';
import '../settings_repository.dart' show SettingsRepository;

Future<Result<ReturnPostedReceipt, String>> postPurchaseReturnFlow(
  Database db,
  BatchRepository batches,
  ExchangeRateRepository rates,
  SettingsRepository settings,
  PurchaseReturnDraft draft, {
  required int userId,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final issuedAt = draft.issuedAt;
  final issuedIso = issuedAt.toUtc().toIso8601String();

  // (1) تحقق نقي من البنود.
  final linesFailure = validateReturnLines(draft.lines);
  if (linesFailure != null) return Err(linesFailure);

  try {
    // (2) الفاتورة الأصلية: نوع + حالة + وجود.
    final orig = await loadOriginalInvoice(
      db,
      draft.originalInvoiceId,
      'purchase',
    );
    if (orig.error != null) return Err(orig.error!);

    // (3) البنود + المنتسب + السقف (المشترى − المرتجع سابقاً).
    final membership = await checkMembershipAndCaps(
      db,
      draft.originalInvoiceId,
      'purchase_return',
      draft.lines,
    );
    if (membership.error != null) return Err(membership.error!);
    final origItems = membership.items;

    // (4) قيمة الاسترداد Snapshot (القرار 6).
    final valued = valueReturnLines(origItems, draft.lines);
    final refundTotal = valued.refundTotal;

    // (5) اتجاه الرد (القرار 2).
    final refundFailure = validateRefundDirection(
      refundTotal,
      draft.refundCash,
      draft.refundMethod,
    );
    if (refundFailure != null) return Err(refundFailure);
    final settlement = settleRefund(refundTotal, draft.refundCash);
    final refundCash = settlement.netCash;
    final refundCredit = settlement.credit;

    // (6) المورد للجزء المخصوم من دينه.
    if (refundCredit > moneyEpsilon && orig.row['supplier_id'] == null) {
      return const Err(
        'فاتورة الشراء الأصلية بلا مورد مسجَّل — لا حساب يُخصم منه؛ '
        'اختر الاسترداد نقداً إلى الصندوق.',
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
        return const Err('لا يوجد صندوق افتراضي للمنشأة — أنشئ صندوقاً أولاً.');
      }
      cashboxId = boxId;
    }

    // (9) معلومات الأصناف + فحص توفر المخزون مسبقاً (5.4-5).
    final products = await loadProductsForReturnItems(db, origItems);
    final stockFailure = await checkPurchaseReturnStock(
      db,
      origItems,
      products,
      draft.lines,
      orig.row['warehouse_id'] as int,
    );
    if (stockFailure != null) return Err(stockFailure);

    // (10) المعاملة الواحدة — كل الكتابات أو لا شيء (5.4-4).
    return await db.transaction((txn) async {
      // 10-أ) رقم PRN ذرّي (قاعدة 5.4-1).
      final year = issuedAt.year;
      final seq = DocSequenceService(txn);
      final number = await seq.nextNumber(DocSequenceType.purchaseReturn, year);
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
      await assertReturnCapsInside(
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

        // Snapshot تكلفة الوحدة الأصلية (بالعملة الأساسية) — مقسوم
        // المستلم الكلي (R16-a: بونص الشراء داخل line_cost — القسمة
        // على qty + free_qty تعيد تكلفة الوحدة الفعلية وقت الشراء).
        final snapshotUnit = roundCost(
          (origItem['line_cost'] as num? ?? 0) / dispatchedDivisor(origItem),
        );
        final lineCost = roundCost(lineQty * snapshotUnit);

        // WAC قبل الخصم: يُقرأ المخزون الكلي والتكلفة داخل المعاملة.
        final wacBefore = (info == null || info.isService || productId == null)
            ? null
            : await readWacState(txn, productId);

        // خصم الدفعات (القرار 4): الواردة الأصلية أولاً ثم FEFO للمتبقي.
        final deductions = <ReturnBatchCap>[];
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
              if (take > qtyEpsilon) {
                final affected = await txn.rawUpdate(
                  'UPDATE batch SET qty = qty - ?, updated_at = ? '
                  'WHERE id = ? AND qty >= ?',
                  [take, at.toUtc().toIso8601String(), originalBatchId, take],
                );
                if (affected > 0) {
                  deductions.add(
                    ReturnBatchCap(
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
          if (remaining > qtyEpsilon) {
            final fefo = await batches.allocateFefo(
              txn,
              productId: productId,
              warehouseId: orig.row['warehouse_id'] as int,
              qty: remaining,
              asOf: issuedAt,
              includeExpired: true,
            );
            if (fefo.shorted) {
              throw ReturnFlowError(
                'الكمية غير متوفرة بدفعات الصنف '
                '«${info.name}»: المتاح '
                '${formatNum(lineQty - remaining + fefo.allocatedQty)} '
                'والمطلوب ${formatNum(lineQty)} — لا يسمح النظام بمخزون سالب.',
              );
            }
            await batches.applyAllocation(txn, fefo.allocations, now: at);
            for (final a in fefo.allocations) {
              deductions.add(
                ReturnBatchCap(
                  batchId: a.batchId,
                  batchNumber: a.batchNumber,
                  expiryDate: dateOnly(a.expiryDate),
                  qty: a.qty,
                ),
              );
            }
          }
        }

        final batchSummary = deductions.isEmpty
            ? null
            : deductions
                  .map((d) => '${d.batchNumber}×${formatNum(d.qty)}')
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
          throw ReturnFlowError(
            'الكمية غير متوفرة للصنف «${info.name}» بالمخزن — '
            'الرصيد الدفتري أقل من المطلوب (${formatNum(lineQty)}) — '
            'لا يسمح النظام بمخزون سالب.',
          );
        }

        // إعادة حساب WAC على المتبقي (قاعدة 5.4-3 — Snapshot).
        if (wacBefore != null) {
          final remainingQty = wacBefore.qty - lineQty;
          double newCost;
          if (remainingQty <= qtyEpsilon) {
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
            {'cost_price': newCost, 'updated_at': at.toUtc().toIso8601String()},
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
  } on ReturnFlowError catch (e) {
    return Err(e.message);
  } on StateError catch (e) {
    return Err(e.message);
  } on DatabaseException catch (e) {
    return Err(describeReturnDbError(e));
  }
}
