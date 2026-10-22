/// اختبارات عدة حقول نماذج SIM (V10-0) — تثبت الهوية البصرية للعدة
/// الأساسية قبل تحويل الشاشتين: البطاقة، الحقل السطري بنجمته،
/// الصندوقي بحدوده، صف المفتاح، وشريط الحفظ الثابت بحالاته.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/ui/core/widgets/sim_form_widgets.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ar'),
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('SimFormLineField — تلميح بنجمة الإلزام وسطر سفلي', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(
      SimFormLineField(hint: 'اسم المنتج', controller: controller, required: true),
    ));
    expect(find.text('اسم المنتج *'), findsOneWidget);
    // InputDecoration بحد سفلي (UnderlineInputBorder) لا صندوقي.
    final decoration = tester.widget<TextField>(
      find.byType(TextField),
    ).decoration!;
    expect(decoration.enabledBorder, isA<UnderlineInputBorder>());
  });

  testWidgets('SimFormBoxField — تلميح وحد صندوقي رباعي', (tester) async {
    await tester.pumpWidget(
      _wrap(const SimFormBoxField(hint: 'سعر البيع', keyboardType: TextInputType.number)),
    );
    expect(find.text('سعر البيع'), findsOneWidget);
    final decoration = tester.widget<TextField>(
      find.byType(TextField),
    ).decoration!;
    expect(decoration.enabledBorder, isA<OutlineInputBorder>());
  });

  testWidgets('SimFormBoxRow — حقلان متجاوران بفاصل', (tester) async {
    await tester.pumpWidget(_wrap(
      const SimFormBoxRow(
        start: SimFormBoxField(hint: 'سعر البيع'),
        end: SimFormBoxField(hint: 'فتح الأسهم'),
      ),
    ));
    expect(find.text('سعر البيع'), findsOneWidget);
    expect(find.text('فتح الأسهم'), findsOneWidget);
    expect(find.byType(Row), findsOneWidget);
  });

  testWidgets('SimFormSwitchRow — تسمية ومفتاح والنقر يبدل', (tester) async {
    var value = false;
    await tester.pumpWidget(_wrap(
      StatefulBuilder(
        builder: (_, setState) => SimFormSwitchRow(
          label: 'تمكين جرد المنتج',
          value: value,
          onChanged: (v) => setState(() => value = v),
        ),
      ),
    ));
    expect(find.text('تمكين جرد المنتج'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('SimFormSaveBar — تسمية وحالات التحميل والتعطيل', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(_wrap(
      SimFormSaveBar(label: 'حفظ المنتج', onPressed: () => pressed++),
    ));
    expect(find.text('حفظ المنتج'), findsOneWidget);
    await tester.tap(find.text('حفظ المنتج'));
    expect(pressed, 1);

    // معطّل: لا استجابة.
    await tester.pumpWidget(_wrap(
      SimFormSaveBar(label: 'حفظ المنتج', onPressed: () => pressed++, enabled: false),
    ));
    await tester.tap(find.text('حفظ المنتج'), warnIfMissed: false);
    expect(pressed, 1);

    // تحميل: مؤشر انتظار ولا استجابة.
    await tester.pumpWidget(_wrap(
      SimFormSaveBar(label: 'حفظ المنتج', onPressed: () => pressed++, loading: true),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('حفظ المنتج'), warnIfMissed: false);
    expect(pressed, 1);
  });

  testWidgets('SimFormCard — بطاقة بحواف مستديرة تحوي حقلاً', (tester) async {
    await tester.pumpWidget(_wrap(
      const SimFormCard(child: SimFormLineField(hint: 'الاسم الكامل')),
    ));
    expect(find.text('الاسم الكامل'), findsOneWidget);
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(12));
  });
}
