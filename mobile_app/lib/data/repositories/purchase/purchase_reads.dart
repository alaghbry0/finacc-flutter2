/// جزء من تقسيم R18-D3a لمستودع المشتريات — مستخرج حرفياً من
/// purchase_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/doc_sequence.dart';
import '../../../domain/models/purchase.dart';

/// معاينة رقم PUR القادم للسنة (آخر مُصدر + 1) — عرضٌ فقط بلا استهلاك؛
/// الترقيم الحقيقي يستهلك ذرّياً داخل معاملة الترحيل نفسها.
///
/// (R18-D1: كان هذا المنطق داخل نموذج فاتورة الشراء الحية — نُقل
/// للمستودع ليبقى لمس `core/storage/doc_sequence` في طبقة البيانات
/// حصراً.)
Future<String> previewPurchaseNo(Database db, int year) async {
  final last = await DocSequenceService(db)
      .lastIssuedNumber(DocSequenceType.purchase, year);
  return formatDocNumber(DocSequenceType.purchase, year, last + 1);
}

// ─────────────────────────────────────────────────────────────────────
// الترحيل الذرّي (FR-02-08 / 5.4-3 / 5.4-4)

// ─────────────────────────────────────────────────────────────────────

/// تفاصيل فاتورة شراء كاملة: الرأس + البنود + اسم المورد + العملة.
///
/// `null` إن لم توجد (أو ليست فاتورة شراء).
Future<PurchaseInvoiceDetail?> purchaseInvoiceDetail(
  Database db,
  int invoiceId,
) async {
  final rows = await db.rawQuery(
    '''
    SELECT i.*, s.name AS supplier_name, s.phone AS supplier_phone,
           cu.code AS currency_code, cu.symbol_svg AS currency_symbol
    FROM invoice i
    LEFT JOIN supplier s ON s.id = i.supplier_id
    JOIN currency cu ON cu.id = i.currency_id
    WHERE i.id = ? AND i.doc_type = 'purchase'
    LIMIT 1
  ''',
    [invoiceId],
  );
  if (rows.isEmpty) return null;
  final itemRows = await db.query(
    'invoice_item',
    where: 'invoice_id = ?',
    whereArgs: [invoiceId],
    orderBy: 'id ASC',
  );
  return PurchaseInvoiceDetail(
    invoice: PurchaseInvoice.fromRow(rows.first),
    items: [for (final row in itemRows) PurchaseInvoiceItemLine.fromRow(row)],
    supplierName: rows.first['supplier_name'] as String?,
    supplierPhone: rows.first['supplier_phone'] as String?,
    currencyCode: rows.first['currency_code'] as String?,
    currencySymbol: rows.first['currency_symbol'] as String?,
  );
}

/// آخر فواتير الشراء (الأحدث أولاً) — لتقرير/بحث الشاشات.
Future<List<PurchaseInvoiceSummary>> recentPurchasesList(
  Database db, {
  int limit = 50,
  int? supplierId,
}) async {
  final where = [
    "i.doc_type = 'purchase'",
    if (supplierId != null) 'i.supplier_id = ?',
  ].join(' AND ');
  final rows = await db.rawQuery(
    '''
    SELECT i.id, i.invoice_no, i.issued_at, i.supplier_id, i.total,
           i.paid_amount, i.due_amount, i.pay_status, i.status,
           s.name AS supplier_name, cu.code AS currency_code
    FROM invoice i
    LEFT JOIN supplier s ON s.id = i.supplier_id
    JOIN currency cu ON cu.id = i.currency_id
    WHERE $where
    ORDER BY i.issued_at DESC, i.id DESC
    LIMIT ?
  ''',
    [?supplierId, limit],
  );
  return [
    for (final row in rows)
      PurchaseInvoiceSummary(
        id: row['id'] as int,
        invoiceNo: row['invoice_no'] as String,
        issuedAt: DateTime.parse(row['issued_at'] as String),
        supplierId: row['supplier_id'] as int?,
        supplierName: row['supplier_name'] as String?,
        currencyCode: row['currency_code'] as String?,
        total: (row['total'] as num?)?.toDouble() ?? 0,
        paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
        dueAmount: (row['due_amount'] as num?)?.toDouble() ?? 0,
        payStatus: PurchasePaymentMethod.values.firstWhere(
          (m) => m.code == (row['pay_status'] as String),
        ),
        status: row['status'] as String,
      ),
  ];
}

// ─────────────────────────────────────────────────────────────────────
// مساعدات خاصة
