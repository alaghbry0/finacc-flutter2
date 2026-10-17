/// جزء من تقسيم R18-D3a لمستودع المبيعات — مستخرج حرفياً من
/// sale_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/numbers.dart';
import '../../../domain/core/result.dart';
import '../../../domain/services/sale_pricing.dart';
import '../../../domain/models/invoice_void.dart';
import 'sale_flow_types.dart';
import 'sale_queries.dart';

// ─────────────────────────────────────────────────────────────────────

/// **إبطال فاتورة بيع مكتملة** — معاملة واحدة (انظر رأس الملف § الإبطال).
///
/// [userId] منفّذ الإبطال (المدير — الصلاحية تُحسم في الواجهة)
/// و[reason] سبب اختياري يُخزَّن في قيد التدقيق وحده.
///
/// الترتيب: تحققات مسبقة (نوع/حالة/مرتجعات) → معاملة واحدة (حرارة
/// الحالة ← عكس المخزون ودفعاته ← إبطال سند الإصدار وسطره المعاكس ←
/// استرداد تخصيصات السندات اللاحقة ← `status='void'` ← تدقيق) → إيصال.
Future<Result<VoidInvoiceReceipt, String>> voidSaleInvoiceFlow(
  Database db,

  int invoiceId, {
  required int userId,
  String? reason,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final atIso = at.toUtc().toIso8601String();
  final cleanReason = (reason ?? '').trim();

  try {
    // (1) الفاتورة الأصلية: وجود + نوع + حالة (آلة الحالات 5.4-2).
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
    if (docType != 'sale') {
      return Err(
        'الفاتورة رقم #$invoiceId ليست فاتورة بيع (نوعها «$docType») — '
        'لا يُبطَل من محرك المبيعات إلا بيع.',
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

    // (2) الحارس الملزم: لا إبطال لفاتورة عليها مرتجعات مكتملة
    //     (يُلغى المرتجع أولاً — FR-02-15).
    final returnCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM invoice WHERE original_invoice_id = ? "
            "AND doc_type = 'sale_return' AND status = 'completed'",
            [invoiceId],
          ),
        ) ??
        0;
    if (returnCount > 0) {
      return Err(
        'على الفاتورة ${orig['invoice_no']} مرتجعات مكتملة '
        '($returnCount مرتجع SRN) — عالِج المرتجعات أولاً ثم أبطل '
        'الفاتورة (لا يُبطل مستند وعليه مرتجعات — FR-02-15).',
      );
    }

    // (3) البنود + معلومات الأصناف (خدمي/متتبع).
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
    final products = await loadSaleProducts(db, productIds);

    // (4) المعاملة الواحدة — كل الكتابات أو لا شيء (5.4-4).
    return await db.transaction((txn) async {
      // 4-أ) حرارة الحالة داخل المعاملة (التزامن — لا إبطال مزدوج).
      final guard = await txn.rawQuery(
        'SELECT status, invoice_no FROM invoice WHERE id = ? LIMIT 1',
        [invoiceId],
      );
      final liveStatus = guard.first['status'] as String;
      if (liveStatus != 'completed') {
        throw SaleFlowError(
          'الفاتورة ${guard.first['invoice_no']} تغيّرت حالتها إلى '
          '«$liveStatus» قبل الإبطال — أعد المحاولة.',
        );
      }
      final invoiceNo = guard.first['invoice_no'] as String;
      final warehouseId = orig['warehouse_id'] as int;

      var stockMoves = 0;
      var restoredQty = 0.0;
      var reversalCash = 0.0;
      var cashReversals = 0;
      var voucherRefunds = 0;

      // 4-ب) عكس المخزون بنداً بنداً: المنصرف الكلي (qty + freeQty —
      //      البونص خرج من المخزون فيُرجَع) بتكلفة الوحدة الأصلية.
      for (final item in itemRows) {
        final productId = item['product_id'] as int?;
        if (productId == null) continue;
        final info = products[productId];
        if (info == null || info.isService) continue;

        final qty = (item['qty'] as num?)?.toDouble() ?? 0;
        final freeQty = (item['free_qty'] as num?)?.toDouble() ?? 0;
        final dispatched = roundCost(qty + freeQty);
        if (dispatched <= qtyEpsilon) continue;
        final divisor = dispatched > 0 ? dispatched : 1;
        final snapshotUnit = roundCost(
          ((item['line_cost'] as num?)?.toDouble() ?? 0) / divisor,
        );
        restoredQty = roundCost(restoredQty + dispatched);

        // دفعات البيع الأصلية: ما استُهلك منها في هذه الفاتورة (بلا
        // مرتجعات سابقة — الحارس أعلاه يمنع وجودها).
        final entries =
            <
              ({int batchId, String batchNumber, String expiryDate, double qty})
            >[];
        if (info.trackBatches) {
          final saleMoves = await txn.rawQuery(
            'SELECT notes, qty FROM stock_movement '
            "WHERE movement_type = 'sale' AND ref_type = 'invoice' "
            'AND ref_id = ? AND product_id = ? AND warehouse_id = ? '
            'ORDER BY id ASC',
            [invoiceId, productId, warehouseId],
          );
          final consumed = <String, double>{};
          final order = <String>[];
          for (final move in saleMoves) {
            final match = saleBatchNotePattern.firstMatch(
              (move['notes'] as String?) ?? '',
            );
            if (match == null) continue; // حركة غير دفعية (مخزون عام).
            final key = '${match.group(1)!.trim()}|${match.group(2)!}';
            consumed[key] =
                (consumed[key] ?? 0) - ((move['qty'] as num?)?.toDouble() ?? 0);
            if (!order.contains(key)) order.add(key);
          }
          for (final key in order) {
            final cap = consumed[key] ?? 0;
            if (cap <= qtyEpsilon) continue;
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
            if (batchRows.isEmpty) continue; // غير متتبعة → متبقٍ عام.
            entries.add((
              batchId: batchRows.first['id'] as int,
              batchNumber: parts[0],
              expiryDate: parts[1],
              qty: cap,
            ));
          }
        }

        // زيادة الدفعات الأصلية + حركة عودة لكل دفعة (نمط SRN — القرار 3).
        for (final entry in entries) {
          await txn.rawUpdate(
            'UPDATE batch SET qty = qty + ?, updated_at = ? WHERE id = ?',
            [entry.qty, atIso, entry.batchId],
          );
          await txn.insert('stock_movement', {
            'product_id': productId,
            'warehouse_id': warehouseId,
            'movement_type': 'sale_return',
            'qty': entry.qty, // الوارد موجب.
            'unit_cost': snapshotUnit,
            'ref_type': 'invoice',
            'ref_id': invoiceId,
            'moved_at': atIso,
            'notes':
                'رقم الدفعة ${entry.batchNumber} '
                '(تنتهي ${entry.expiryDate}) — إبطال $invoiceNo',
            'created_at': atIso,
            'created_by': userId,
          });
          stockMoves++;
        }

        // المتبقي بلا دفعة قابلة للتتبع → مخزون عام بحركة مستقلة
        // (dispatched > 0 دائماً هنا فالغير المتتبع يمر من هذا المسار).
        final residual = roundCost(
          dispatched - entries.fold(0.0, (sum, e) => sum + e.qty),
        );
        if (residual > qtyEpsilon) {
          await txn.insert('stock_movement', {
            'product_id': productId,
            'warehouse_id': warehouseId,
            'movement_type': 'sale_return',
            'qty': residual,
            'unit_cost': snapshotUnit,
            'ref_type': 'invoice',
            'ref_id': invoiceId,
            'moved_at': atIso,
            'notes':
                '$invoiceNo — إبطال'
                '${freeQty > qtyEpsilon ? ' (بونص مرتجع: ${formatNum(freeQty)})' : ''}',
            'created_at': atIso,
            'created_by': userId,
          });
          stockMoves++;
        }

        // دفتر stock_level للنوعين — زيادة مباشرة (لا خطر سالب).
        await txn.rawInsert(
          'INSERT OR IGNORE INTO stock_level(product_id, warehouse_id, qty) '
          'VALUES(?, ?, 0)',
          [productId, warehouseId],
        );
        await txn.rawUpdate(
          'UPDATE stock_level SET qty = qty + ? '
          'WHERE product_id = ? AND warehouse_id = ?',
          [dispatched, productId, warehouseId],
        );
      }

      // 4-ج) عكس الصندوق (أ) سند الإصدار: نمط voidMovement حرفياً —
      //      is_voided=1 على الأصل + سطر معاكس حي مستبعد من الأرصدة
      //      عبر reversal_of + حذف روابط التخصيص (رابط لا حركة).
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
              'إبطال تحصيل $invoiceNo'
              '${cleanReason.isEmpty ? '' : ' — $cleanReason'}',
          'created_at': atIso,
          'created_by': userId,
        });
        reversalCash = roundMoney(
          reversalCash + ((tx['amount'] as num?)?.toDouble() ?? 0),
        );
        cashReversals++;
      }

      // 4-د) عكس الصندوق (ب) تخصيصات السندات اللاحقة (RVT FIFO على
      //      الفاتورة): حركة استرداد حقيقية معاكسة الاتجاه (محسوبة في
      //      الأرصدة فتصفّي أثر السند) + حذف رابط التخصيص + عكس نصيب
      //      الفاتورة من فرق الصرف المحقق.
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
        // نصيب الفاتورة من fx المحقق (صيغة createVoucher — رأس ملف
        // cash_repository): القبض (vRate−invRate) والصرف (invRate−vRate).
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
            'no=$invoiceNo doc_type=sale '
            'reason=${cleanReason.isEmpty ? '-' : cleanReason} '
            'reversed_cash=${formatNum(reversalCash)} '
            'restored_qty=${formatNum(restoredQty)} '
            'stock_moves=$stockMoves cash_reversals=$cashReversals '
            'voucher_refunds=$voucherRefunds total=${orig['total']} '
            'paid=${orig['paid_amount']} due=${orig['due_amount']}',
        'at': atIso,
      });

      return Ok<VoidInvoiceReceipt, String>(
        VoidInvoiceReceipt(
          invoiceId: invoiceId,
          invoiceNo: invoiceNo,
          docType: 'sale',
          stockMovementCount: stockMoves,
          cashReversalCount: cashReversals,
          voucherRefundCount: voucherRefunds,
          reversedCash: reversalCash,
          reversedQty: restoredQty,
        ),
      );
    });
  } on SaleFlowError catch (e) {
    return Err(e.message);
  } on StateError catch (e) {
    return Err(e.message);
  } on DatabaseException catch (e) {
    return Err(describeSaleDbError(e));
  }
}

// ─────────────────────────────────────────────────────────────────────
// القراءات
