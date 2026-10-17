/// جزء من تقسيم R18-D3a لمستودع النقدية — مستخرج حرفياً من
/// cash_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/result.dart';
import '../../../domain/services/purchase_pricing.dart' show moneyEpsilon;
import '../../../domain/models/cash.dart';
import 'cash_flow_types.dart';
import 'cash_helpers.dart';

// ─────────────────────────────────────────────────────────────────────

/// **إبطال حركة** — معاملة واحدة: حركة معاكسة (بإشارات مستعادة —
/// للتحويل باعتبار الساقين معكوسة) + `is_voided=1` على الأصل +
/// استرجاع دفاتر الفواتير + حذف روابط التخصيص + قيد تدقيق.
///
/// القيود: حركة ملغاة/معاكسة لا تُبطل؛ الحركات المرتبطة بمستند آخر
/// (تحصيل الإصدار/رد المرتجع) تُبطل عبر مستنداتها؛ الأنواع المؤجلة
/// (V1.1) مرفوضة برسالة واضحة. **الرقم المرقّم لا يُعاد أبداً.**
Future<Result<int, String>> voidCashMovementFlow(
  Database db,

  int id, {
  required int userId,
  String? reason,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();

  try {
    // تحققات مسبقة (خارج المعاملة — قراءة فقط).
    final rows = await db.query('cash_tx', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) {
      return Err('الحركة رقم #$id غير موجودة.');
    }
    final orig = rows.first;
    if ((orig['is_voided'] as int? ?? 0) == 1) {
      return const Err('هذه الحركة ملغاة سابقاً — لا تُبطل مرتين.');
    }
    if (orig['reversal_of'] != null) {
      return const Err(
        'هذه حركة معاكسة لإبطال سابق — لا تُبطل الحركات المعاكسة.',
      );
    }
    final type = CashTxType.tryParse(orig['tx_type'] as String);
    if (type == null) {
      return const Err(
        'نوع الحركة من وحدة مؤجلة (V1.1) — لا يُدعم إبطالها هنا بعد.',
      );
    }
    if (type == CashTxType.opening) {
      return const Err(
        'حركة الافتتاح لا تُبطل مباشرة — عدّل الرصيد الافتتاحي من مصدره.',
      );
    }
    final refType = orig['ref_type'] as String?;
    final refId = orig['ref_id'] as int?;
    if (refType == 'invoice' && refId != null) {
      return const Err(
        'هذه الحركة مرتبطة بمستند (فاتورة/مرتجع) — تُبطل عبر إبطال '
        'المستند نفسه من وحدته، لا من سجل الصندوق.',
      );
    }

    // النوع المعاكس (إشارات مستعادة — ملحق و).
    final reversalType = switch (type) {
      CashTxType.receipt => 'payment',
      CashTxType.payment => 'receipt',
      CashTxType.expense => 'receipt',
      CashTxType.ownerDraw => 'capital_in',
      CashTxType.capitalIn => 'owner_draw',
      CashTxType.boxTransfer => 'box_transfer',
      CashTxType.bankDeposit => 'bank_withdraw',
      CashTxType.bankWithdraw => 'bank_deposit',
      CashTxType.opening => 'receipt',
    };

    final txDateIso = at.toUtc().toIso8601String();
    final originalLabel =
        (orig['voucher_no'] as String?) ??
        (orig['description'] as String?) ??
        '#$id';
    final cleanReason = (reason ?? '').trim();

    return await db.transaction((txn) async {
      // (أ) علامة الإبطال على الأصل — تحديث حالة لا تعديل مالي.
      await txn.rawUpdate(
        'UPDATE cash_tx SET is_voided = 1 WHERE id = ?',
        <Object>[id],
      );

      // (ب) استرجاع دفاتر الفواتير + حذف روابط التخصيص (رابط تخصيص
      //     لا حركة مالية — حذفه داخل المعاملة مسموح).
      final allocs = await txn.rawQuery(
        'SELECT invoice_id, allocated_amount FROM payment_allocation '
        'WHERE cash_tx_id = ?',
        <Object>[id],
      );
      for (final alloc in allocs) {
        final invoiceId = alloc['invoice_id'] as int;
        final allocAmount =
            (alloc['allocated_amount'] as num?)?.toDouble() ?? 0;
        final restored = await txn.rawUpdate(
          'UPDATE invoice SET due_amount = due_amount + ?, '
          'paid_amount = paid_amount - ?, updated_at = ? '
          'WHERE id = ? AND paid_amount >= ? - ?',
          <Object>[
            allocAmount,
            allocAmount,
            txDateIso,
            invoiceId,
            allocAmount,
            moneyEpsilon,
          ],
        );
        if (restored == 0) {
          throw CashFlowError(
            'تعذر استرجاع تخصيص الفاتورة رقم #$invoiceId — بياناتها '
            'غير متسقة مع السند. لم يُكتب شيء (تراجعت المعاملة).',
          );
        }
      }
      if (allocs.isNotEmpty) {
        await txn.rawDelete(
          'DELETE FROM payment_allocation WHERE cash_tx_id = ?',
          <Object>[id],
        );
      }

      // (ج) الحركة المعاكسة — نفس الأنواع بإشارات مستعادة (للتحويل:
      //     معاكسة الساقين بتبديل المصدر والهدف)، تُولد حية
      //     (`is_voided=0`) وتُستبعد من الأرصدة عبر `reversal_of`.
      final reversalId = await txn.insert('cash_tx', {
        'tx_type': reversalType,
        'cashbox_id': type.isTwoLegged
            ? orig['to_cashbox_id']
            : orig['cashbox_id'],
        'to_cashbox_id': type.isTwoLegged ? orig['cashbox_id'] : null,
        'currency_id': orig['currency_id'],
        'amount': orig['amount'],
        'exchange_rate': orig['exchange_rate'],
        'settlement_rate': orig['settlement_rate'],
        'fx_gain_loss': -((orig['fx_gain_loss'] as num?)?.toDouble() ?? 0),
        'voucher_no': null, // رقم الأصل لا يُعاد ولا يُنسخ (استمرارية).
        'tx_date': txDateIso,
        'ref_type': orig['ref_type'],
        'ref_id': null,
        'expense_category_id': orig['expense_category_id'],
        'customer_id': orig['customer_id'],
        'supplier_id': orig['supplier_id'],
        'is_voided': 0,
        'reversal_of': id,
        'description':
            'إبطال: $originalLabel'
            '${cleanReason.isEmpty ? '' : ' — $cleanReason'}',
        'created_at': txDateIso,
        'created_by': userId,
      });

      // (د) قيد التدقيق.
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'cash_void',
        'entity': 'cash_tx',
        'entity_id': id,
        'details':
            'type=${orig['tx_type']} amount=${orig['amount']} '
            'reversal=$reversalId label=$originalLabel'
            '${cleanReason.isEmpty ? '' : ' reason=$cleanReason'}',
        'at': txDateIso,
      });

      return Ok<int, String>(reversalId);
    });
  } on CashFlowError catch (e) {
    return Err(e.message);
  } on StateError catch (e) {
    return Err(e.message);
  } on DatabaseException catch (e) {
    return Err(describeCashDbError(e, 'إبطال الحركة'));
  }
}

// ─────────────────────────────────────────────────────────────────────
// السجل والقراءات (FR-04-08 سجل كامل + مرشحات)
