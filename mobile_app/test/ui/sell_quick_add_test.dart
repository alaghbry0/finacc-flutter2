/// اختبارات «إضافة بند» السريعة داخل الفاتورة (V10) — قيادة بقاعدة
/// حقيقية مزروعة وفق النمط المعتمد (openSeededApp):
///
/// 1. حالة السلة: تسجيل العابرة + التفريغ بعد الترحيل.
/// 2. المساعد: صنف خدمي بسعر العملة النشطة + تسجيل عند إلغاء الحفظ
///    وعدمه عند التعليم.
/// 3. الأرشفة بعد الترحيل حصراً (نقد 🔴-1): العابر يُؤرشف بعد نجاح
///    postSale والمحفوظ يبقى بالقوائم.
/// 4. النافذة: التحقق (اسم/سعر) + مربع الحفظ وتلميح العابر + الخطأ
///    يظهر داخلها + النجاح يغلقها.
/// 5. بطاقة «صنف جديد» بالمنتقي: أول الشبكة عند توفر onQuickAdd،
///    غيابها بدونه، وtap تمرر نص البحث وتغلق بالسطر المضاف.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:sqflite/sqflite.dart' show Database;
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/exchange_rate_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/repositories/quotation_repository.dart';
import 'package:mobile_app/data/repositories/sale_repository.dart';
import 'package:mobile_app/data/repositories/settings_repository.dart';
import 'package:mobile_app/domain/core/result.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/domain/models/sale.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/sell/view_models/sell_cart_view_model.dart';
import 'package:mobile_app/ui/features/sell/views/widgets/item_picker_sheet.dart';
import 'package:mobile_app/ui/features/sell/views/widgets/sell_checkout_helpers.dart';
import 'package:mobile_app/ui/features/sell/views/widgets/sim_quick_add_dialog.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  final at = DateTime.utc(2026, 10, 8, 9);

  late AppDatabase handle;
  late CompanyRepository companies;
  late ItemRepository items;
  late ExchangeRateRepository fx;
  late SaleRepository sales;
  late QuotationRepository quotations;
  late SettingsRepository settings;
  late int baseId;

  Future<void> open() async {
    final seeded = await openSeededApp();
    handle = seeded.$1;
    companies = seeded.$2;
    items = ItemRepository(handle.db);
    fx = ExchangeRateRepository(handle.db);
    sales = SaleRepository(handle.db);
    quotations = QuotationRepository(handle.db);
    settings = SettingsRepository(handle.db);
    final currencies = await companies.listActiveCurrencies();
    baseId = currencies.firstWhere((c) => c.isBase).id;
    addTearDown(handle.close);
  }

  SellCartViewModel buildVm() => SellCartViewModel(
        itemRepo: items,
        companyRepo: companies,
        fxRepo: fx,
        saleRepo: sales,
        quotationRepo: quotations,
        database: handle.db,
        settingsRepo: settings,
        clock: () => at,
      );

  group('حالة السلة — تسجيل العابرة (V10)', () {
    test('registerOneOff يضيف بلا تكرار ويُفرَّغ بعد الترحيل الناجح',
        () async {
      await open();
      final vm = buildVm();
      await vm.load();

      expect(vm.state.oneOffItemIds, isEmpty);
      vm.registerOneOff(41);
      vm.registerOneOff(41);
      vm.registerOneOff(42);
      expect(vm.state.oneOffItemIds, {41, 42});

      // ترحيل فاتورة تحمل عابرًا حقيقيًا — نجاح = تفريغ + أرشفة.
      final app = _FakeApp(items: items, companies: companies);
      final created = await createQuickSellItem(
        app,
        vm,
        'توصيل مستعجل',
        1500,
        saveToProducts: false,
      );
      expect(created.isOk, isTrue, reason: created.errorOrNull ?? '');
      vm.addItemFromInfo(created.valueOrNull!);
      expect(vm.state.lines, hasLength(1));
      final posted = await vm.postSale(
        paidCash: 1500,
        method: SalePaymentMethod.cash,
      );
      expect(posted.isOk, isTrue, reason: posted.errorOrNull ?? '');
      expect(vm.state.lines, isEmpty);
      expect(vm.state.oneOffItemIds, isEmpty);
      // أرشفة best-effort غير متزامنة — نمنحها دورة أحداث كاملة.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final archivedId = created.valueOrNull!.item.id;
      final rows = await handle.db.query(
        'product',
        where: 'id = ?',
        whereArgs: [archivedId],
        columns: ['is_archived'],
      );
      expect(
        (rows.first['is_archived'] as int? ?? 0) == 1,
        isTrue,
        reason: 'العابر #$archivedId يجب أن يؤرشف بعد الترحيل',
      );
    });
  });

  group('المساعد createQuickSellItem (V10 — نقد 🔴-2)', () {
    test('صنف خدمي دائمًا بسعر العملة النشطة — المحفوظ لا يُسجَّل عابرًا',
        () async {
      await open();
      final vm = buildVm();
      await vm.load();
      expect(vm.state.currencyId, baseId);

      final app = _FakeApp(items: items, companies: companies);
      final saved = await createQuickSellItem(
        app,
        vm,
        'تركيب شبكة',
        4500,
        saveToProducts: true,
      );
      expect(saved.isOk, isTrue, reason: saved.errorOrNull ?? '');
      final info = saved.valueOrNull!;
      expect(info.item.isService, isTrue);
      expect(info.retailPrice, 4500);
      expect(vm.state.oneOffItemIds, isEmpty,
          reason: 'المحفوظ لا يُسجل عابرًا');

      // السعر مخزن بعملة السلة.
      final detail = await items.detail(info.item.id);
      expect(detail, isNotNull);
      final basePrice = detail!.prices
          .firstWhere((p) => p.currencyId == baseId)
          .price;
      expect(basePrice, 4500);

      // غير المحفوظ يُسجَّل عابرًا.
      final oneOff = await createQuickSellItem(
        app,
        vm,
        'قرطاس خاص',
        300,
        saveToProducts: false,
      );
      expect(oneOff.isOk, isTrue, reason: oneOff.errorOrNull ?? '');
      expect(vm.state.oneOffItemIds, {oneOff.valueOrNull!.item.id});
    });

    test('الاسم الفارغ يرفضه createItem برسالة عربية', () async {
      await open();
      final vm = buildVm();
      await vm.load();
      final app = _FakeApp(items: items, companies: companies);
      final result = await createQuickSellItem(
        app,
        vm,
        '   ',
        100,
        saveToProducts: true,
      );
      expect(result.isErr, isTrue);
      expect(result.errorOrNull, contains('اسم الصنف'));
    });
  });

  group('نافذة «إضافة بند» (V10)', () {
    Future<void> pumpDialog(
      WidgetTester tester, {
      QuickAddItemCreator? onCreate,
      String initialName = '',
    }) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showQuickAddItemDialog(
                  context,
                  initialName: initialName,
                  onCreate:
                      onCreate ?? (_, _, _) async => const Err('خلل'),
                ),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();
    }

    testWidgets('البنية: العنوان والحقول ومربع الحفظ والأزرار والاسم المحقون',
        (tester) async {
      await pumpDialog(tester, initialName: 'قهوة سريعة');
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      expect(find.text(l10n.sellQuickAddTitle), findsOneWidget);
      expect(find.byKey(const Key('quick_add_name_field')), findsOneWidget);
      expect(find.byKey(const Key('quick_add_price_field')), findsOneWidget);
      expect(find.byKey(const Key('quick_add_save_toggle')), findsOneWidget);
      expect(find.text(l10n.commonCancel), findsOneWidget);
      expect(find.text(l10n.sellQuickAddContinue), findsOneWidget);
      expect(
        tester.widget<TextFormField>(
          find.byKey(const Key('quick_add_name_field')),
        ).initialValue,
        'قهوة سريعة',
      );
    });

    testWidgets('إلغاء التعليم يظهر تلميح العابر ويعيده بالتعليم',
        (tester) async {
      await pumpDialog(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      expect(find.text(l10n.sellQuickAddOneOffHint), findsNothing);
      await tester.tap(find.byKey(const Key('quick_add_save_toggle')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.sellQuickAddOneOffHint), findsOneWidget);
      await tester.tap(find.byKey(const Key('quick_add_save_toggle')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.sellQuickAddOneOffHint), findsNothing);
    });

    testWidgets('الاسم الفارغ → خطأ داخلي دون نداء الإنشاء', (tester) async {
      var calls = 0;
      await pumpDialog(
        tester,
        onCreate: (_, _, _) async {
          calls++;
          return const Err('لا يُستدعى');
        },
      );
      await tester.tap(find.byKey(const Key('quick_add_continue_btn')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byKey(const Key('quick_add_error_text')), findsOneWidget);
    });

    testWidgets('السعر غير الصالح → خطأ داخلي', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(
        find.byKey(const Key('quick_add_name_field')),
        'صنف تجريبي',
      );
      await tester.enterText(
        find.byKey(const Key('quick_add_price_field')),
        'abc',
      );
      await tester.tap(find.byKey(const Key('quick_add_continue_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quick_add_error_text')), findsOneWidget);
    });

    testWidgets('خطأ الإنشاء يظهر داخل النافذة ولا يغلقها', (tester) async {
      await pumpDialog(
        tester,
        onCreate: (_, _, _) async => const Err('الاسم مكرر — اختر آخر'),
      );
      await tester.enterText(
        find.byKey(const Key('quick_add_name_field')),
        'صنف موجود',
      );
      await tester.enterText(
        find.byKey(const Key('quick_add_price_field')),
        '200',
      );
      await tester.tap(find.byKey(const Key('quick_add_continue_btn')));
      await tester.pumpAndSettle();
      expect(find.text('الاسم مكرر — اختر آخر'), findsOneWidget);
      expect(find.byKey(const Key('quick_add_continue_btn')), findsOneWidget);
    });

    testWidgets('النجاح يغلق النافذة ويعيد الصنف — والإلغاء يعيد null',
        (tester) async {
      const created = ItemStockInfo(
        item: Item(id: 7, name: 'مفك خاص', isService: true),
        retailPrice: 900,
      );
      ItemStockInfo? popped;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  popped = await showQuickAddItemDialog(
                    context,
                    initialName: '',
                    onCreate: (_, _, _) async =>
                        const Ok<ItemStockInfo, String>(created),
                  );
                },
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('quick_add_name_field')),
        'مفك خاص',
      );
      await tester.enterText(
        find.byKey(const Key('quick_add_price_field')),
        '900',
      );
      await tester.tap(find.byKey(const Key('quick_add_continue_btn')));
      await tester.pumpAndSettle();
      expect(popped, isNotNull);
      expect(popped!.item.name, 'مفك خاص');

      // الإلغاء يعيد null.
      popped = null;
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(popped, isNull);
    });
  });

  group('بطاقة «صنف جديد» بالمنتقي (V10)', () {
    const stubResults = [
      ItemStockInfo(
        item: Item(id: 1, name: 'حليب بقري'),
        totalQty: 40,
        retailPrice: 200,
      ),
      ItemStockInfo(
        item: Item(id: 2, name: 'شاي أحمر'),
        totalQty: 12,
        retailPrice: 90,
      ),
    ];

    testWidgets('أول خلية عند توفر onQuickAdd وغائبة بدونه', (tester) async {
      // مستودع مسيطر عليه (نتائج ثابتة) — البطاقة أول خلية بالشبكة.
      final stub = _StubItems(List<ItemStockInfo>.of(stubResults));
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showItemPickerSheet(
                  context,
                  itemRepo: stub,
                  currencyId: 1,
                  decimals: 2,
                  currencyCode: 'YER',
                  onPick: (_) {},
                  onQuickAdd: (_) async => null,
                ),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('sell_picker_quick_add_tile')),
        findsOneWidget,
      );
      // نتائج حقيقية خلف البطاقة.
      expect(find.text('حليب بقري'), findsOneWidget);

      // غياب onQuickAdd — تُفتح نسخة بلا بطاقة (إغلاق المنتقي بزر X).
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showItemPickerSheet(
                  context,
                  itemRepo: stub,
                  currencyId: 1,
                  decimals: 2,
                  currencyCode: 'YER',
                  onPick: (_) {},
                ),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('sell_picker_quick_add_tile')),
        findsNothing,
      );
      expect(find.text('حليب بقري'), findsOneWidget);
    });

    testWidgets('الفراغ: بطاقة «صنف جديد» بديل الطريق المسدود',
        (tester) async {
      final stub = _StubItems(const <ItemStockInfo>[]);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showItemPickerSheet(
                  context,
                  itemRepo: stub,
                  currencyId: 1,
                  decimals: 2,
                  currencyCode: 'YER',
                  onPick: (_) {},
                  onQuickAdd: (_) async => null,
                ),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('sell_picker_quick_add_tile')),
        findsOneWidget,
      );
    });

    testWidgets('tap تمرر نص البحث وتغلق المنتقي بعد الإضافة', (tester) async {
      final stub = _StubItems(const <ItemStockInfo>[]);
      final picked = <ItemStockInfo>[];
      var receivedQuery = '?';
      const created = ItemStockInfo(
        item: Item(id: 99, name: 'صنف فوري', isService: true),
        retailPrice: 250,
      );
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showItemPickerSheet(
                  context,
                  itemRepo: stub,
                  currencyId: 1,
                  decimals: 2,
                  currencyCode: 'YER',
                  onPick: picked.add,
                  onQuickAdd: (query) async {
                    receivedQuery = query;
                    return created;
                  },
                ),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      // ابحث عن شيء غير موجود — يمرر النص للنافذة (المستودع المزيف
      // يرجع فراغاً دائماً فالنتائج الفارغة بلا بحث أصلًا؛ نكتب النص
      // ثم نقر البطاقة مباشرة).
      await tester.enterText(
        find.byKey(const Key('sell_picker_search_field')),
        'شيء نادر جدًا',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('sell_picker_quick_add_tile')),
      );
      await tester.pumpAndSettle();
      expect(receivedQuery, 'شيء نادر جدًا');
      expect(picked, hasLength(1));
      expect(picked.single.item.name, 'صنف فوري');
      // المنتقي أُغلق (الشاشة الابتدائية ظاهرة مجددًا).
      expect(find.text('افتح'), findsOneWidget);
      expect(find.byKey(const Key('sell_picker_grid')), findsNothing);
    });
  });

}

/// مستودع أصناف مسيطر عليه لاختبارات الودجات — بحث يعيد قائمة
/// ثابتة (لا قاعدة حقيقية داخل fake async).
class _StubItems extends ItemRepository {
  _StubItems(this._results) : super(_FakeDb());

  final List<ItemStockInfo> _results;

  @override
  Future<List<ItemStockInfo>> searchItems(
    String query, {
    int? categoryId,
    bool includeArchived = false,
    int limit = 50,
    int offset = 0,
    int? currencyIdForPrice,
  }) async => _results;
}

/// مقبض قاعدة مزيّف — يكفي البناء (لا يُستدعى بالبحث المسنود).
class _FakeDb implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// وكيل تحكم مبنى للاختبار — يوفر مستودعي الأصناف والشركات فقط
/// (كل ما يحتاجه المساعد) ويرد الباقي بـnoSuchMethod.
class _FakeApp extends ChangeNotifier implements AppController {
  _FakeApp({required this.items, required this.companies});

  @override
  final ItemRepository items;

  @override
  final CompanyRepository companies;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
