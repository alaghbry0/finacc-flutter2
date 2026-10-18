/// قراءات عروض الأسعار (القائمة/التفاصيل) — جزء من
/// تقسيم R20-D3a لمستودع عروض الأسعار (نمط R19-D3d): منقولة حرفياً من
/// quotation_repository.dart (الواجهة العامة والسلوك ثابتان — المستودع
/// يفوِّض بتواقيعه نفسها).
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/models/quotation.dart';

/// قائمة العروض (الأحدث أولاً) بتصفية العميل/الحالة وحد أعلى.
Future<List<QuotationSummary>> quotationSummaries(
  Database db, {
  int? customerId,
  QuotationStatus? status,
  int limit = 50,
}) async {
  final where = [
    if (customerId != null) 'q.customer_id = ?',
    if (status != null) 'q.status = ?',
  ];
  final rows = await db.rawQuery(
    '''
      SELECT q.id, q.quotation_no, q.issued_at, q.valid_until, q.customer_id,
             q.total, q.status, q.converted_invoice_id,
             c.name AS customer_name, cu.code AS currency_code
      FROM quotation q
      LEFT JOIN customer c ON c.id = q.customer_id
      JOIN currency cu ON cu.id = q.currency_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY q.issued_at DESC, q.id DESC
      LIMIT ?
    ''',
    [?customerId, ?status?.code, limit],
  );
  return [
    for (final row in rows)
      QuotationSummary(
        id: row['id'] as int,
        quotationNo: row['quotation_no'] as String,
        issuedAt: DateTime.parse(row['issued_at'] as String),
        validUntil: row['valid_until'] == null
            ? null
            : DateTime.tryParse(row['valid_until'] as String),
        customerId: row['customer_id'] as int?,
        customerName: row['customer_name'] as String?,
        currencyCode: row['currency_code'] as String?,
        total: (row['total'] as num?)?.toDouble() ?? 0,
        status: QuotationStatus.fromCode(row['status'] as String),
        convertedInvoiceId: row['converted_invoice_id'] as int?,
      ),
  ];
}

/// تفاصيل عرض كامل: الرأس + البنود + أسماء العميل/العملة.
Future<QuotationDetail?> quotationDetailById(Database db, int id) async {
  final rows = await db.rawQuery(
    '''
      SELECT q.*, c.name AS customer_name, c.phone AS customer_phone,
             cu.code AS currency_code
      FROM quotation q
      LEFT JOIN customer c ON c.id = q.customer_id
      JOIN currency cu ON cu.id = q.currency_id
      WHERE q.id = ?
      LIMIT 1
    ''',
    [id],
  );
  if (rows.isEmpty) return null;
  final itemRows = await db.query(
    'quotation_item',
    where: 'quotation_id = ?',
    whereArgs: [id],
    orderBy: 'id ASC',
  );
  return QuotationDetail(
    quotation: Quotation.fromRow(rows.first),
    items: [for (final row in itemRows) QuotationItemLine.fromRow(row)],
    customerName: rows.first['customer_name'] as String?,
    customerPhone: rows.first['customer_phone'] as String?,
    currencyCode: rows.first['currency_code'] as String?,
  );
}
