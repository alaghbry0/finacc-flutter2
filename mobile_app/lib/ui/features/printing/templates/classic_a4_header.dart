/// ترويسة القالب الكلاسيكي (R19-D3c — مستخرجة حرفياً من
/// `classic_a4_template.dart` بلا أي تغيير دلالة): المنشأة يميناً +
/// الشعار وسطاً + بيانات المتجر يساراً + صندوق وضع الدفع + صف رقم
/// الفاتورة/التاريخ/الشارة.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../../../../data/models/invoice_template_settings.dart';
import '../core/print_palette.dart';
import '../core/print_widgets.dart';
import '../docs/print_docs.dart';
import 'classic_a4_helpers.dart';
import 'template_colors.dart';

// -------------------------------------------------------------------
// الترويسة: المنشأة يميناً + الشعار وسطاً + بيانات المتجر يساراً +
// صندوق وضع الدفع + صف رقم الفاتورة/التاريخ/الشارة
// -------------------------------------------------------------------

pw.Widget classicTopHeader(
  InvoicePrintDoc doc,
  InvoiceTemplateSettings settings,
  Uint8List? logoPng,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        children: [
          // بيانات المتجر — يسار الصفحة (فيزيائياً أولاً).
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                classicStoreLine(doc.header.phone),
                classicStoreLine(doc.header.address),
                if (settings.showTax && (doc.taxNumber ?? '').trim().isNotEmpty)
                  classicStoreLine(doc.taxNumber, prefix: classicTaxLabel(doc)),
              ],
            ),
          ),
          pw.SizedBox(width: 6 * pw.PdfPageFormat.mm),
          // الشعار — وسط الترويسة (BLOB المنشأة وإلا monogram).
          classicLogoBox(logoPng, doc.header.name),
          pw.SizedBox(width: 6 * pw.PdfPageFormat.mm),
          // اسم المنشأة — يمين الصفحة (جهة القراءة الأولى).
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                doc.header.name,
                style: PrintText.head(color: PrintPalette.brandDeep, size: 16),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
          ),
        ],
      ),
      classicGap(2),
      // صندوق وضع الدفع الملون بنص أبيض — منتصف أعلى النموذج.
      pw.Center(
        child: pw.Container(
          width: 74 * pw.PdfPageFormat.mm,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
          color: templateDarken(templatePdfColor(settings.tableHeadArgb)),
          child: pw.Text(
            doc.payStatusLabel ?? doc.labels.title,
            style: PrintText.head(color: pw.PdfColors.white, size: 13.5),
            textAlign: pw.TextAlign.center,
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      ),
      classicGap(2),
      classicDocNoRow(doc, settings),
    ],
  );
}

/// سطر بيانات متجر صغير (أو «تسمية: قيمة» للضريبة) — يسار الترويسة.
pw.Widget classicStoreLine(String? value, {String? prefix}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return pw.SizedBox(height: 0);
  final composed = prefix == null || prefix.isEmpty ? text : '$prefix: $text';
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 1),
    child: pw.Text(
      composed,
      style: PrintText.body(color: PrintPalette.inkSoft, size: 9),
      textDirection: pw.TextDirection.rtl,
    ),
  );
}

String? classicTaxLabel(InvoicePrintDoc doc) => doc.templateLabels?.taxNumber;

/// الشعار وسط الترويسة — من `company.logo_png` وإلا monogram بالحرف
/// الأول داخل إطار مستدير الزوايا (نفس فكرة البنّاء القائم).
pw.Widget classicLogoBox(Uint8List? logoPng, String businessName) {
  if (logoPng != null && logoPng.isNotEmpty) {
    final image = pw.MemoryImage(logoPng);
    final pxW = image.width?.toDouble() ?? 0;
    final pxH = image.height?.toDouble() ?? 0;
    if (pxW > 0 && pxH > 0) {
      const maxH = 17.0 * pw.PdfPageFormat.mm;
      const maxW = 26.0 * pw.PdfPageFormat.mm;
      var h = maxH;
      var w = h * pxW / pxH;
      if (w > maxW) {
        w = maxW;
        h = w * pxH / pxW;
      }
      return pw.Center(
        child: pw.Image(image, width: w, height: h),
      );
    }
  }
  return pw.Container(
    width: 15 * pw.PdfPageFormat.mm,
    height: 15 * pw.PdfPageFormat.mm,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PrintPalette.brand, width: 1.2),
      borderRadius: pw.BorderRadius.circular(20),
    ),
    child: pw.Text(
      printMonogram(businessName),
      style: PrintText.head(color: PrintPalette.brandDeep, size: 15),
    ),
  );
}

/// صف رقم الفاتورة (أحمر عريض يميناً) + التاريخ يساراً + شارة النسخة.
pw.Widget classicDocNoRow(
  InvoicePrintDoc doc,
  InvoiceTemplateSettings settings,
) {
  final red = templatePdfColor(settings.accentRedArgb);
  final badgeText = classicBadgeText(doc, settings);
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      // يسار (فيزيائياً أولاً): التاريخ وتحته/بجانبه شارة النسخة.
      pw.Row(
        children: [
          if (badgeText != null) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: red, width: 0.9),
              ),
              child: pw.Text(
                badgeText,
                style: PrintText.head(color: red, size: 10),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
            pw.SizedBox(width: 4 * pw.PdfPageFormat.mm),
          ],
          pw.Text(
            '${doc.labels.date}: ${doc.dateLabel}',
            style: PrintText.body(size: 10),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
      // يمين: رقم الفاتورة بالأحمر العريض (نموذج المالك).
      pw.Text(doc.docNo, style: PrintText.head(color: red, size: 13)),
    ],
  );
}

/// نص شارة النسخة (أصل/صورة) — null عند «بلا» أو غياب التسمية.
String? classicBadgeText(
  InvoicePrintDoc doc,
  InvoiceTemplateSettings settings,
) {
  final labels = doc.templateLabels;
  return switch (settings.badge) {
    InvoiceBadgeMode.original => labels?.badgeOriginal,
    InvoiceBadgeMode.copy => labels?.badgeCopy,
    InvoiceBadgeMode.none => null,
  };
}
