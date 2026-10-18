/// المبيعات حسب العميل/الفئة/الصنف/اليوم (FR-09-06) — جزء من تقسيم
/// R20-D3a لمستودع تقارير الحركة (نمط R19-D3d): منقولة حرفياً من
/// movement_reports_repository.dart (الواجهة العامة والسلوك ثابتان —
/// المستودع يفوِّض بتواقيعه نفسها).
///
/// ## قرارات معمارية موثقة (منقولة من رأس المستودع الأصلي):
/// 1. **حدود الفترة على مستوى اليوم**: `date(issued_at)` `BETWEEN` شاملة
///    الطرفين — نفس اصطلاح `profit_report_repository` (لا ساعات/دقائق
///    تُقصّ من أطراف اليوم).
/// 2. **المبيعات بالعملة الأساسية**: `line_total × exchange_rate`
///    لكل سطر (لا خلط عملات — 5.4-7)، فواتير البيع **المكتملة حصراً**
///    (المسودة والإبطال مستبعدان)، والفترة السابقة = [من − N، من − 1]
///    حيث N = طول الفترة بالأيام (متلاصقة أمام البداية).
/// 3. **نسبة التغير**: null عند صفر الفترة السابقة (لا معنى رياضياً —
///    الواجهة تعرض «جديد»).
/// 4. **بعد «اليوم»**: اليوم الحالي يقارن بنفس ترتيبه في الفترة السابقة
///    (اليوم − N) — مقارنة «مثل اليوم من الفترة السابقة».
/// 5. **التصنيف الفارغ**: مبيعات بلا عميل تُجمَّع تحت سطر «عميل نقدي»
///    (label = '')؛ الأسطر الحرة/الأصناف بلا فئة تحت «غير مصنّف»
///    (label = '') — لا تختفي المبيعات من التقرير. سطر حر (بلا صنف)
///    مستبعد من بعد «الصنف» عمداً (لا صنف يُنسب إليه — نفس قرار
///    `topItems`).
/// 6. **الترتيب**: «اليوم» تصاعدياً بالتاريخ؛ وغيره تنازلياً بالمبيعات
///    (كسر التعادل بالاسم تصاعدياً) بحد 50 صفاً.
library;

import 'package:sqflite/sqflite.dart';

import '../../../domain/core/dates.dart';
import 'movement_report_models.dart';

