/// اختبار انحدار بنّاء PDF تقرير الوردية (موجة 1-a — UX-audit
/// A4/A5/A9): الصندوق والمستخدم كانا يُرسمان مفككين معكوسين لأن قيمة
/// `_kvLine` تمر بلا `textDirection.rtl`، وصف «الفرق» المختلط
/// «250 · زيادة» كان يعاني نفس الكسر (تفكيك + خطر انهيار subsetter).
/// هنا يُبنى تقرير بخطوط Almarai الحقيقية بأسماء كاسرة وفرق زيادة وعجز
/// ويُفحص: %PDF + الحجم + صفحة A4 واحدة (بنود المعادلة محدودة).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/features/printing/services/shift_report_pdf_builder.dart';

import '../helpers/printing_docs_for_tests.dart';

void main() {
  testWidgets('يبني تقرير وردية كاملاً بصفحة واحدة (فرق زيادة مختلط)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      // difference = 250 → صف «250 · زيادة» المختلط من التدقيق.
      final doc = shiftDocForTests(
        l10n,
        userName: 'خالد سعيد',
        boxName: 'الصندوق الرئيسي',
        difference: 250,
      );
      final pdf = await const ShiftReportPdfBuilder().build(doc);
      final bytes = await pdf.save();
      expect(String.fromCharCodes(bytes, 0, 4), '%PDF');
      expect(bytes.length, greaterThan(6 * 1024));
      expect(pdfPageCount(bytes), 1, reason: 'تقرير الوردية صفحة واحدة');
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('كل أسماء pdfprobe (الكاسرة سابقاً) تبني تقريراً بنجاح', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      for (var i = 0; i < kPdfProbeNames.length; i++) {
        // بالتناوب: الاسم مرة مستخدماً ومرة صندوقاً + فرق عجز سالب.
        final name = kPdfProbeNames[i];
        final doc = shiftDocForTests(
          l10n,
          userName: i.isEven ? name : 'أبو نور',
          boxName: i.isOdd ? name : 'الصندوق الرئيسي',
          difference: i.isEven ? 250 : -120,
        );
        final pdf = await const ShiftReportPdfBuilder().build(doc);
        final bytes = await pdf.save();
        expect(String.fromCharCodes(bytes, 0, 4), '%PDF', reason: name);
        expect(bytes.length, greaterThan(4 * 1024), reason: name);
        expect(pdfPageCount(bytes), 1, reason: name);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
