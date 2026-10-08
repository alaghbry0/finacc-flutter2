/// اختبار دخان بنّاء PDF تقرير الأرباح والخسائر (FR-09-02 — الشريحة
/// 10): يبني مستنداً كاملاً بخطوط Almarai الحقيقية (rootBundle) ويعرض
/// بايتات `%PDF` — يحرس قالب الملحق (بنية صفحة A4/RTL/الجدول اليدوي
/// الملوّن) ضد أي كسر API في حزمة pdf دون فتح معاينة حقيقية.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/repositories/profit_report_repository.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/features/printing/services/profit_report_pdf_builder.dart';

void main() {
  testWidgets('البنّاء يُخرج PDF سليماً بخطوط Almarai وتقرير معبأ', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      // تقرير بكل السطور ممتلئة + إشارات سالبة (فروق صرف خسارة).
      final report = ProfitReport(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
        sales: 1250,
        salesReturns: 250,
        cogs: 700,
        returnCost: 150,
        stockSurplus: 300,
        stockShortage: 120,
        expenses: 180,
        fxGainLoss: -40,
        ownerDrawings: 90,
        salesInvoiceCount: 5,
        returnInvoiceCount: 2,
      );
      expect(report.profit, 410, reason: '(1250−250)−(700−150)+300−120−180−40');

      final doc = buildProfitPrintDoc(
        l10n: l10n,
        report: report,
        currencyCode: 'YER',
        decimals: 0,
        generatedAt: DateTime(2026, 11, 30, 14, 30),
      );

      // المسقط نفسه: التسميات معربة والقيم موقّعة منسّقة.
      expect(doc.labels.title, 'تقرير الأرباح والخسائر');
      expect(doc.periodLabel, contains('2026'));
      expect(doc.sections, hasLength(4), reason: 'إيراد/تكلفة/تسويات/مصاريف');
      expect(doc.sections.first.lines, hasLength(3));
      expect(doc.sections.first.lines.first.valueLabel, '+1,250');
      expect(doc.sections.last.lines.single.valueLabel, '−180');

      final pdf = await const ProfitReportPdfBuilder().build(doc);
      final bytes = await pdf.save();
      // PDF حقيقي: ترويسة %PDF وحجم معقول بخطوط مضمّنة.
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes, 0, 4), '%PDF');
    });
  });
}
