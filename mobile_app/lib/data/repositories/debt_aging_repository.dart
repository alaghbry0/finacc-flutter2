/// مستودع أعمار الديون — تقرير FR-09-05 (الشريحة 9): أرصدة العملاء
/// مصنّفة (٠–٣٠ / ٣١–٦٠ / ٦١–٩٠ / +٩٠) على أساس تخصيص FIFO
/// (الأقدم أولاً).
///
/// ## أساس FIFO (القرار المعماري الموثق):
/// `invoice.due_amount` هو **المتبقي غير المحصّل بعد تخصيص FIFO** —
/// سند القبض المرقّم (RVT) المخصص يحدّث الدفتر لحظة الترحيل
/// (`cash_repository` 4-ب: `due_amount − alloc, paid_amount + alloc` +
/// صفوف `payment_allocation`)، فأي فاتورة بيع مكتملة بـ
/// `due_amount > 0` هي فعلاً فاتورة مفتوحة بمتبقٍّ صحيح. السند الحر
/// «على الحساب» يخصم من رصيد الطرف العام (صيغة FR-03-02) ولا يُنسب
/// لفاتورة بعينها فهو خارج تصنيف الفواتير هذا — مطابقةً لقراءة كشف
/// الحساب في `CustomerRepository.statement()`.
///
/// ## قاعدة الدلاء (حرفياً أصناف SRS الأربعة):
/// عمر الدين = (تاريخ الاحتساب − تاريخ الاستحقاق) بالأيام، والمرجع
/// `due_date` عند وجوده وإلا `issued_at` (شروط الائتمان). القيم السالبة
/// (غير مستحق بعد) تُدمج في دلو ٠–٣٠ لأنها دين **جارٍ** لا متأخر —
/// ويُتتبَّع مجموعها في `currentNotDue` لعرضه منفصلاً. الحدود:
/// ≤ ٣٠ يوماً / ٣١–٦٠ / ٦١–٩٠ / ≥ ٩١.
///
/// الأرشفة لا تُخفي الدين: المؤرشفون أصحاب فواتير مفتوحة يظهرون في
/// التقرير (التحصيل مسؤولية لا تسقط بالأرشفة — FR-03-09).
library;

import 'package:sqflite/sqflite.dart';

/// تفصيل فاتورة مفتوحة داخل التقرير (يُعرض عند توسيع سطر العميل).
class AgingInvoiceDetail {
  const AgingInvoiceDetail({
    required this.invoiceId,
    required this.invoiceNo,
    required this.issuedAt,
    required this.dueDate,
    required this.daysPastDue,
    required this.dueAmount,
  });

  /// معرّف الفاتورة في جدول `invoice`.
  final int invoiceId;

  /// رقم الفاتورة (INV-…).
  final String invoiceNo;

  /// تاريخ الإصدار (UTC).
  final DateTime issuedAt;

  /// تاريخ الاستحقاق (UTC) — أو `null` فيُعتمد تاريخ الإصدار.
  final DateTime? dueDate;

  /// أيام التجاوز منذ المرجع: موجب = متأخر، سالب = غير مستحق بعد،
  /// صفر = يستحق اليوم.
  final int daysPastDue;

  /// المتبقي غير المحصّل (FIFO — أنظر رأس الملف).
  final double dueAmount;
}

/// سطر عميل واحد — مبالغه موزّعة على الدلاء الأربعة بعملة التقرير.
class AgingCustomerRow {
  const AgingCustomerRow({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.whatsapp,
    required this.bucket0to30,
    required this.bucket31to60,
    required this.bucket61to90,
    required this.bucket90Plus,
    required this.currentNotDue,
    required this.details,
  }) : total = bucket0to30 + bucket31to60 + bucket61to90 + bucket90Plus;

  final int customerId;
  final String name;

  /// هاتف العميل (لتذكير واتساب عند غياب رقم الواتساب).
  final String? phone;

