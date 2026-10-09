/// محرك قوالب فواتير المبيعات (موجة UX-3) — **يفهرس القوالب ويسلّم
/// `pw.Document`**: يوحّد الثيم (Almarai عبر PrintFonts) وخطوط النص،
/// ويوزّع البناء على القالب المطلوب بالإعدادات:
///
/// - `classic_a4` — أفقي محاكٍ لنموذج المالك الحكومي.
/// - `simple_a4` — البنّاء القائم كما هو (الافتراضي).
/// - `thermal_80` — إيصال رول 80مم بباركود Code128.
///
/// كل استدعاء يبدأ بـ`PrintFonts.load()` (idempotent) — المستدعي لا
/// يحتاج تحميل الخطوط بنفسه. الشعار يمر اختيارياً من `company.logo_png`.
library;

import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../core/print_fonts.dart';
import '../print_docs.dart';
import 'classic_a4_template.dart';
import 'invoice_template_settings.dart';
import 'simple_a4_template.dart';
import 'thermal_80_template.dart';

/// بطاقة قالب في فهرس المحرك — تسميات العرض تبنيها الشاشة من l10n
/// (المحرك يحمل الكود والورق فقط، بلا نصوص).
class InvoiceTemplateDescriptor {
  const InvoiceTemplateDescriptor({
    required this.code,
    required this.paper,
    required this.landscape,
  });

  /// كود القالب (يطابق جدول print_template).
  final String code;

  /// الورق (`a4-landscape` / `a4-portrait` / `roll80`).
  final String paper;

  /// أفقي؟ (للمعاينة المصغّرة بالشاشة).
  final bool landscape;
}

/// بنّاء المستندات بموجب القالب النشط.
class InvoiceTemplateEngine {
  const InvoiceTemplateEngine();

  /// فهرس القوالب المعتمدة (بترتيب البذر).
  static const List<InvoiceTemplateDescriptor> templates =
      <InvoiceTemplateDescriptor>[
        InvoiceTemplateDescriptor(
          code: kInvoiceTemplateClassicA4,
          paper: 'a4-landscape',
          landscape: true,
        ),
        InvoiceTemplateDescriptor(
          code: kInvoiceTemplateSimpleA4,
          paper: 'a4-portrait',
          landscape: false,
        ),
        InvoiceTemplateDescriptor(
          code: kInvoiceTemplateThermal80,
          paper: 'roll80',
          landscape: false,
        ),
      ];

  /// يبني مستند الفاتورة بالقالب المطلوب — `settings` غيابه = البسيط
  /// الافتراضي (سلوك ما قبل UX-3 حرفياً).
  Future<pw.Document> build(
    InvoicePrintDoc doc, {
    InvoiceTemplateSettings? settings,
    Uint8List? logoPng,
  }) async {
    await PrintFonts.load();
    final effective = settings ?? const InvoiceTemplateSettings();
    switch (effective.templateId) {
      case kInvoiceTemplateClassicA4:
        final pdf = _document(doc);
        const ClassicA4InvoiceTemplate().addPages(
          pdf,
          doc,
          effective,
          logoPng,
        );
        return pdf;
      case kInvoiceTemplateThermal80:
        final pdf = _document(doc);
        const Thermal80InvoiceTemplate().addPages(pdf, doc, effective);
        return pdf;
      default:
        return const SimpleA4InvoiceTemplate().build(doc, effective);
    }
  }

  /// مستند موحّد الثيم: Almarai في كل مكان (لا يسقط النص الضمني إلى
  /// Courier غير اليونيكودي أبداً) — البنّاء القائم يبني ثيمه بنفسه
  /// فنبنيه هنا للقالبين الجديدين بالطريقة نفسها.
  pw.Document _document(InvoicePrintDoc doc) => pw.Document(
    title: doc.docNo,
    author: doc.header.name,
    creator: kPrintAppCredit,
    theme: pw.ThemeData.withFont(base: PrintFonts.regular, bold: PrintFonts.bold),
  );
}
