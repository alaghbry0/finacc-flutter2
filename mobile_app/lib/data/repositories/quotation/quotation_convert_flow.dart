/// تحويل عرض السعر إلى فاتورة بيع (FR-02-11 / AC-17) — جزء من تقسيم
/// R20-D3a لمستودع عروض الأسعار (نمط R19-D3d): منقول حرفياً من
/// quotation_repository.dart (الواجهة العامة والسلوك ثابتان — المستودع
/// يفوِّض بتواقيعه نفسها).
///
/// **الذرّية عبر postSale**: يُبنى `SaleDraft` من بنود العرض بنفس
/// أسعارها وخصومها الفعلية، ثم يُنفَّذ `SaleRepository.postSale` — والربط
/// الذرّي عبر `SaleDraft.fromQuotationId`: تحديث العرض إلى `converted` +
/// `converted_invoice_id` يجري **داخل معاملة postSale نفسها** (فشل أي
/// طرف — مخزون ناقص مثلاً — يرجع الفاتورة والعرض معاً). سعر صرف
/// **الفاتورة** هو سعر يوم التحويل (Snapshot FR-08-05) لا سعر يوم العرض.
///
/// قرار رابع منقول من رأس المستودع الأصلي: التحويل من draft/sent حصراً
/// — وطلبات التحويل المتزامنة يحميها شرط `status IN ('draft','sent')`
/// داخل معاملة الفاتورة.
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/result.dart';
import '../../../domain/models/quotation.dart';
import '../../../domain/models/sale.dart';
import '../../../domain/services/sale_pricing.dart';
import '../sale_repository.dart';

/// **تحويل عرض سعر إلى فاتورة بيع مكتملة بضغطة واحدة**.
///
/// يبني `SaleDraft` من بنود العرض بنفس أسعارها وخصومها الفعلية المخزنة
/// (الخصوم الموزعة pro-rata وقت الإنشاء تُنقل حرفياً كخصومات مبالغ —
/// الأرقام النهائية تتطابق بالتساوي) وينادي `postSale` بـ
/// [fromQuotationId] فيتحول العرض إلى `converted` داخل نفس معاملة
/// الفاتورة.
///
/// - [paidCash] الجزء النقدي (0 = آجل كامل).
/// - [paymentMethod] اختياري: `null` → استنتاج من paidCash مقابل صافي
///   العرض (نقدي/آجل/مختلط — FR-02-03).
/// - [issuedAt] تاريخ الفاتورة (افتراضياً [now]) — سعر صرف الفاتورة
///   يُحل ليومه لا يوم العرض (FR-08-05).
Future<Result<SalePostedReceipt, String>> convertToInvoiceFlow(
  Database db,
  SaleRepository sales,
  int quotationId, {
  required double paidCash,
  SalePaymentMethod? paymentMethod,
  required int userId,
  DateTime? now,
  DateTime? issuedAt,
}) async {
  final at = now ?? DateTime.now();
  final rows = await db.query(
    'quotation',
    where: 'id = ?',
    whereArgs: [quotationId],
    limit: 1,
  );
  if (rows.isEmpty) {
    return Err('عرض السعر رقم #$quotationId غير موجود.');
  }
  final quotation = Quotation.fromRow(rows.first);
  if (!quotation.status.convertible) {
    return Err(
      'عرض السعر غير قابل للتحويل — حالته الحالية '
      '«${quotation.status.code}».',
    );
  }

  final itemRows = await db.query(
    'quotation_item',
    where: 'quotation_id = ?',
    whereArgs: [quotationId],
    orderBy: 'id ASC',
  );
  if (itemRows.isEmpty) {
    return const Err('عرض السعر بلا بنود — لا يُحوَّل إلى فاتورة.');
  }

  // البنود بنفس أسعارها وخصومها الفعلية (خصم الرأس موزَّع فيها أصلاً).
  final lines = [
    for (final row in itemRows)
      CartLine(
        productId: row['product_id'] as int,
        qty: (row['qty'] as num?)?.toDouble() ?? 0,
        unitPrice: (row['unit_price'] as num?)?.toDouble() ?? 0,
        lineDiscountValue: (row['discount_amount'] as num?)?.toDouble() ?? 0,
        notes: row['notes'] as String?,
      ),
  ];

  // نوع الدفع: معلناً أو مستنتجاً من المبلغ مقابل صافي العرض.
  final method =
      paymentMethod ?? SalePricing.derivePayStatus(quotation.total, paidCash);

  return sales.postSale(
    SaleDraft(
      customerId: quotation.customerId,
      currencyId: quotation.currencyId,
      lines: lines,
      paidCash: paidCash,
      paymentMethod: method,
      warehouseId: quotation.warehouseId,
      notesInternal: quotation.notesInternal,
      notesPrinted: quotation.notesPrinted,
      issuedAt: issuedAt ?? at,
      fromQuotationId: quotationId,
    ),
    userId: userId,
    now: at,
  );
}