  /// رقم واتساب العميل (الأولوية عند التذكير).
  final String? whatsapp;

  /// دلو ٠–٣٠ (يشمل الجاري غير المستحق بعد — قاعدة الدلاء برأس الملف).
  final double bucket0to30;

  final double bucket31to60;

  final double bucket61to90;

  /// دلو +٩٠ (≥ ٩١ يوماً).
  final double bucket90Plus;

  /// الجزء غير المستحق بعد (أيام سالبة) — مدمج في دلو ٠–٣٠ ومتتبَّع
  /// هنا لعرضه منفصلاً في الملخص.
  final double currentNotDue;

  /// تفاصيل الفواتير المفتوحة مرتّبة تصاعدياً بالإصدار (الأقدم أولاً).
  final List<AgingInvoiceDetail> details;

  /// إجمالي ديون العميل بعملة التقرير (مجموع الدلاء الأربعة).
  final double total;
}

/// تقرير أعمار الديون لعملة واحدة حتى تاريخ محدد.
class AgingReport {
  const AgingReport({
    required this.currencyId,
    required this.currencyCode,
    required this.asOf,
    required this.rows,
    required this.total0to30,
    required this.total31to60,
    required this.total61to90,
    required this.total90Plus,
    required this.currentNotDue,
  }) : grandTotal = total0to30 + total31to60 + total61to90 + total90Plus,
       customersCount = rows.length;

  final int currencyId;
  final String currencyCode;

  /// لحظة الاحتساب (يومها هو مرجع الأعمار).
  final DateTime asOf;

  /// سطر لكل عميل عليه ديون مفتوحة بهذه العملة، مرتّبة بالأكبر ديناً.
  final List<AgingCustomerRow> rows;

  final double total0to30;
  final double total31to60;
  final double total61to90;
  final double total90Plus;

  /// إجمالي الجزء غير المستحق بعد (مدمج في total0to30).
  final double currentNotDue;

  /// مجموع الدلاء الأربعة.
  final double grandTotal;

  /// عدد العملاء المدينين.
  final int customersCount;
}

/// مستودع أعمار الديون — قراءة صرفة فوق `invoice` × `customer`.
class DebtAgingRepository {
  DebtAgingRepository(this._db);

  final Database _db;

