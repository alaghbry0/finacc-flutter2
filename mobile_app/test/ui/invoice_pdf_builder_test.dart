/// اختبار انحدار بنّاء PDF فاتورة المبيعات (موجة 1-a — UX-audit
/// A1/A5/A9): اسم العميل كان يُرسم مفككاً معكوساً لأن قيمة `_kvLine`
/// تمر بلا `textDirection.rtl` (شكوى المالك الحرفية)، وكانت أسماء شائعة
/// (9 من 17 في تجربة pdfprobe) تكسر `pdf.save` بالكامل (`Bad state: No
/// element` في subsetter الخط). هنا يُبنى مستند كامل بخطوط Almarai
/// الحقيقية ويُفحص: بناء بلا استثناء + ترويسة %PDF + حجم منطقي + عدد
/// الصفحات (التدفق إلى صفحة ثانية عبر MultiPage).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/features/printing/services/invoice_pdf_builder.dart';

import '../helpers/printing_docs_for_tests.dart';

void main() {
  testWidgets('يبني فاتورة كاملة متعددة الصفحات باسم عربي كاسر', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      // 30 بنداً تُفيض إلى صفحة ثانية بنفس الشريط والتذييل.
      final doc = invoiceDocForTests(
        l10n,
        partyName: 'أحمد محمد الشرعبي',
        itemCount: 30,
      );
      final pdf = await const InvoicePdfBuilder().build(doc);
      final bytes = await pdf.save();
      expect(String.fromCharCodes(bytes, 0, 4), '%PDF');
      expect(bytes.length, greaterThan(15 * 1024));
      expect(pdfPageCount(bytes), 2, reason: 'تدفق MultiPage لصفحة ثانية');
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('كل أسماء pdfprobe (الكاسرة سابقاً) تبني بنجاح', (tester) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      for (final name in kPdfProbeNames) {
        final doc = invoiceDocForTests(l10n, partyName: name, itemCount: 2);
        final pdf = await const InvoicePdfBuilder().build(doc);
        final bytes = await pdf.save();
        expect(String.fromCharCodes(bytes, 0, 4), '%PDF', reason: name);
        expect(bytes.length, greaterThan(4 * 1024), reason: name);
        expect(pdfPageCount(bytes), 1, reason: name);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