/// تجميع المبيعات حسب [dimension] للفترة [from]..[to] (شاملة الطرفين)
/// بالعملة الأساسية، مع نسبة التغير عن الفترة السابقة المساوية في
/// الطول (القرار 2 برأس الملف).
Future<List<SalesByRow>> loadSalesBy(
  Database db, {
  required SalesByDimension dimension,
  required DateTime from,
  required DateTime to,
}) async {
  final fromDay = dateOnly(from);
  final toDay = dateOnly(to);

  // الفترة السابقة: [من − N، من − 1] — متلاصقة أمام البداية (قرار 2).
  final lengthDays =
      DateTime(
        to.year,
        to.month,
        to.day,
      ).difference(DateTime(from.year, from.month, from.day)).inDays +
      1;
  final prevFrom = DateTime(
    from.year,
    from.month,
    from.day,
  ).subtract(Duration(days: lengthDays));
  final prevTo = DateTime(
    from.year,
    from.month,
    from.day,
  ).subtract(const Duration(days: 1));
  final prevFromDay = dateOnly(prevFrom);
  final prevToDay = dateOnly(prevTo);

  // (أ) تجميع الفترة الحالية.
  final currentRows = await _salesAggregate(db, dimension, fromDay, toDay);
  // (ب) تجميع الفترة السابقة (لا ترتيب/حد — خريطة بحث فقط).
  final previousRows = await _salesAggregate(
    db,
    dimension,
    prevFromDay,
    prevToDay,
  );

  // بعد «اليوم» يقارن كل يوم بنظيره بالإزاحة نفسها (قرار 4):
  // اليوم d ↔ اليوم d − N — فخريطة السابقة بمفاتيحها الخام، والبحث
  // بمفتاح اليوم الحالي بعد إزاحته للخلف N يوماً (identity للأبعاد
  // الأخرى: الكيان نفسه).
  String previousKeyOf(String label) {
    if (dimension != SalesByDimension.day) return label;
    final day = DateTime.tryParse(label);
    if (day == null) return label;
    return dateOnly(day.subtract(Duration(days: lengthDays)));
  }

  final previousByLabel = <String, double>{
    for (final row in previousRows)
      (row['label'] as String? ?? ''):
          (row['salesBase'] as num?)?.toDouble() ?? 0,
  };

  final rows = <SalesByRow>[];
  for (final row in currentRows) {
    final label = (row['label'] as String?) ?? '';
    final salesBase = (row['salesBase'] as num?)?.toDouble() ?? 0;
    final previous = previousByLabel[previousKeyOf(label)] ?? 0;
    rows.add(
      SalesByRow(
        label: label,
        salesBase: salesBase,
        invoiceCount: row['invoiceCount'] as int? ?? 0,
        changePct: previous == 0
            ? null
            : (salesBase - previous) / previous * 100,
      ),
    );
  }

  // (ج) الترتيب (القرار 6): «اليوم» تصاعدياً؛ وغيره بالمبيعات
  // تنازلياً (كسر التعادل بالاسم) بحد 50.
  if (dimension == SalesByDimension.day) {
    rows.sort((a, b) => a.label.compareTo(b.label));
  } else {
    rows.sort((a, b) {
      if (a.salesBase != b.salesBase) {
        return b.salesBase.compareTo(a.salesBase);
      }
      return a.label.compareTo(b.label);
    });
    if (rows.length > 50) rows.removeRange(50, rows.length);
  }

  return rows;
}

/// تجميع واحد لمبيعات الفترة حسب البعد — فواتير البيع المكتملة حصراً،
/// المبالغ بالأساس (`line_total × exchange_rate`)، وعدد الفواتير
/// **المميزة** (COUNT DISTINCT — السطور المتعددة لفاتورة واحدة لا
/// تضاعف العدد).
Future<List<Map<String, Object?>>> _salesAggregate(
  Database db,
  SalesByDimension dimension,
  String fromDay,
  String toDay,
) async {
  // التجميع والتسمية حسب البعد (قرار 5): LEFT JOIN للعميل/الفئة —
  // الفارغ يُجمَّع في سطر واحد (label = '').
  final (groupExpr, joins) = switch (dimension) {
    SalesByDimension.customer => (
      'c.id',
      'LEFT JOIN customer c ON c.id = i.customer_id',
    ),
    SalesByDimension.category => (
      'cat.id',
      'LEFT JOIN product p ON p.id = ii.product_id '
          'LEFT JOIN category cat ON cat.id = p.category_id',
    ),
    SalesByDimension.item => ('p.id', 'JOIN product p ON p.id = ii.product_id'),
    SalesByDimension.day => ('date(i.issued_at)', ''),
  };
  final labelExpr = switch (dimension) {
    // العميل/الفئة قد يكونان NULL → COALESCE إلى '' (القرار 5).
    SalesByDimension.customer => "COALESCE(c.name, '')",
    SalesByDimension.category => "COALESCE(cat.name, '')",
    SalesByDimension.item => "COALESCE(p.name, '')",
    SalesByDimension.day => 'date(i.issued_at)',
  };

  return db.rawQuery(
    '''
      SELECT $labelExpr AS label,
             COALESCE(SUM(ii.line_total * i.exchange_rate), 0) AS salesBase,
             COUNT(DISTINCT i.id) AS invoiceCount
      FROM invoice_item ii
      JOIN invoice i ON i.id = ii.invoice_id
      $joins
      WHERE i.doc_type = 'sale' AND i.status = 'completed'
        AND date(i.issued_at) >= ? AND date(i.issued_at) <= ?
      GROUP BY $groupExpr
      ''',
    <Object?>[fromDay, toDay],
  );
}