  /// يبني تقرير الأعمار لعملة [currencyId] حتى يوم [asOf] (الآن افتراضاً).
  ///
  /// الاستعلام: فواتير البيع **المكتملة** ذات متبقٍّ آجل مفتوح
  /// (`due_amount > 0`) لعملاء معروفين بالعملة المطلوبة — تُستبعد
  /// المسودات والإبطالات والمرتجعات والمشتريات والفواتير المسددة.
  /// التصنيف في Dart فوق الصفوف (قابل للاختبار ومطابق لقاعدة الدلاء
  /// برأس الملف).
  Future<AgingReport> agingReport({
    required int currencyId,
    DateTime? asOf,
  }) async {
    final reference = asOf ?? DateTime.now();
    final asOfDay = DateTime.utc(
      reference.year,
      reference.month,
      reference.day,
    );

    final rows = await _db.rawQuery(
      '''
      SELECT i.id AS invoice_id, i.invoice_no, i.issued_at, i.due_date,
             i.due_amount,
             c.id AS customer_id, c.name AS customer_name,
             c.phone AS customer_phone, c.whatsapp AS customer_whatsapp,
             cu.code AS currency_code
      FROM invoice i
      JOIN customer c ON c.id = i.customer_id
      JOIN currency cu ON cu.id = i.currency_id
      WHERE i.doc_type = 'sale' AND i.status = 'completed'
        AND i.customer_id IS NOT NULL
        AND i.currency_id = ?
        AND i.due_amount > 0
      ORDER BY c.name COLLATE NOCASE ASC, i.issued_at ASC, i.id ASC
      ''',
      <Object?>[currencyId],
    );

    var currencyCode = '';
    final byCustomer = <int, _CustomerBuilder>{};
    for (final row in rows) {
      currencyCode = (row['currency_code'] as String?) ?? currencyCode;
      final customerId = row['customer_id'] as int;
      final issuedDay = _utcMidnight(row['issued_at'] as String?)!;
      final dueDay = _utcMidnight(row['due_date'] as String?);
      final referenceDay = dueDay ?? issuedDay;
      final days = asOfDay.difference(referenceDay).inDays;
      final amount = (row['due_amount'] as num?)?.toDouble() ?? 0;
      final builder = byCustomer.putIfAbsent(customerId, () {
        return _CustomerBuilder(
          customerId: customerId,
          name: row['customer_name'] as String,
          phone: row['customer_phone'] as String?,
          whatsapp: row['customer_whatsapp'] as String?,
        );
      });
      if (days <= 30) {
        builder.bucket0to30 += amount;
      } else if (days <= 60) {
        builder.bucket31to60 += amount;
      } else if (days <= 90) {
        builder.bucket61to90 += amount;
      } else {
        builder.bucket90Plus += amount;
      }
      if (days < 0) {
        builder.currentNotDue += amount;
      }
      builder.details.add(
        AgingInvoiceDetail(
          invoiceId: row['invoice_id'] as int,
          invoiceNo: row['invoice_no'] as String,
          issuedAt: issuedDay,
          dueDate: dueDay,
          daysPastDue: days,
          dueAmount: amount,
        ),
      );
    }

    final agingRows = [for (final builder in byCustomer.values) builder.build()]
      ..sort((a, b) {
        if (a.total != b.total) return b.total.compareTo(a.total);
        if (a.name != b.name) return a.name.compareTo(b.name);
        return a.customerId.compareTo(b.customerId);
      });

    var total0to30 = 0.0;
    var total31to60 = 0.0;
    var total61to90 = 0.0;
    var total90Plus = 0.0;
    var currentNotDue = 0.0;
    for (final row in agingRows) {
      total0to30 += row.bucket0to30;
      total31to60 += row.bucket31to60;
      total61to90 += row.bucket61to90;
      total90Plus += row.bucket90Plus;
      currentNotDue += row.currentNotDue;
    }

    return AgingReport(
      currencyId: currencyId,
      currencyCode: currencyCode,
      asOf: asOfDay,
      rows: agingRows,
      total0to30: total0to30,
      total31to60: total31to60,
      total61to90: total61to90,
      total90Plus: total90Plus,
      currentNotDue: currentNotDue,
    );
  }
}

/// مجمّع مؤقت لسطر عميل أثناء بناء التقرير.
class _CustomerBuilder {
  _CustomerBuilder({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.whatsapp,
  });

  final int customerId;
  final String name;
  final String? phone;
  final String? whatsapp;

  double bucket0to30 = 0;
  double bucket31to60 = 0;
  double bucket61to90 = 0;
  double bucket90Plus = 0;
  double currentNotDue = 0;
  final List<AgingInvoiceDetail> details = <AgingInvoiceDetail>[];

  AgingCustomerRow build() => AgingCustomerRow(
    customerId: customerId,
    name: name,
    phone: phone,
    whatsapp: whatsapp,
    bucket0to30: bucket0to30,
    bucket31to60: bucket31to60,
    bucket61to90: bucket61to90,
    bucket90Plus: bucket90Plus,
    currentNotDue: currentNotDue,
    details: List<AgingInvoiceDetail>.unmodifiable(details),
  );
}

/// منتصف ليل UTC ليوم التقويم من نص ISO (كامل أو `YYYY-MM-DD`) —
/// أو `null` عند الغياب/التعذّر (نفس مساعد `customer_repository`).
DateTime? _utcMidnight(String? iso) {
  if (iso == null) return null;
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return null;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}
