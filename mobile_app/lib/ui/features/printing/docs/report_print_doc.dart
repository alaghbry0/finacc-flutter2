/// مسقط التقرير الجدولي العام للطباعة (V7-B — عدة تصدير التقارير):
/// إسقاط **نقي** يغلّف أي تقرير جدولي (المبيعات حسب الصنف/العميل،
/// أعمار الديون، حركات الأصناف، ملخص المخزون…) في قالب A4 واحد.
///
/// بنية المستند: شريط هوية المنشأة (يتكرر أعلى كل صفحة) ← عنوان
/// التقرير ← صف «الفترة: … / تاريخ التقرير: …» ← جدول بأعمدة فيزيائية
/// RTL (أول عمود بالقائمة = أقصى اليمين) ← صف الإجمالي الداكن إن وجد
/// ← تذييل موحد.
///
/// قاعدة الملزمة المعمارية (نمط print_docs): كل نص يظهر داخل ملف PDF
/// يمر عبر هذا المسقط كقيمة **مسبقة التعريب/التنسيق** يبنيها المستدعي
/// من l10n — القالب نفسه بلا أي نص حرفي قابل للترجمة. الأرقام تصل
/// سلاسل جاهزة منسقة بـ`AmountText.format` (غربية بفواصل آلاف).
library;

import 'print_docs.dart';

/// مواصفة عمود في جدول التقرير المطبوع.
///
/// [label] تسمية رأس العمود (جاهزة من l10n عادة). [numeric] تعلّم عمودًا
/// رقميًا: خلاياه تُرسم بالخط المرافق الجدولي (UX-2b) باتجاه LTR ومحاذاة
/// يسار فتستقيم الأرقام عموديًا على الورق. [ltr] يعلّم عمودًا محتواه
/// لاتيني/أرقام مستندات (INV-2026-…) فيُرسم LTR بخط الجسم بلا خط جدولي.
class ReportColumnSpec {
  const ReportColumnSpec(this.label, {this.numeric = false, this.ltr = false});

  /// تسمية رأس العمود (سلسلة جاهزة من المستدعي).
  final String label;

  /// عمود رقمي — خلايا جدولية LTR (أرقام متساوية العرض).
  final bool numeric;

  /// عمود لاتيني الاتجاه (أرقام مستندات/رموز) — LTR بخط الجسم.
  final bool ltr;
}

/// مستند تقرير جدولي عام قابل للطباعة — يغذي قالب A4 (ReportPdfBuilder).
///
/// [rows] كل القيم سلاسل جاهزة للعرض مسبقة التنسيق من المستدعي؛ الصفوف
/// القصيرة/الطويلة عن [columns] يطبعها القالب بصبر (قص/حشو بخلايا فارغة)
/// فلا ينهار البناء أبدًا. [totalRow] (اختيارية) بنفس عدد الأعمدة تُرسم
/// بشريط داكن (PrintPalette.brandDeep) أسفل الجدول.
class ReportPrintDoc {
  const ReportPrintDoc({
    required this.header,
    required this.title,
    required this.periodLabel,
    required this.periodText,
    required this.dateLabel,
    required this.dateText,
    required this.columns,
    required this.rows,
    this.totalRow,
    required this.footerThanks,
  });

  /// رأس المنشأة (شريط الهوية أعلى كل صفحة).
  final PrintHeader header;

  /// عنوان التقرير («المبيعات حسب الصنف»… — سلسلة جاهزة).
  final String title;

  /// تسمية حقل الفترة («الفترة» — من l10n.reportPdfPeriodLabel).
  final String periodLabel;

  /// قيمة الفترة («من X إلى Y» أو اسم الشهر… — سلسلة جاهزة).
  final String periodText;

  /// تسمية حقل التاريخ («تاريخ التقرير» — من l10n.reportPdfDateLabel).
  final String dateLabel;

  /// قيمة التاريخ (`08/10/2026 14:30` — سلسلة جاهزة بأرقام جدولية).
  final String dateText;

  /// مواصفات الأعمدة بالترتيب المنطقي العربي — **أول عمود بالقائمة =
  /// أقصى يمين الجدول** (القالب يقلب الترتيب فيزيائيًا بنفسه).
  final List<ReportColumnSpec> columns;

  /// صفوف البيانات — كل قيمة سلسلة جاهزة، بترتيب [columns] نفسه.
  final List<List<String>> rows;

  /// صف الإجمالي (اختياري — «الإجمالي، —، —، 45,000») بنفس ترتيب
  /// الأعمدة؛ يُرسم بشريط داكن بخط أبيض عريض.
  final List<String>? totalRow;

  /// عبارة الشكر في التذييل (من l10n.printingFooterThanks).
  final String footerThanks;
}
