/// قالب «بسيط A4 عمودي» (موجة UX-3) — بناء [InvoicePdfBuilder] الحالي
/// منقولاً تحت المحرك **بسلوكه كما هو**: ترويسة brandDeep عمودية وجدول
/// [إجمالي/خصم/سعر/كمية/صنف] فيزيائي LTR وبطاقة إجماليات — نفس بصمة
/// المتجر المطبوعة منذ الشريحة 7.
///
/// إعدادات UX-3 تُطبَّق عليه فقط بتفعيلها من شاشة التخصيص: إسقاط عمود
/// الخصم، إدراج عمود الوحدة (عند توفر أسماء الوحدات)، إخفاء التذييل،
/// سطر الرقم الضريبي، وباركود رقم الفاتورة — والإعدادات المبذورة له
/// (هجرة v4) مطابقة لألوانه الحالية فلا يتغير المخرج الافتراضي ذرةً.
library;

import 'package:pdf/widgets.dart' as pw;

import '../print_docs.dart';
import '../services/invoice_pdf_builder.dart';
import 'invoice_template_settings.dart';

/// بنّاء قالب simple_a4 — مغلّف رفيع فوق [InvoicePdfBuilder].
class SimpleA4InvoiceTemplate {
  const SimpleA4InvoiceTemplate();

  /// يسلّم المستند الكامل (سلوك البنّاء القائم).
  Future<pw.Document> build(
    InvoicePrintDoc doc,
    InvoiceTemplateSettings settings,
  ) {
    return const InvoicePdfBuilder().build(doc, settings: settings);
  }
}
