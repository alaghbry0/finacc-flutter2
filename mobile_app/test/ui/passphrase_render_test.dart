/// اختبار شاشة عبارة المرور (الشريحة 10 — تشخيصي تحوّل انحدارياً):
/// يثبت أن الرحلة الكاملة (ترحيب ← منشأة ← PIN ← تأكيد ← عبارة المرور)
/// تعمل على عرض هاتف 390×844: الحقلان والزر داخل إطار العرض، والزر
/// يُفعَّل عند تطابق الحقلين، والإرسال ينقل لخطوة الإنشاء.
///
/// خلفية: عطلت جولة QA الحية إدخال عبارة المرور عبر أحداث CDP
/// التركيبية (فك تعليق حالة التحرير في Chrome بلا واجهة) — هذا
/// الاختبار يثبت أن الشاشة نفسها سليمة البنية والرسم على عرض الهاتف.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/onboarding_auth/views/onboarding_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  testWidgets('شاشة عبارة المرور كاملة على 390×844: الحقلان والزر والإرسال', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      final seeded = await openSeededApp();
      addTearDown(seeded.$1.close);
      final controller = AppController(forTesting: seeded.$1);
      await controller.decidePhaseForTest();
      controller.unlockSession();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: const MaterialApp(
            home: OnboardingScreen(),
            locale: Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // شاشة الترحيب: تمرير لزر المتابعة ثم الضغط عليه.
      await tester.scrollUntilVisible(
        find.text('متابعة'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('متابعة'));
      await tester.pump(const Duration(milliseconds: 300));
      // انتظار تحميل العملات (runAsync يسمح بـ Future حقيقي).
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // الخطوة 1: اسم المنشأة ثم متابعة (YER الافتراضية أولاً — أول
      // خيار عملة مختار مسبقاً في النموذج).
      await tester.enterText(find.byType(TextField).first, 'متجر التشخيص');
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('متابعة'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();

      // الخطوة 2: إدخال PIN — الإرسال التلقائي عند 6 خانات (P2-9، توحيداً
      // مع لوحة شاشة القفل): كل إدخال مكتمل ينتقل للخطوة التالية بلا زر.
      Future<void> enterPin() async {
        for (final digit in ['4', '5', '6', '7', '8', '9']) {
          await tester.tap(find.text(digit).last);
          await tester.pump(const Duration(milliseconds: 120));
        }
        await tester.pumpAndSettle();
      }

      await enterPin();
      // الإرسال التلقائي نقلنا لوضع التأكيد (لا زر «متابعة» بعد الآن).
      expect(
        find.text('تأكيد الرمز'),
        findsOneWidget,
        reason: 'الإرسال التلقائي عند 6 خانات انتقل للتأكيد (P2-9)',
      );
      await enterPin();
      // التطابق نقلنا تلقائياً لقسم عبارة المرور.
      await tester.pumpAndSettle();

      // شاشة عبارة المرور — التحقق الهيكلي الحاسم.
      expect(
        find.text('عبارة المرور (8 خانات فأكثر)'),
        findsOneWidget,
        reason: 'وسم الحقل الأول موجود',
      );
      expect(
        find.text('تأكيد عبارة المرور'),
        findsOneWidget,
        reason: 'وسم الحقل الثاني موجود في الشجرة',
      );

      // هندسة الحقلين والزر داخل إطار العرض (390×844).
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2), reason: 'حقلا عبارة المرور موجودان');
      final field2 = fields.evaluate().last.findRenderObject() as RenderBox;
      final field2Top = field2.localToGlobal(Offset.zero).dy;
      expect(
        field2Top > 0 && field2Top < 844,
        isTrue,
        reason: 'الحقل الثاني داخل إطار العرض (y=$field2Top)',
      );
      final buttonFinder = find.widgetWithText(FilledButton, 'متابعة');
      expect(buttonFinder, findsOneWidget, reason: 'زر المتابعة موجود');
      final button =
          buttonFinder.evaluate().single.findRenderObject() as RenderBox;
      final buttonTop = button.localToGlobal(Offset.zero).dy;
      expect(
        buttonTop > 0 && buttonTop < 844,
        isTrue,
        reason: 'الزر داخل إطار العرض (y=$buttonTop)',
      );

      // الزر معطّل قبل الملء.
      expect(
        (tester.widget<FilledButton>(buttonFinder)).onPressed,
        isNull,
        reason: 'الزر معطّل قبل تطابق الحقلين',
      );

      // ملء الحقلين بقيم متطابقة عبر enterText (يطلق onChanged فعلياً).
      await tester.enterText(fields.at(0), 'FinAcc-2026');
      await tester.pump();
      await tester.enterText(fields.at(1), 'FinAcc-2026');
      await tester.pumpAndSettle();

      // الزر يتحول للعمل (passphraseFormValid).
      expect(
        (tester.widget<FilledButton>(buttonFinder)).onPressed,
        isNotNull,
        reason: 'الزر مفعّل بعد تطابق الحقلين',
      );

      // الإرسال ينقل لخطوة الإنشاء (دوار التقدم) أو يكملها.
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pump(const Duration(milliseconds: 400));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      // بعد الإنشاء: إما شاشة الإتمام أو قفل/جاهزية (المنشأة أُنشئت).
      final completed =
          find.text('تم إنشاء متجر التشخيص بنجاح').evaluate().isNotEmpty ||
          controller.phase != AppPhase.needsOnboarding;
      expect(
        completed,
        isTrue,
        reason: 'المنشأة أُنشئت بعد الإرسال (phase=${controller.phase})',
      );
    });
  });
}
