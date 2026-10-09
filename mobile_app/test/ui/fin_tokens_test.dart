/// اختبارات موجة UX-2b (التلميع البصري): توكنات التصميم + الخط المرافق
/// للأرقام الجدولية (NotoSansArabic بعائلة أساسية مع fallback إلى
/// Almarai) + عدّاد الفواتير بأرقام النظام + تضمين الخط الجدولي في PDF
/// المطبوع (اسم BaseFont يظهر في بايتات المستند).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/theme/app_colors.dart';
import 'package:mobile_app/ui/core/theme/app_typography.dart';
import 'package:mobile_app/ui/core/theme/fin_tokens.dart';
import 'package:mobile_app/ui/core/widgets/numerals_scope.dart';
import 'package:mobile_app/ui/core/widgets/stat_tile.dart';
import 'package:mobile_app/ui/features/printing/services/invoice_pdf_builder.dart';

import '../helpers/printing_docs_for_tests.dart';

void main() {
  group('FinTokens — خريطة الاتساق البصري (UX-2b)', () {
    test('سلّم الفراغات الموحد 4/8/12/16/20/24/32 + قاع FAB', () {
      expect(FinSpacing.xs, 4);
      expect(FinSpacing.sm, 8);
      expect(FinSpacing.md, 12);
      expect(FinSpacing.lg, 16);
      expect(FinSpacing.xl, 20);
      expect(FinSpacing.xxl, 24);
      expect(FinSpacing.bottom, 32);
      expect(FinSpacing.fabClearance, 96);
    });

    test('أنصاف الأقطار: شرائح 8/أزرار 12/بطاقات 16/حوارات 20/أوراق 24', () {
      expect(FinRadius.chip, 8);
      expect(FinRadius.control, 12);
      expect(FinRadius.card, 16);
      expect(FinRadius.dialog, 20);
      expect(FinRadius.sheet, 24);
      expect(FinRadius.cardBorder, BorderRadius.circular(16));
      expect(FinRadius.controlBorder, BorderRadius.circular(12));
    });

    test('الحركة الموحدة 420ms + fast 220ms + منحنى easeOutCubic', () {
      expect(FinMotion.standard, const Duration(milliseconds: 420));
      expect(FinMotion.fast, const Duration(milliseconds: 220));
      expect(FinMotion.curve, Curves.easeOutCubic);
    });
  });

  group('FinText — الخط المرافق للأرقام الجدولية (DS-18n)', () {
    test('أنماط المبالغ تتصدّرها NotoSansArabic مع fallback إلى Almarai', () {
      for (final style in [
        FinText.amountDisplay(const Color(0xFF000000)),
        FinText.amountLarge(const Color(0xFF000000)),
        FinText.amountRow(const Color(0xFF000000)),
      ]) {
        expect(style.fontFamily, 'NotoSansArabic');
        expect(style.fontFamilyFallback, <String>['Almarai']);
        expect(style.fontFeatures, FinText.tabularNums);
      }
    });

    test('withTabularDigits يحوّل أي نمط دون مساس بقيمه الأخرى', () {
      final base = TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: const Color(0xFF123456),
      );
      final out = FinText.withTabularDigits(base);
      expect(out.fontFamily, 'NotoSansArabic');
      expect(out.fontFamilyFallback, <String>['Almarai']);
      expect(out.fontWeight, FontWeight.w700);
      expect(out.fontSize, 16);
      expect(out.color, const Color(0xFF123456));
    });

    test('هوية النصوص تبقى Almarai (بلا fallback)', () {
      final body = FinText.amountLabel(const Color(0xFF000000));
      expect(body.fontFamily, 'Almarai');
      expect(body.fontFamilyFallback, isNull);
    });
  });

  group('FinColors — توكن واتساب بوضعين (UX-2b)', () {
    test('الوضعان لهما زوج whatsappContainer/onWhatsappContainer مختلف', () {
      expect(FinColors.light.whatsappContainer, const Color(0xFFD7F2E4));
      expect(FinColors.light.onWhatsappContainer, const Color(0xFF075E54));
      expect(FinColors.dark.whatsappContainer, const Color(0xFF113528));
      expect(FinColors.dark.onWhatsappContainer, const Color(0xFFA6EFD0));
      expect(
        FinColors.dark.whatsappContainer,
        isNot(FinColors.light.whatsappContainer),
      );
    });
  });

  group('StatTile — عدّاد الفواتير بأرقام النظام الحي', () {
    testWidgets('غربي افتراضياً وعربي شرقي تحت NumeralsScope', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: FinText.fontFamily),
          home: const NumeralsScope(
            arabicIndic: false,
            child: StatTile(
              label: 'فواتير اليوم',
              value: 7,
              icon: Icons.receipt_long_rounded,
              isCount: true,
            ),
          ),
        ),
      );
      expect(find.text('7'), findsOneWidget);
      expect(find.text('٧'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: FinText.fontFamily),
          home: const NumeralsScope(
            arabicIndic: true,
            child: StatTile(
              label: 'فواتير اليوم',
              value: 7,
              icon: Icons.receipt_long_rounded,
              isCount: true,
            ),
          ),
        ),
      );
      expect(find.text('٧'), findsOneWidget);
      expect(find.text('7'), findsNothing);
    });
  });

  group('الطباعة — الخط الجدولي المرافق في PDF (UX-2b)', () {
    testWidgets('فاتورة مطبوعة تضمّن NotoSansArabic إلى جوار Almarai', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
        final doc = invoiceDocForTests(
          l10n,
          partyName: 'أحمد محمد الشرعبي',
          itemCount: 2,
        );
        final pdf = await const InvoicePdfBuilder().build(doc);
        final bytes = await pdf.save();
        expect(String.fromCharCodes(bytes, 0, 4), '%PDF');
        // أرقام جدولية على الورق: الخط المرافق مضمّن فعلاً في المستند،
        // وهوية Almarai حاضرة للنصوص العربية (لا استبدال للهوية).
        final latin = String.fromCharCodes(
          bytes.map((b) => b < 128 ? b : 0x20),
        );
        expect(latin.contains('NotoSansArabic'), isTrue);
        expect(latin.contains('Almarai'), isTrue);
      });
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
