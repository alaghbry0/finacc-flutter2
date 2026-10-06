/// اختبارات بصرية للمكونات الأساسية — PinPad LTR وAmountText ونظام الأرقام.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/ui/core/theme/app_colors.dart';
import 'package:mobile_app/ui/core/widgets/amount_text.dart';
import 'package:mobile_app/ui/core/widgets/numerals_scope.dart';
import 'package:mobile_app/ui/core/widgets/pin_pad.dart';

import '../helpers/app_for_tests.dart';

void main() {
  group('PinPad — فيزيائية LTR (معيار مالي عربي)', () {
    testWidgets('الصف الأول فعلياً 1-2-3 من اليسار داخل حاوية RTL', (
      tester,
    ) async {
      final digits = <int>[];
      await tester.pumpWidget(
        wrapWithL10n(
          Directionality(
            textDirection: TextDirection.rtl,
            child: PinPad(onDigit: digits.add, onBackspace: () {}),
          ),
        ),
      );
      await pumpQuietly(tester);

      // مواضع أزرار الأرقام داخل PinPad نفسه.
      final one = find.text('1');
      final three = find.text('3');
      expect(one, findsOneWidget);
      expect(three, findsOneWidget);
      final oneDx = tester.getTopLeft(one).dx;
      final threeDx = tester.getTopLeft(three).dx;
      expect(
        oneDx < threeDx,
        isTrue,
        reason: 'الرقم 1 يجب أن يكون يسار 3 مادياً (لوحة LTR داخل RTL)',
      );
    });

    testWidgets('الأزرار 0-9 والرجوع تستدعي الاستدعاءات', (tester) async {
      final digits = <int>[];
      var backspaces = 0;
      await tester.pumpWidget(
        wrapWithL10n(
          PinPad(onDigit: digits.add, onBackspace: () => backspaces++),
        ),
      );
      await pumpQuietly(tester);

      for (final d in ['5', '0', '9']) {
        await tester.tap(find.text(d).first);
        await pumpQuietly(tester, 3);
      }
      expect(digits, [5, 0, 9]);
      // زر المسح (أيقونة backspace).
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await pumpQuietly(tester, 3);
      expect(backspaces, 1);
    });
  });

  group('AmountText — تنسيق موحد DS-18', () {
    testWidgets('افتراضي غربي بفواصل آلاف وعلامة غير لونية', (tester) async {
      await tester.pumpWidget(
        wrapWithL10n(
          const AmountText(
            amount: 1234.5,
            sign: FinSign.incoming,
            size: AmountSize.large,
          ),
        ),
      );
      await pumpQuietly(tester);
      expect(find.textContaining('1,234.50'), findsOneWidget);
      expect(find.textContaining('+'), findsOneWidget,
          reason: 'العلامة غير اللونية إلزامية');
    });

    testWidgets('نظام الأرقام الشرقي عبر NumeralsScope ينعكس فوراً', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithL10n(
          NumeralsScope(
            arabicIndic: true,
            child: const AmountText(
              amount: 1234.5,
              sign: FinSign.outgoing,
            ),
          ),
        ),
      );
      await pumpQuietly(tester);
      expect(find.textContaining('١٬٢٣٤٫٥٠'), findsOneWidget);
      expect(find.textContaining('−'), findsOneWidget);
    });

    testWidgets('YER بلا كسور (decimals=0)', (tester) async {
      await tester.pumpWidget(
        wrapWithL10n(
          const AmountText(amount: 12500, decimals: 0),
        ),
      );
      await pumpQuietly(tester);
      expect(find.textContaining('12,500'), findsOneWidget);
      expect(find.textContaining('12,500.00'), findsNothing);
    });
  });

  group('NumeralsScope — البث الافتراضي', () {
    testWidgets('غياب النطاق = غربي (الافتراض الآمن)', (tester) async {
      late bool captured;
      await tester.pumpWidget(
        wrapWithL10n(
          Builder(
            builder: (context) {
              captured = NumeralsScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(captured, isFalse);
    });

    testWidgets('التغيير يعيد البناء بقيمة جديدة', (tester) async {
      await tester.pumpWidget(
        wrapWithL10n(
          const NumeralsScope(arabicIndic: false, child: SizedBox()),
        ),
      );
      await tester.pumpWidget(
        wrapWithL10n(
          const NumeralsScope(arabicIndic: true, child: SizedBox()),
        ),
      );
      await pumpQuietly(tester, 2);
      expect(NumeralsScope.of(tester.element(find.byType(SizedBox))), isTrue);
    });
  });
}
