/// جزء من تقسيم R18-D3a لمستودع النقدية — مستخرج حرفياً من
/// cash_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/doc_sequence.dart';
import '../../../domain/core/numbers.dart';
import '../../../domain/core/result.dart';
import '../../../domain/services/purchase_pricing.dart';
import '../../../domain/models/cash.dart';
import '../exchange_rate_repository.dart' show ExchangeRateRepository;
import '../settings_repository.dart' show SettingsRepository;
import 'cash_flow_types.dart';
import 'cash_helpers.dart';

// ─────────────────────────────────────────────────────────────────────

/// الفواتير المفتوحة لطرف بعملة — الأقدم أولاً (FIFO).
///
/// المتبقي = `due_amount − تخصيصات السندات المرقمة الحية` (القرار 3).
Future<List<OpenInvoiceLine>> partyOpenInvoices(
  Database db, {
  required VoucherPartyType partyType,
  required int partyId,
  required int currencyId,
}) async {
  final docType = partyType == VoucherPartyType.customer ? 'sale' : 'purchase';
  final partyColumn = partyType == VoucherPartyType.customer
      ? 'customer_id'
      : 'supplier_id';
  final rows = await db.rawQuery(
    '''
    SELECT i.id, i.invoice_no, i.issued_at, i.due_amount,
           COALESCE((
             SELECT SUM(pa.allocated_amount)
             FROM payment_allocation pa
             JOIN cash_tx ct ON ct.id = pa.cash_tx_id
             WHERE pa.invoice_id = i.id
               AND ct.voucher_no IS NOT NULL
               AND ct.is_voided = 0
               AND ct.reversal_of IS NULL
           ), 0) AS voucher_alloc
    FROM invoice i
    WHERE i.doc_type = ? AND i.status = 'completed'
      AND i.$partyColumn = ? AND i.currency_id = ?
      AND i.due_amount > 0
    ORDER BY i.issued_at ASC, i.id ASC
  ''',
    <Object?>[docType, partyId, currencyId],
  );
  return [
    for (final row in rows)
      OpenInvoiceLine(
        invoiceId: row['id'] as int,
        invoiceNo: row['invoice_no'] as String,
        issuedAt: DateTime.parse(row['issued_at'] as String),
        dueAmount: (row['due_amount'] as num?)?.toDouble() ?? 0,
        voucherAllocated: (row['voucher_alloc'] as num?)?.toDouble() ?? 0,
      ),
  ].where((line) => line.remaining > moneyEpsilon).toList();
}

// ─────────────────────────────────────────────────────────────────────
// السند المرقّم (FR-04-02/03/10) — قبض RVT / صرف PMT

// ─────────────────────────────────────────────────────────────────────

