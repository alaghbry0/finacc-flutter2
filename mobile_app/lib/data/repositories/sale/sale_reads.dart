/// جزء من تقسيم R18-D3a لمستودع المبيعات — مستخرج حرفياً من
/// sale_repository.dart (الواجهة العامة والسلوك ثابتان).
library;

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/doc_sequence.dart';
import '../../../domain/core/dates.dart';
import '../../../domain/models/sale.dart';

/// معاينة رقم INV القادم للسنة (آخر مُصدر + 1) — عرضٌ فقط بلا استهلاك؛
/// الترقيم الحقيقي يستهلك ذرّياً داخل معاملة الترحيل نفسها.
///
/// (R18-D1: كان هذا المنطق داخل نموذج سلة الكاشير — نُقل للمستودع
/// ليبقى لمس `core/storage/doc_sequence` في طبقة البيانات حصراً.)
Future<String> previewSaleInvoiceNo(Database db, int year) async {
  final last = await DocSequenceService(db)
      .lastIssuedNumber(DocSequenceType.invoice, year);
  return formatDocNumber(DocSequenceType.invoice, year, last + 1);
}

// ─────────────────────────────────────────────────────────────────────
// الترحيل الذرّي (FR-02-06 / 5.4-4)

// ─────────────────────────────────────────────────────────────────────

/// تفاصيل فاتورة بيع كاملة: الرأس + البنود + اسم العميل + العملة.
///
/// `null` إن لم توجد (أو ليست فاتورة بيع).
Future<SaleInvoiceDetail?> saleInvoiceDetail(Database db, int invoiceId) async {
  final rows = await db.rawQuery(
    '''
    SELECT i.*, c.name AS customer_name, c.phone AS customer_phone,
           cu.code AS currency_code, cu.symbol_svg AS currency_symbol
    FROM invoice i
    LEFT JOIN customer c ON c.id = i.customer_id
    JOIN currency cu ON cu.id = i.currency_id
    WHERE i.id = ? AND i.doc_type = 'sale'
    LIMIT 1
  ''',
    [invoiceId],
  );
  if (rows.isEmpty) return null;
  // اسم الوحدة يُقرأ للعرض فقط (قوالب الطباعة UX-3) — JOIN قراءة صرف
  // فوق عمود موجود منذ v1، بلا أي مساس بمنطق الترحيل/الترحيل العكسي.
  final itemRows = await db.rawQuery(
    '''
    SELECT ii.*, u.name AS unit_name
    FROM invoice_item ii
    LEFT JOIN unit u ON u.id = ii.unit_id
    WHERE ii.invoice_id = ?
    ORDER BY ii.id ASC
  ''',
    [invoiceId],
  );
  return SaleInvoiceDetail(
    invoice: SaleInvoice.fromRow(rows.first),
    items: [for (final row in itemRows) SaleInvoiceItemLine.fromRow(row)],
    customerName: rows.first['customer_name'] as String?,
    customerPhone: rows.first['customer_phone'] as String?,
    currencyCode: rows.first['currency_code'] as String?,
    currencySymbol: rows.first['currency_symbol'] as String?,
  );
}

/// آخر فواتير البيع (الأحدث أولاً) — لتقرير/بحث الشاشات.
Future<List<SaleInvoiceSummary>> recentSalesList(
  Database db, {
  int limit = 50,
  int? customerId,
}) async {
  final where = [
    "i.doc_type = 'sale'",
    if (customerId != null) 'i.customer_id = ?',
  ].join(' AND ');
  final rows = await db.rawQuery(
    '''
    SELECT i.id, i.invoice_no, i.issued_at, i.customer_id, i.total,
           i.paid_amount, i.due_amount, i.pay_status, i.status,
           c.name AS customer_name, cu.code AS currency_code
    FROM invoice i
    LEFT JOIN customer c ON c.id = i.customer_id
    JOIN currency cu ON cu.id = i.currency_id
    WHERE $where
    ORDER BY i.issued_at DESC, i.id DESC
    LIMIT ?
  ''',
    [?customerId, limit],
  );
  return [
    for (final row in rows)
      SaleInvoiceSummary(
        id: row['id'] as int,
        invoiceNo: row['invoice_no'] as String,
        issuedAt: DateTime.parse(row['issued_at'] as String),
        customerId: row['customer_id'] as int?,
        customerName: row['customer_name'] as String?,
        currencyCode: row['currency_code'] as String?,
        total: (row['total'] as num?)?.toDouble() ?? 0,
        paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
        dueAmount: (row['due_amount'] as num?)?.toDouble() ?? 0,
        payStatus: SalePaymentMethod.values.firstWhere(
          (m) => m.code == (row['pay_status'] as String),
        ),
        status: row['status'] as String,
      ),
  ];
}

/// إجماليات مبيعات فترة (شاملة الطرفين) — بالعملة الأساسية عبر
/// `total_base` (نفس أساس DashboardRepository — FR-09-01).
Future<SalesPeriodTotals> salesTotalsForPeriod(
  Database db,
  DateTime from,
  DateTime to,
) async {
  final salesRows = await db.rawQuery(
    '''
    SELECT COUNT(*) AS n, COALESCE(SUM(total_base), 0) AS s,
           COALESCE(SUM(cost_total), 0) AS c
    FROM invoice
    WHERE doc_type = 'sale' AND status = 'completed'
      AND date(issued_at) >= ? AND date(issued_at) <= ?
  ''',
    [dateOnly(from), dateOnly(to)],
  );
  final cashRows = await db.rawQuery(
    '''
    SELECT COALESCE(SUM(t.amount), 0) AS a
    FROM cash_tx t
    WHERE t.tx_type = 'receipt' AND t.is_voided = 0
      AND t.ref_type = 'invoice'
      AND EXISTS (
        SELECT 1 FROM invoice i
        WHERE i.id = t.ref_id AND i.doc_type = 'sale'
          AND i.status = 'completed'
          AND date(i.issued_at) >= ? AND date(i.issued_at) <= ?
      )
  ''',
    [dateOnly(from), dateOnly(to)],
  );
  return SalesPeriodTotals(
    invoiceCount: (salesRows.first['n'] as int?) ?? 0,
    salesBase: (salesRows.first['s'] as num?)?.toDouble() ?? 0,
    costTotal: (salesRows.first['c'] as num?)?.toDouble() ?? 0,
    cashCollected: (cashRows.first['a'] as num?)?.toDouble() ?? 0,
  );
}

// ─────────────────────────────────────────────────────────────────────
// مساعدات خاصة
