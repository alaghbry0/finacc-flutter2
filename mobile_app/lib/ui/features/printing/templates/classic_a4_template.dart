/// قالب «كلاسيكي A4 أفقي» (موجة UX-3) — محاكاة حرفية لنموذج المالك
/// الحكومي: إطار خارجي رفيع للصفحة · اسم المنشأة يميناً + الشعار وسطاً
/// (`company.logo_png` وإلا monogram) + بيانات المتجر يساراً · صندوق
/// أزرق سماوي بنص أبيض لوضع الدفع بمنتصف الأعلى · رقم الفاتورة
/// **بالأحمر** يميناً والتاريخ يساراً · بيانات العميل أسطر نصية يمينية
/// بلا إطار · جدول أصناف بإطار خارجي **سميك** وحدود داخلية رفيعة ورأس
/// **مظلل** عريض (الصنف أقصى اليمين) · خط مزدوج فاصل · جدول إجماليات
/// صغير يميناً (صف الإجمالي بخلفية كريمية والمتبقي بأحمر عريض) · خانة
/// ملاحظات · ثلاث خانات توقيع أفقية (المستلم/المحصل/البائع) · مساحة
/// ختم محجوزة.
///
/// استراتيجية RTL (النمط المُجرَّب بالبناة القائمة): الأعمدة فيزيائية
/// LTR بحيث يقع وصف الصنف أقصى اليمين، وكل خلية نص عربي تُرسم
/// `textDirection: rtl` — والأرقام بأعمدة tnum (Noto) بترتيبها الطبيعي.
///
/// كل تسمية تصل مسبقة التعريب من `InvoicePrintDoc` — لا نص حرفي هنا.
///
/// أقسام التخطيط مستخرجة إلى ملفات مركزّة بجوار القالب (R19-D3c):
/// الترويسة (`classic_a4_header.dart`) وكتلة الطرف (`classic_a4_party.dart`)
/// وجدول الأصناف (`classic_a4_items_table.dart`) والإجماليات
/// (`classic_a4_totals.dart`) والذيل (`classic_a4_footer.dart`)
/// والمساعدات المشتركة (`classic_a4_helpers.dart`).
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../../../../data/models/invoice_template_settings.dart';
import '../docs/print_docs.dart';
import 'classic_a4_footer.dart';
import 'classic_a4_header.dart';
import 'classic_a4_helpers.dart';
import 'classic_a4_items_table.dart';
import 'classic_a4_party.dart';
import 'classic_a4_totals.dart';
import 'template_colors.dart';

export 'classic_a4_totals.dart' show kClassicCream;

/// سقف البنود لصفحة الكلاسيكي المُأطَّرة الواحدة (A4 أفقي: ~198مم ارتفاع
/// محتوى — الترويسة/الإجماليات/التوقيعات تأكل النصيب الأكبر). فوقه
/// يتحول القالب تلقائياً إلى تدفق MultiPage (بلا إطار صفحة — الترويسة
/// والتذييل يتكرران بكل صفحة كنماذج الجهات المتعددة الصفحات).
const int kClassicSinglePageMaxRows = 14;

/// بنّاء القالب الكلاسيكي.
class ClassicA4InvoiceTemplate {
  const ClassicA4InvoiceTemplate();

  /// يضيف صفحات القالب داخل مستند المحرك.
  void addPages(
    pw.Document pdf,
    InvoicePrintDoc doc,
    InvoiceTemplateSettings settings,
    Uint8List? logoPng,
  ) {
    if (doc.items.length <= kClassicSinglePageMaxRows) {
      pdf.addPage(_framedPage(doc, settings, logoPng));
    } else {
      _addFlowPages(pdf, doc, settings, logoPng);
    }
  }

  // -------------------------------------------------------------------
  // الصفحة المُأطَّرة الواحدة (نموذج المالك)
  // -------------------------------------------------------------------

  pw.Page _framedPage(
    InvoicePrintDoc doc,
    InvoiceTemplateSettings settings,
    Uint8List? logoPng,
  ) {
    return pw.Page(
      pageFormat: pw.PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(6 * pw.PdfPageFormat.mm),
      build: (context) => pw.Container(
        // الإطار الخارجي الرفيع للصفحة كلها.
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: templatePdfColor(settings.borderArgb),
            width: 0.8,
          ),
        ),
        padding: const pw.EdgeInsets.all(4 * pw.PdfPageFormat.mm),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            classicTopHeader(doc, settings, logoPng),
            classicGap(2),
            classicCustomerLines(doc),
            classicGap(2),
            pw.Expanded(child: classicItemsTable(doc, settings)),
            classicGap(2),
            classicDoubleRule(settings),
            classicGap(2),
            classicTotalsRow(doc, settings),
            classicGap(3),
            if (settings.showSignatures) ...[
              classicSignaturesRow(doc),
              classicGap(2),
            ],
            if (settings.showBarcode && classicDocNoIsEncodable(doc))
              classicBarcode(doc),
            if (settings.showFooter) classicFooterRow(doc),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // التدفق للبنود الكثيرة (فوق السقف) — نفس اللغة البصرية بلا إطار
  // -------------------------------------------------------------------

  void _addFlowPages(
    pw.Document pdf,
    InvoicePrintDoc doc,
    InvoiceTemplateSettings settings,
    Uint8List? logoPng,
  ) {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pw.PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(8 * pw.PdfPageFormat.mm),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            classicTopHeader(doc, settings, logoPng),
            classicGap(2),
            classicCustomerLines(doc),
            classicGap(2),
          ],
        ),
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            classicGap(2),
            if (settings.showSignatures) ...[
              classicSignaturesRow(doc),
              classicGap(2),
            ],
            if (settings.showBarcode && classicDocNoIsEncodable(doc))
              classicBarcode(doc),
            if (settings.showFooter) classicFooterRow(doc),
          ],
        ),
        build: (context) => [
          classicItemsTable(doc, settings),
          classicGap(2),
          classicDoubleRule(settings),
          classicGap(2),
          classicTotalsRow(doc, settings),
        ],
      ),
    );
  }
}