/// **ترحيل سند قبض/صرف** — معاملة ذرّية واحدة: رقم RVT/PMT + حركة
/// الصندوق + تحديث دفاتر الفواتير المخصصة (FIFO) + صفوف التخصيص +
/// قيد التدقيق (الخريطة برأس الملف — القرارات 2/3/4).
Future<Result<VoucherPostedReceipt, String>> createVoucherFlow(
  Database db,
  ExchangeRateRepository rates,
  SettingsRepository settings,

  VoucherDraft draft, {
  required int userId,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final txDate = draft.txDate;
  final txIso = txDate.toUtc().toIso8601String();
  final isReceipt = draft.partyType == VoucherPartyType.customer;

  if (draft.amount.isNaN ||
      draft.amount.isInfinite ||
      draft.amount <= moneyEpsilon) {
    return const Err('مبلغ السند يجب أن يكون رقماً أكبر من صفر.');
  }
  final amount = roundMoney(draft.amount);

  try {
    // (1) الصندوق + الطرف + الأسعار (خارج المعاملة — نمط البيع).
    final boxRows = await db.query(
      'cashbox',
      columns: ['name', 'currency_id', 'is_archived'],
      where: 'id = ?',
      whereArgs: [draft.cashboxId],
      limit: 1,
    );
    if (boxRows.isEmpty) {
      return Err('الصندوق رقم #${draft.cashboxId} غير موجود.');
    }
    if ((boxRows.first['is_archived'] as int? ?? 0) == 1) {
      return Err(
        'الصندوق «${boxRows.first['name']}» مؤرشف — اختر صندوقاً نشطاً.',
      );
    }
    final boxCurrencyId = boxRows.first['currency_id'] as int;

    final partyTable = isReceipt ? 'customer' : 'supplier';
    final partyRows = await db.query(
      partyTable,
      columns: ['name', 'is_archived'],
      where: 'id = ?',
      whereArgs: [draft.partyId],
      limit: 1,
    );
    if (partyRows.isEmpty) {
      return Err(
        '${isReceipt ? 'العميل' : 'المورد'} رقم #${draft.partyId} غير موجود.',
      );
    }
    if ((partyRows.first['is_archived'] as int? ?? 0) == 1) {
      return Err(
        '${isReceipt ? 'العميل' : 'المورد'} '
        '«${partyRows.first['name']}» مؤرشف — أزل الأرشفة أولاً.',
      );
    }
    final partyName = partyRows.first['name'] as String;

    final vRate = await cashRateForDay(
      db,
      rates,
      settings,
      draft.currencyId,
      txDate,
    );
    if (vRate == null) {
      return Err(missingRateMessage(draft.currencyId));
    }
    final crossCurrency = draft.currencyId != boxCurrencyId;
    double? settlementRate;
    if (crossCurrency) {
      final boxRate = await cashRateForDay(
        db,
        rates,
        settings,
        boxCurrencyId,
        txDate,
      );
      if (boxRate == null) {
        return Err(missingRateMessage(boxCurrencyId));
      }
      // settlement = وحدات عملة الصندوق لكل وحدة عملة السند.
      settlementRate = roundMoney(vRate.rate / boxRate.rate);
    }

    // (2) خطة التخصيص FIFO (قراءة خارج المعاملة؛ الحراسة داخلها).
    final plan = <VoucherAllocationApplied>[];
    if (draft.allocateFifo) {
      final open = await partyOpenInvoices(
        db,
        partyType: draft.partyType,
        partyId: draft.partyId,
        currencyId: draft.currencyId,
      );
      var left = amount;
      for (final line in open) {
        if (left <= moneyEpsilon) break;
        final alloc = roundMoney(line.remaining < left ? line.remaining : left);
        if (alloc <= moneyEpsilon) continue;
        plan.add(
          VoucherAllocationApplied(
            invoiceId: line.invoiceId,
            invoiceNo: line.invoiceNo,
            amount: alloc,
          ),
        );
        left = roundMoney(left - alloc);
      }
      if (left > moneyEpsilon) {
        return Err(
          'المبلغ ${formatNum(amount)} يتجاوز المديونية المفتوحة '
          '(${formatNum(roundMoney(amount - left))} بعملة السند) — قلّل '
          'المبلغ أو اختر «على الحساب».',
        );
      }
    }

    // (3) فرق الصرف المحقق (القرار 4) — بالعملة الأساسية.
    var fxGainLoss = 0.0;
    if (crossCurrency && plan.isNotEmpty) {
      final paidBase = amount * vRate.rate;
      var bookBase = 0.0;
      for (final alloc in plan) {
        final invRows = await db.query(
          'invoice',
          columns: ['exchange_rate'],
          where: 'id = ?',
          whereArgs: [alloc.invoiceId],
          limit: 1,
        );
        final invRate =
            (invRows.first['exchange_rate'] as num?)?.toDouble() ?? 1;
        bookBase += alloc.amount * invRate;
      }
      // ربح = (ما دخل الشركة بالأساس) − (ما خرج منها بالأساس):
      // القبض: نقود − دين دفتري؛ الصرف: دين دفتري − نقود.
      fxGainLoss = roundMoney(
        isReceipt ? paidBase - bookBase : bookBase - paidBase,
      );
    }

    // (4) المعاملة الواحدة — كل الكتابات أو لا شيء.
    return await db.transaction((txn) async {
      // 4-أ) رقم RVT/PMT ذرّي داخل المعاملة نفسها (قاعدة 5.4-1).
      final year = txDate.year;
      final seqType = isReceipt
          ? DocSequenceType.receiptVoucher
          : DocSequenceType.paymentVoucher;
      final seq = DocSequenceService(txn);
      final number = await seq.nextNumber(seqType, year);
      final voucherNo = formatDocNumber(seqType, year, number);

      final description = composeVoucherDescription(
        isReceipt,
        partyName,
        draft.description,
      );

      final cashTxId = await txn.insert('cash_tx', {
        'tx_type': isReceipt ? 'receipt' : 'payment',
        'cashbox_id': draft.cashboxId,
        'currency_id': draft.currencyId,
        'amount': amount,
        'exchange_rate': vRate.rate,
        'settlement_rate': settlementRate,
        'fx_gain_loss': fxGainLoss,
        'voucher_no': voucherNo,
        'tx_date': txIso,
        // السند المخصص: رابط الطرف فارغ (القرار 2)؛ الحر يحمله ليخصم
        // من رصيد الطرف عبر صيغ FR-03-02/03 القائمة.
        'ref_type': draft.allocateFifo ? 'invoice' : 'on_account',
        'ref_id': null,
        'customer_id': (!isReceipt || draft.allocateFifo)
            ? null
            : draft.partyId,
        'supplier_id': (isReceipt || draft.allocateFifo) ? null : draft.partyId,
        'description': description,
        'created_at': at.toUtc().toIso8601String(),
        'created_by': userId,
      });

      // 4-ب) دفاتر الفواتير المخصصة + صفوف payment_allocation (FIFO).
      for (final alloc in plan) {
        final updated = await txn.rawUpdate(
          'UPDATE invoice SET due_amount = due_amount - ?, '
          'paid_amount = paid_amount + ?, updated_at = ? '
          'WHERE id = ? AND due_amount >= ? - ?',
          <Object>[
            alloc.amount,
            alloc.amount,
            at.toUtc().toIso8601String(),
            alloc.invoiceId,
            alloc.amount,
            moneyEpsilon,
          ],
        );
        if (updated == 0) {
          throw CashFlowError(
            'فاتورة ${alloc.invoiceNo} تغيّر مستحقها من جهة أخرى — '
            'أعد فتح السند وحدّث المديونية.',
          );
        }
        await txn.insert('payment_allocation', {
          'cash_tx_id': cashTxId,
          'invoice_id': alloc.invoiceId,
          'allocated_amount': alloc.amount,
          'allocated_at': at.toUtc().toIso8601String(),
          'created_by': userId,
        });
      }

      // 4-ج) قيد التدقيق.
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': isReceipt ? 'voucher_receipt_post' : 'voucher_payment_post',
        'entity': 'cash_tx',
        'entity_id': cashTxId,
        'details':
            'no=$voucherNo party=$partyName amount=$amount '
            'currency=${draft.currencyId} rate=${vRate.rate}'
            '${crossCurrency ? ' settlement=$settlementRate' : ''} '
            'fx=$fxGainLoss allocations=${plan.length}'
            '${vRate.fallback ? ' fallback=1' : ''}',
        'at': at.toUtc().toIso8601String(),
      });

      return Ok<VoucherPostedReceipt, String>(
        VoucherPostedReceipt(
          cashTxId: cashTxId,
          voucherNo: voucherNo,
          amount: amount,
          currencyCode: '',
          allocations: plan,
          fxGainLoss: fxGainLoss,
        ),
      );
    });
  } on CashFlowError catch (e) {
    return Err(e.message);
  } on StateError catch (e) {
    return Err(e.message);
  } on DatabaseException catch (e) {
    return Err(describeCashDbError(e, 'حفظ السند'));
  }
}

// ─────────────────────────────────────────────────────────────────────
// الحركات السريعة (FR-04-02) — مصروف/مسحوبات/إيداع مالك/تحويل/بنكي
