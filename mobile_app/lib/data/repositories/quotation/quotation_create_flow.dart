/// إنشاء عرض السعر (FR-02-11) — جزء من تقسيم R20-D3a لمستودع عروض
/// الأسعار (نمط R19-D3d): منقول حرفياً من quotation_repository.dart —
/// **المعاملة كاملة داخل هذا الملف الواحد غير مشطورة** (الواجهة
/// العامة والسلوك ثابتان — المستودع يفوِّض بتواقيعه نفسها).
///
/// **عرض السعر مستند غير ملزم**: يُرقَّم `QTE-YYYY-NNNNN` ذرّياً (قاعدة
/// 5.4-1) ولا يخصم مخزوناً ولا يحرك صندوقاً ولا يدين أحداً إطلاقاً —
/// بضعة صفوف مستندية + قيد تدقيق فقط.
///
/// ## قرارات موثقة (منقولة من رأس المستودع الأصلي — انظر
/// worklog-parts/6-b.md):
/// 1. جدول `quotation` بلا عمود `rate_is_fallback` ولا `converted_at`
///    (المخطط مجمّد §5.3): لحظة التحويل تُخزَّن في `updated_at`، وشارة
///    «سعر تقديري» (FR-02-20) تظهر على الفاتورة الناتجة (عمودها هناك)
///    لا على العرض — طلب هجرة مرفوع للمنسّق إن أُريدت على العرض نفسه.
/// 2. `quotation.discount_amount` يخزَّن **إجمالي الخصم الفعلي**
///    (أسطر + رأس) بنفس دلالة `invoice.discount_amount` — لا عمود
///    مستقل لخصوم الأسطر بالمخطط.
/// 3. عند الإنشاء يوزَّع خصم الرأس pro-rata داخل بنود العرض (مثل
///    الفاتورة تماماً) فيتحول التحويل إلى نسخ أرقام حرفي بلا إعادة توزيع.
library;

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/doc_sequence.dart';
import '../../../domain/core/dates.dart';
import '../../../domain/core/result.dart';
import '../../../domain/models/quotation.dart';
import '../../../domain/models/sale.dart';
import '../../../domain/services/sale_pricing.dart';
import '../exchange_rate_repository.dart';
import '../settings_repository.dart';
import 'quotation_helpers.dart';

