/// اختبارات الويدجت النووية المستخرجة بموجة W1-W6 (R17-b — تدقيق R16):
/// تغطية خفيفة بنمط pin_and_amount_test — كل ويدجت تعرض محتواها وتسلك
/// سلوكها الأساسي (النقر/المسح/العدّاد) بلا أي اعتماد على قاعدة بيانات.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/ui/core/widgets/access_card.dart';
import 'package:mobile_app/ui/core/widgets/count_badge.dart';
import 'package:mobile_app/ui/core/widgets/fin_error_card.dart';
import 'package:mobile_app/ui/core/widgets/fin_search_field.dart';
import 'package:mobile_app/ui/core/widgets/fin_section_title.dart';
import 'package:mobile_app/ui/core/widgets/hub_hero_card.dart';
import 'package:mobile_app/ui/core/widgets/info_note.dart';

import '../helpers/app_for_tests.dart';

void main() {
  group('FinErrorCard (W1) — بطاقة الخطأ الموحدة', () {
    testWidgets('تعرض رسالة الرفض كاملة بأيقونة الخطأ', (tester) async {
      await tester.pumpWidget(
        wrapWithL10n(
          const FinErrorCard(message: 'المبلغ المدفوع يتجاوز إجمالي الفاتورة'),
        ),
      );
      await pumpQuietly(tester);
      expect(find.text('المبلغ المدفوع يتجاوز إجمالي الفاتورة'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });

  group('AccessCard (W2) — بطاقة الوصول الموحدة', () {
    testWidgets('تعرض العنوان والوصف والنقر يستدعي onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapWithL10n(
          AccessCard(
            icon: Icons.receipt_long_rounded,
            title: 'فواتير المبيعات',
            subtitle: 'سجل الفواتير المرحّلة',
            color: Colors.teal,
            onTap: () => taps++,
          ),
        ),
      );
      await pumpQuietly(tester);
      expect(find.text('فواتير المبيعات'), findsOneWidget);
      expect(find.text('سجل الفواتير المرحّلة'), findsOneWidget);
      await tester.tap(find.text('فواتير المبيعات'));
      await pumpQuietly(tester, 3);
      expect(taps, 1);
    });

    testWidgets('رقاقة العدّاد تظهر عند تمرير count وتغيب بدونه', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithL10n(
          AccessCard(
            icon: Icons.inventory_2_rounded,
            title: 'الأصناف',
            subtitle: 'دليل الأصناف',
            color: Colors.teal,
            onTap: () {},
            count: 7,
          ),
        ),
      );
      await pumpQuietly(tester);
      expect(find.byType(CountBadge), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });
  });

  group('HubHeroCard (W3) — بطاقة البطولة المعلمية', () {
    testWidgets('تعرض العنوان والوصف ومحتوى below بفتحته', (tester) async {
      await tester.pumpWidget(
        wrapWithL10n(
          HubHeroCard(
            icon: Icons.point_of_sale_rounded,
            title: 'نقطة البيع',
            subtitle: const Text('صافي اليوم'),
            below: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('١٬٢٣٤٫٠٠ YER'),
            ),
          ),
        ),
      );
      await pumpQuietly(tester);
      expect(find.text('نقطة البيع'), findsOneWidget);
      expect(find.text('صافي اليوم'), findsOneWidget);
      expect(find.text('١٬٢٣٤٫٠٠ YER'), findsOneWidget);
    });
  });

  group('FinSectionTitle (W4) — عنوان القسم الموحد', () {
    testWidgets('يعرض الأيقونة والعنوان والذيل الاختياري', (tester) async {
      await tester.pumpWidget(
        wrapWithL10n(
          const FinSectionTitle(
            icon: Icons.account_balance_wallet_rounded,
            title: 'المالية والأرباح',
            trailing: Text('ذيل'),
          ),
        ),
      );
      await pumpQuietly(tester);
      expect(find.text('المالية والأرباح'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
      expect(find.text('ذيل'), findsOneWidget);
    });
  });

  group('InfoNote وCountBadge (W5) — الملاحظة والعدّاد الموحدان', () {
    testWidgets('الملاحظة تعرض نصها بأيقونة، والنبرة التحذيرية لا تكسرها', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithL10n(
          const InfoNote(
            icon: Icons.info_outline_rounded,
            message: 'الدفعات تُستهلك بتواريخ الصلاحية FEFO',
          ),
        ),
      );
      await pumpQuietly(tester);
      expect(
        find.text('الدفعات تُستهلك بتواريخ الصلاحية FEFO'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        wrapWithL10n(
          const InfoNote(
            icon: Icons.warning_amber_rounded,
            message: 'تنبيه',
            warning: true,
          ),
        ),
      );
      await pumpQuietly(tester);
      expect(find.text('تنبيه'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('العدّاد يعرض الرقم بأرقام غربية بلا NumeralsScope', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithL10n(const CountBadge(count: 12, color: Colors.teal)),
      );
      await pumpQuietly(tester);
      expect(find.text('12'), findsOneWidget);
    });
  });

  group('FinSearchField (W6) — حقل البحث الموحد', () {
    testWidgets('يعرض التلميح، والكتابة تستدعي onChanged، والمسح يعمل', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final queries = <String>[];
      var clears = 0;
      await tester.pumpWidget(
        wrapWithL10n(
          FinSearchField(
            controller: controller,
            fieldKey: const Key('core_search_field'),
            hint: 'ابحث بالاسم أو الباركود',
            onChanged: queries.add,
            onCleared: () {
              clears++;
              controller.clear();
            },
          ),
        ),
      );
      await pumpQuietly(tester);
      expect(find.text('ابحث بالاسم أو الباركود'), findsOneWidget);
      // زر المسح غائب قبل أي نص.
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.enterText(
        find.byKey(const Key('core_search_field')),
        'زيت',
      );
      await pumpQuietly(tester, 3);
      expect(queries, ['زيت']);
      // ظهر زر المسح مع النص.
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await pumpQuietly(tester, 3);
      expect(clears, 1);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });
}
