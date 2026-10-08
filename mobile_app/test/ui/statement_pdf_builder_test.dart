/// اختبار انحدار بنّاء PDF كشف حساب الطرف (موجة 1-a — UX-audit
/// A2/A5/A9): اسم الطرف والفترة «من … إلى …» كانا يُرسمان مفككين
/// معكوسين لأن قيمة `_kvLine` تمر بلا `textDirection.rtl`، وكانت أسماء
/// شائعة تكسر `pdf.save` بالكامل. هنا يُبنى مستند كامل بخطوط Almarai
/// الحقيقية بأسماء كاسرة ويُفحص: %PDF + الحجم + عدد الصفحات (تدفق
/// الكشوف الطويلة عبر MultiPage).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/features/printing/services/statement_pdf_builder.dart';

import '../helpers/printing_docs_for_tests.dart';

void main() {
  testWidgets('يبني كشفاً كاملاً متعدد الصفحات باسم طرف عربي كاسر', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      // 60 قيداً تُفيض إلى صفحة ثانية.
      final doc = statementDocForTests(
        l10n,
        partyName: 'أحمد محمد الشرعبي',
        lineCount: 60,
      );
      final pdf = await const StatementPdfBuilder().build(doc);
      final bytes = await pdf.save();
      expect(String.fromCharCodes(bytes, 0, 4), '%PDF');
      expect(bytes.length, greaterThan(15 * 1024));
      expect(pdfPageCount(bytes), greaterThanOrEqualTo(2));
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('كل أسماء pdfprobe (الكاسرة سابقاً) تبني كشفاً بنجاح', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      for (final name in kPdfProbeNames) {
        final doc = statementDocForTests(l10n, partyName: name, lineCount: 4);
        final pdf = await const StatementPdfBuilder().build(doc);
        final bytes = await pdf.save();
        expect(String.fromCharCodes(bytes, 0, 4), '%PDF', reason: name);
        expect(bytes.length, greaterThan(4 * 1024), reason: name);
        expect(pdfPageCount(bytes), 1, reason: name);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