/// **إنشاء عرض سعر ذرّياً**: رقم QTE + الرأس + البنود + قيد تدقيق —
/// **بلا أي حركة مخزون أو صندوق** (مستند غير ملزم).
Future<Result<Quotation, String>> createQuotationFlow(
  Database db,
  ExchangeRateRepository rates,
  SettingsRepository settings,
  QuotationDraft draft, {
  required int userId,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final issuedIso = draft.issuedAt.toUtc().toIso8601String();

  // التسعير النقي المشترك مع الفاتورة (خصومات pro-rata موثقة هناك).
  final cartLines = [
    for (final line in draft.lines)
      CartLine(
        productId: line.productId,
        qty: line.qty,
        unitPrice: line.unitPrice,
        lineDiscountType: line.lineDiscountType,
        lineDiscountValue: line.lineDiscountValue,
        notes: line.notes,
      ),
  ];
  final failure = SalePricing.validateCart(
    cartLines,
    invoiceDiscountType: draft.invoiceDiscountType,
    invoiceDiscountValue: draft.invoiceDiscountValue,
  );
  if (failure != null) return Err(failure);
  final priced = SalePricing.priceCart(
    cartLines,
    invoiceDiscountType: draft.invoiceDiscountType,
    invoiceDiscountValue: draft.invoiceDiscountValue,
  );

  try {
    // الأصناف — أسماء لقطة البنود + رفض المفقود (لا فحص مخزون إطلاقاً:
    // العرض لا يلتزم شيئاً).
    final productIds = draft.lines.map((l) => l.productId).toSet();
    final productRows = await db.rawQuery(
      'SELECT id, name, unit_id FROM product '
      'WHERE id IN (${List.filled(productIds.length, '?').join(',')})',
      productIds.toList(),
    );
    final namesById = {
      for (final row in productRows)
        row['id'] as int: (row['name'] as String, row['unit_id'] as int?),
    };
    for (final id in productIds) {
      if (!namesById.containsKey(id)) {
        return Err('الصنف رقم #$id غير موجود.');
      }
    }

    // سياسة FX (FR-08-09) — نفس قاعدة البيع بلا عمود شارة هنا
    // (القرار 1 برأس الملف): بلا سعر اليوم → رفض إلا بـ fx.fallback.
    final currencyRows = await db.query(
      'currency',
      columns: ['code', 'is_base'],
      where: 'id = ?',
      whereArgs: [draft.currencyId],
      limit: 1,
    );
    if (currencyRows.isEmpty) {
      return Err('العملة رقم #${draft.currencyId} غير موجودة.');
    }
    final isBase = (currencyRows.first['is_base'] as int? ?? 0) == 1;
    final currencyCode = currencyRows.first['code'] as String;
    var rate = 1.0;
    if (!isBase) {
      final today = await rates.rateFor(draft.currencyId, draft.issuedAt);
      if (today != null && today > 0) {
        rate = today;
      } else if ((await settings.getString('fx.fallback', 'off')) ==
          'last_known') {
        final lastKnown = await rates.latestBefore(
          draft.currencyId,
          draft.issuedAt,
        );
        if (lastKnown == null || lastKnown <= 0) {
          return Err(
            'لا يوجد أي سعر صرف معروف لعملة $currencyCode — '
            'أدخل سعراً أولاً ثم أنشئ العرض.',
          );
        }
        rate = lastKnown;
      } else {
        return Err(
          'لا يوجد سعر صرف لعملة $currencyCode بتاريخ اليوم — '
          'أدخل سعر اليوم أولاً (لا يُحفظ بسعر افتراضي).',
        );
      }
    }

    return await db.transaction((txn) async {
      // رقم QTE ذرّي داخل المعاملة (قاعدة 5.4-1).
      final year = draft.issuedAt.year;
      final seq = DocSequenceService(txn);
      final number = await seq.nextNumber(DocSequenceType.quotation, year);
      final quotationNo = formatDocNumber(
        DocSequenceType.quotation,
        year,
        number,
      );

      final quotationId = await txn.insert('quotation', {
        'quotation_no': quotationNo,
        'customer_id': draft.customerId,
        'warehouse_id': draft.warehouseId,
        'currency_id': draft.currencyId,
        'exchange_rate': rate,
        'issued_at': issuedIso,
        'valid_until': draft.validUntil == null
            ? null
            : dateOnly(draft.validUntil!),
        'status': 'draft',
        'subtotal': priced.totals.subtotal,
        'discount_amount': roundMoney(priced.totals.totalDiscount),
        'tax_rate': 0,
        'tax_amount': 0,
        'total': priced.totals.grandTotal,
        'notes_internal': draft.notesInternal,
        'notes_printed': draft.notesPrinted,
        'created_at': at.toUtc().toIso8601String(),
        'updated_at': at.toUtc().toIso8601String(),
        'created_by': userId,
      });

      for (final pricedLine in priced.lines) {
        final (name, unitId) = namesById[pricedLine.line.productId]!;
        await txn.insert('quotation_item', {
          'quotation_id': quotationId,
          'product_id': pricedLine.line.productId,
          'line_desc': name,
          'qty': pricedLine.line.qty,
          'unit_id': unitId,
          'unit_factor': 1,
          'unit_price': pricedLine.line.unitPrice,
          'discount_percent':
              pricedLine.line.lineDiscountType == SaleDiscountType.percent
              ? pricedLine.line.lineDiscountValue
              : 0,
          'discount_amount': pricedLine.effectiveDiscount,
          'tax_percent': 0,
          'line_total': pricedLine.netFinal,
          'notes': (pricedLine.line.notes ?? '').trim().isEmpty
              ? null
              : pricedLine.line.notes!.trim(),
          'created_at': at.toUtc().toIso8601String(),
        });
      }

      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'quotation_create',
        'entity': 'quotation',
        'entity_id': quotationId,
        'details':
            'no=$quotationNo total=${priced.totals.grandTotal} '
            'currency=$currencyCode rate=$rate',
        'at': at.toUtc().toIso8601String(),
      });

      final rows = await txn.query(
        'quotation',
        where: 'id = ?',
        whereArgs: [quotationId],
        limit: 1,
      );
      return Ok<Quotation, String>(Quotation.fromRow(rows.first));
    });
  } on DatabaseException catch (e) {
    return Err(quotationDescribeDbError(e));
  } on StateError catch (e) {
    return Err(e.message);
  }
}
