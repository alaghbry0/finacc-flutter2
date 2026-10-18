/// مساعدات القالب الكلاسيكي المشتركة بين أقسامه (R19-D3c — مستخرجة
/// حرفياً من `classic_a4_template.dart` بلا أي تغيير دلالة).
library;

import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;

import '../docs/print_docs.dart';

pw.SizedBox classicGap(double mm) =>
    pw.SizedBox(height: mm * pw.PdfPageFormat.mm);

/// هل رقم الفاتورة قابلاً للترميز Code128؟ (لاتيني/أرقام حصراً —
/// الأكواد الحالية `INV-YYYY-NNNNN` دائماً كذلك).
bool classicDocNoIsEncodable(InvoicePrintDoc doc) =>
    RegExp(r'^[\x00-\x7F]*$').hasMatch(doc.docNo);
