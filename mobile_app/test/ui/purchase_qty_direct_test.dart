/// اختبارات R17-a بمسار الشراء — «كتابة/تعديل كميات الأصناف مباشرة عند
/// إنشاء الفواتير»: قيمة الكمية داخل [PurchaseQtyStepper] تصبح زراً
/// قابلاً للنقر (`purchase_line_qty_value`) يفتح المحرر الرقمي السريع
/// (showPurchaseNumberEditSheet) — نقرة واحدة + كتابة (7 أو 2.5) بدل
/// الاعتماد على زرَّي ± حصراً. مرآة اختبارات البيع
/// (sell_cart_qty_direct_test) باتجاه الشراء.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/exchange_rate_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/purchase_repository.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/router/app_router.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/purchases/view_models/purchase_cart_session.dart';
import 'package:mobile_app/ui/features/purchases/view_models/purchase_cart_view_model.dart';
import 'package:mobile_app/ui/features/purchases/views/widgets/purchase_widgets.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  final at = DateTime.utc(2026, 10, 6, 12);

  late AppDatabase handle;
  late ItemRepository items;
  late CompanyRepository companies;
  late ExchangeRateRepository fx;
  late PurchaseRepository purchases;
  late int warehouseId;
  late int userId;
  late int baseId;

  bool dbOpen = false;

  Future<void> openDb() async {
    if (dbOpen) return;
    final seeded = await openSeededApp();
    handle = seeded.$1;
    items = ItemRepository(handle.db);
    companies = seeded.$2;
    fx = ExchangeRateRepository(handle.db);
    purchases = PurchaseRepository(handle.db);
    userId = (await companies.findAdminUserId())!;
    warehouseId = (await companies.findDefaultWarehouseId())!;
    baseId = (await companies.listActiveCurrencies())
        .firstWhere((c) => c.isBase)
        .id;
    addTearDown(() async {
      dbOpen = false;
      await handle.close();
    });
    dbOpen = true;
  }

  /// صنف مخزون (تكلفة 60، متاح 4) يضاف لفاتورة الشراء الحية.
  Future<void> addStockedItem(PurchaseCartViewModel vm) async {
    final created = await items.createItem(
      ItemDraft(
        name: 'صنف شراء الكمية المباشرة',
        costPrice: 60,
        openingQty: 4,
        prices: [ItemPrice(currencyId: baseId, price: 120)],
      ),
      warehouseId: warehouseId,
      userId: userId,
      now: at,
    );
    final all = await items.searchItems('');
    final info = all.firstWhere((i) => i.item.id == created.valueOrNull!);
    vm.addItemFromInfo(info);
  }

  /// يبني التطبيق كاملاً (راوتر + جلسة مفتوحة) ويعيد الراوتر ونموذج الفاتورة.
  Future<(GoRouter, PurchaseCartViewModel)> bootApp(WidgetTester tester) async {
    final controller = AppController(forTesting: handle);
    await controller.decidePhaseForTest();
    controller.unlockSession();
    addTearDown(controller.dispose);

    final router = buildAppRouter(controller);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await pumpQuietly(tester, 8);

    final vm = purchaseCartSession.attach(
      companyRepo: companies,
      fxRepo: fx,
      purchaseRepo: purchases,
      database: handle.db,
    );
    await vm.load();
    await addStockedItem(vm);
    return (router, vm);
  }

  group('فاتورة الشراء — نقرة قيمة الكمية → كتابة مباشرة (R17-a)', () {
    testWidgets('نقرة القيمة تفتح المحرر الرقمي؛ كتابة 7 وتأكيد → كمية السطر 7 '
        'وأزرار ± باقية لم تُمسّ', (tester) async {
      // 600dp (لا 390): شريط فاتورة الشراء السفلي يفيض بخط الاختبار
      // الافتراضي الأعرض من خطوط الإنتاج (علة قائمة بلا علاقة بكمية
      // R17-a — لا اختبار شاشة شراء سابقاً يكشفها)؛ سلوك الكمية نفسه
      // مستقل عن العرض.
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        purchaseCartSession.reset();
        addTearDown(purchaseCartSession.reset);
        await openDb();

        final (router, vm) = await bootApp(tester);
        router.go('/purchases/new');
        await pumpQuietly(tester, 10);

        // القيمة نفسها صارت هدفاً قابلاً للنقر — وزرّا ± كما هما.
        final valueTap = find.byKey(const Key('purchase_line_qty_value'));
        expect(valueTap, findsOneWidget);
        expect(vm.state.lines.single.qty, 1);

        await tester.tap(valueTap);
        await pumpQuietly(tester, 6);

        // النافذة السفلية ظهرت بعنوان «تعديل الكمية» ومعها حقل واحد.
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(
          find.text('تعديل الكمية: صنف شراء الكمية المباشرة'),
          findsOneWidget,
        );
        final field = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        );
        expect(field, findsOneWidget);

        await tester.enterText(field, '7');
        await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
        await pumpQuietly(tester, 12);

        // الكمية صارت 7 بالسطر وبالعرض — والصافي 7 × 60 = 420.
        expect(vm.state.lines.single.qty, 7);
        expect(
          find.descendant(of: valueTap, matching: find.text('7')),
          findsOneWidget,
          reason: 'قيمة السطر تعرض 7 بعد الكتابة المباشرة',
        );
        expect(vm.state.lines.single.unitCost, 60);
        expect(vm.grandTotal, 420, reason: '7 × 60 — التسعير سليم');

        // أزرار ± تعمل بعد التحرير المباشر (كمية 7 → 6 بنقرة −).
        await tester.tap(
          find.descendant(
            of: find.byType(PurchaseQtyStepper),
            matching: find.byIcon(Icons.remove_rounded),
          ),
        );
        await pumpQuietly(tester, 6);
        expect(vm.state.lines.single.qty, 6);

        router.dispose();
        vm.dispose();
      });
    });

    testWidgets('كسر عشري (2.5) مقبول، والإلغاء لا يمسّ السطر، والصفر يرفض '
        'داخل النافذة (allowZero=false)', (tester) async {
      // 600dp — نفس ملاحظة الاختبار الأول (فيض شريط سفلي قائم بخط
      // الاختبار، لا علاقة له بميزة الكمية).
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        purchaseCartSession.reset();
        addTearDown(purchaseCartSession.reset);
        await openDb();

        final (router, vm) = await bootApp(tester);
        router.go('/purchases/new');
        await pumpQuietly(tester, 10);

        final valueTap = find.byKey(const Key('purchase_line_qty_value'));

        // ── كسر عشري: 2.5 (تقليم الأصفار يعرضها «2.5» لا «2.500») ───
        await tester.tap(valueTap);
        await pumpQuietly(tester, 6);
        final field = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        );
        await tester.enterText(field, '2.5');
        await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
        await pumpQuietly(tester, 12);
        expect(vm.state.lines.single.qty, 2.5);
        expect(
          find.descendant(of: valueTap, matching: find.text('2.5')),
          findsOneWidget,
        );

        // ── إلغاء: السطر باقٍ على 2.5 ─────────────────────────────
        await tester.tap(valueTap);
        await pumpQuietly(tester, 6);
        await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
        await pumpQuietly(tester, 8);
        expect(vm.state.lines.single.qty, 2.5);

        // ── صفر: يرفض داخل النافذة (رسالة خطأ) ولا يصل setQty ────
        await tester.tap(valueTap);
        await pumpQuietly(tester, 6);
        expect(find.byType(BottomSheet), findsOneWidget);
        await tester.enterText(field, '0');
        await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
        await pumpQuietly(tester, 6);
        expect(
          find.byType(BottomSheet),
          findsOneWidget,
          reason: 'الصفر مرفوض — النافذة تبقى مفتوحة برسالة',
        );
        expect(find.text('أدخل رقماً صالحاً.'), findsOneWidget);
        expect(vm.state.lines.single.qty, 2.5);

        router.dispose();
        vm.dispose();
      });
    });
  });
}
