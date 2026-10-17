/// جزء من تقسيم R18-D3a لمستودع المشتريات — مستخرج حرفياً من
/// purchase_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/dates.dart';
import '../../../domain/core/numbers.dart';
import '../../../domain/core/result.dart';
import '../../../domain/services/purchase_pricing.dart';
import '../../../domain/models/invoice_void.dart';
import '../batch_repository.dart' show BatchRepository;
import 'purchase_flow_types.dart';
import 'purchase_queries.dart';

// ─────────────────────────────────────────────────────────────────────

/// **إبطال فاتورة شراء مكتملة** — معاملة واحدة (انظر رأس الملف
/// § الإبطال). [userId] منفّذ الإبطال و[reason] سبب اختياري للتدقيق.
///
/// الترتيب: تحققات مسبقة (نوع/حالة/مرتجعات/توفر المخزون) → معاملة
/// واحدة (حرارة الحالة ← خصم الوارد الكلي ودفعاته Snapshot ← إعادة
/// حساب WAC ← إبطال سند الإصدار وسطره المعاكس ← استرداد تخصيصات
/// السندات اللاحقة ← `status='void'` ← تدقيق) → إيصال.
Future<Result<VoidInvoiceReceipt, String>> voidPurchaseInvoiceFlow(
  Database db,
  BatchRepository batches,

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
    final rows = await db.query(
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
          await db.rawQuery(
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
    final itemRows = await db.query(
      'invoice_item',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'id ASC',
    );
    final productIds = {
      for (final item in itemRows)
        if (item['product_id'] != null) item['product_id'] as int,
    };
    final products = await loadPurchaseProducts(db, productIds);
    final warehouseId = orig['warehouse_id'] as int;
    final stockFailure = await checkVoidStock(
      db,
      itemRows,
      products,
      warehouseId,
    );
    if (stockFailure != null) return Err(stockFailure);

    // (4) المعاملة الواحدة — كل الكتابات أو لا شيء (5.4-4).
    return await db.transaction((txn) async {
      // 4-أ) حرارة الحالة داخل المعاملة (التزامن — لا إبطال مزدوج).
      final guard = await txn.rawQuery(
        'SELECT status, invoice_no FROM invoice WHERE id = ? LIMIT 1',
        [invoiceId],
      );
      final liveStatus = guard.first['status'] as String;
      if (liveStatus != 'completed') {
        throw PurchaseFlowError(
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
        if (received <= qtyEpsilon) continue;
        final divisor = received > 0 ? received : 1;
        final snapshotUnit = roundCost(
          ((item['line_cost'] as num?)?.toDouble() ?? 0) / divisor,
        );
        reversedQtyTotal = roundCost(reversedQtyTotal + received);

        // WAC قبل الخصم: المخزون الكلي والتكلفة داخل المعاملة (القرار 1).
        final wacBefore = await readPurchaseWacState(txn, productId);

        // خصم الدفعات (مرآة PRN — القرار 4): الواردة الأصلية أولاً
        // (بمعرّفها المخزَّن وقت الشراء) ثم FEFO للمتبقي (المنتهية
        // مشمولة — إرجاعها للمورد جائز) — حارس السالب بداخلها يرمي.
        final deductions =
            <
              ({int batchId, String batchNumber, String expiryDate, double qty})
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
              if (take > qtyEpsilon) {
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
          if (remaining > qtyEpsilon) {
            final fefo = await batches.allocateFefo(
              txn,
              productId: productId,
              warehouseId: warehouseId,
              qty: remaining,
              asOf: at,
              includeExpired: true,
            );
            if (fefo.shorted) {
              throw PurchaseFlowError(
                'الكمية غير متوفرة بدفعات الصنف «${info.name}»: المتاح '
                '${formatNum(received - remaining + fefo.allocatedQty)} '
                'والمطلوب ${formatNum(received)} — لا يسمح النظام بمخزون سالب.',
              );
            }
            await batches.applyAllocation(txn, fefo.allocations, now: at);
            for (final a in fefo.allocations) {
              deductions.add((
                batchId: a.batchId,
                batchNumber: a.batchNumber,
                expiryDate: dateOnly(a.expiryDate),
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
                '${freeQty > qtyEpsilon ? ' (بونص خارج: ${formatNum(freeQty)})' : ''}',
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
          throw PurchaseFlowError(
            'الكمية غير متوفرة للصنف «${info.name}» بالمخزن — الرصيد '
            'الدفتري أقل من المطلوب إخراجه (${formatNum(received)}) — لا '
            'يسمح النظام بمخزون سالب (ما بِيع من الوارد لا يُبطَل شراؤه).',
          );
        }

        // إعادة حساب WAC على المتبقي (بصيغة PRN حرفياً — قاعدة 5.4-3).
        final remainingQty = wacBefore.qty - received;
        double newCost;
        if (remainingQty <= qtyEpsilon) {
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
            'reversed_cash=${formatNum(reversalCash)} '
            'reversed_qty=${formatNum(reversedQtyTotal)} '
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
  } on PurchaseFlowError catch (e) {
    return Err(e.message);
  } on StateError catch (e) {
    return Err(e.message);
  } on DatabaseException catch (e) {
    return Err(describePurchaseDbError(e));
  }
}

// ─────────────────────────────────────────────────────────────────────
// القراءات
