/// اختبارات ويدجت شاشات المخزن (المرحلة 2): الواجهة الرئيسية بالعدّادات،
/// قائمة الأصناف مع البحث الفوري، نموذج الصنف (تحقق + توليد باركود +
/// صنف خدمي)، تفاصيل الصنف بالدفعات، أصناف تنفذ قريباً، ومسار الاستيراد
/// الكامل (لصق CSV ← تحليل ← فشل بأسبابه ← إقرار AC-14 ← السليمة فقط).
///
/// نمط القيادة: طبقات البيانات FFI لا تتقدم داخل منطقة الاختبار الوهمية
/// إلا عبر `tester.runAsync` — لذا تُحمَّل النماذج مسبقاً (seam) وتُستدعى
/// عملياتها غير المتزامنة داخل runAsync مباشرة، بينما تُختبر النقرات
/// المتزامنة (مفاتيح/تحقق) من الواجهة. سطح الاختبار طويل (390×1600)
/// لأن عناصر ListView خارج الشاشة لا تُبنى فلا يجدها الباحث.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/repositories/batch_repository.dart';
import 'package:mobile_app/data/repositories/company_repository.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/data/services/item_import_service.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/features/inventory/view_models/import_view_model.dart';
import 'package:mobile_app/ui/features/inventory/view_models/inventory_home_view_model.dart';
import 'package:mobile_app/ui/features/inventory/view_models/item_detail_view_model.dart';
import 'package:mobile_app/ui/features/inventory/view_models/item_form_view_model.dart';
import 'package:mobile_app/ui/features/inventory/view_models/item_list_view_model.dart';
import 'package:mobile_app/ui/features/inventory/view_models/low_stock_view_model.dart';
import 'package:mobile_app/ui/features/inventory/views/import_screen.dart';
import 'package:mobile_app/ui/features/inventory/views/inventory_home_screen.dart';
import 'package:mobile_app/ui/features/inventory/views/item_detail_screen.dart';
import 'package:mobile_app/ui/features/inventory/views/item_form_screen.dart';
import 'package:mobile_app/ui/features/inventory/views/items_list_screen.dart';
import 'package:mobile_app/ui/features/inventory/views/low_stock_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

/// آخر AppController جاهز — يُنشأ داخل runAsync قبل pumpWidget.
AppController? _app;

/// بذرة أصناف قياسية: زيت (طبيعي بكمية 20) وسكر (تحت الحد: كمية 2/حد 5).
Future<void> _seedItems() async {
  final items = ItemRepository(_app!.database!.db);
  final warehouseId = await _app!.companies!.findDefaultWarehouseId() ?? 1;
  final userId = await _app!.companies!.findAdminUserId() ?? 1;
  final now = DateTime.utc(2026, 10, 6, 12);

  await items.createItem(
    ItemDraft(
      name: 'زيت دوار الشمس 1.8ل',
      costPrice: 2200,
      minStock: 5,
      openingQty: 20,
      prices: const [],
    ),
    warehouseId: warehouseId,
    userId: userId,
    now: now,
  );
  await items.createItem(
    ItemDraft(
      name: 'سكر ناعم 1كج',
      costPrice: 900,
      minStock: 5,
      openingQty: 2,
      prices: const [],
    ),
    warehouseId: warehouseId,
    userId: userId,
    now: now,
  );
}

/// يفتح قاعدة مؤسّسة ويحضّر الجلسة — يعيد المستودعات الثلاثة للـ seam.
Future<T> _withReadyApp<T>(
  Future<T> Function(
    ItemRepository items,
    BatchRepository batches,
    CompanyRepository companies,
  )
  body,
) async {
  final seeded = await openSeededApp();
  addTearDown(seeded.$1.close);
  final controller = AppController(forTesting: seeded.$1);
  await controller.decidePhaseForTest();
  controller.unlockSession();
  _app = controller;
  return body(
    ItemRepository(seeded.$1.db),
    BatchRepository(seeded.$1.db),
    seeded.$2,
  );
}

/// سطح هاتف طويل (1600px منطقياً) + رفع الشاشة + إعادة l10n العربي.
Future<AppLocalizations> _pump(
  WidgetTester tester,
  Widget Function(AppController app) build,
) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final app = _app!;
  await tester.pumpWidget(
    ChangeNotifierProvider<AppController>.value(
      value: app,
      child: wrapWithL10n(build(app)),
    ),
  );
  await pumpQuietly(tester, 14);
  final ctx = tester.element(find.byType(Scaffold).first);
  return AppLocalizations.of(ctx)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initFfiForTests();

  group('InventoryHomeScreen — واجهة المخزن بالعدّادات', () {
    testWidgets('تعرض البطاقات الست مع عدّاد تنبيه المخزون = 1', (
      tester,
    ) async {
      late final InventoryHomeViewModel vm;
      await tester.runAsync(() async {
        await _withReadyApp((items, batches, companies) async {
          await _seedItems();
          vm = InventoryHomeViewModel(itemRepo: items, batchRepo: batches);
          await vm.load();
        });
      });
      final l10n = await _pump(
        tester,
        (_) => InventoryHomeScreen(viewModel: vm),
      );

      expect(find.text(l10n.inventoryHomeHeroTitle), findsOneWidget);
      expect(find.text(l10n.inventoryHubItems), findsOneWidget);
      expect(find.text(l10n.inventoryHubLowStock), findsOneWidget);
      expect(find.text(l10n.inventoryHubBatches), findsOneWidget);
      expect(find.text(l10n.inventoryHubImport), findsOneWidget);
      expect(find.text(l10n.inventoryHubCategoriesUnits), findsOneWidget);
      // سكر (كمية 2 ≤ حد 5) — عدّاد التنبيه 1.
      expect(find.text('1'), findsWidgets);
    });
  });

  group('ItemsListScreen — القائمة والبحث الفوري', () {
    testWidgets('يعرض الصنفين ثم «زيت» يبقي واحداً', (tester) async {
      late final ItemListViewModel vm;
      await tester.runAsync(() async {
        await _withReadyApp((items, batches, companies) async {
          await _seedItems();
          vm = ItemListViewModel(itemRepo: items, companyRepo: companies);
          await vm.load();
          expect(vm.state.items, hasLength(2), reason: 'البذر قبل العرض');
        });
      });
      await _pump(tester, (_) => ItemsListScreen(viewModel: vm));

      expect(find.text('زيت دوار الشمس 1.8ل'), findsOneWidget);
      expect(find.text('سكر ناعم 1كج'), findsOneWidget);

      // البحث: الكتابة واجهةً (لا DB فيها) ثم التثبيت الفوري للنموذج
      // داخل runAsync — التأجيل 200ms خاص بالإنتاج ولا يتقدم في المنطقة
      // الوهمية إلا بضخات وهمية غير قادرة على FFI.
      await tester.enterText(
        find.byKey(const Key('items_search_field')),
        'زيت',
      );
      await tester.runAsync(() async => await vm.setQuery('زيت'));
      await pumpQuietly(tester, 10);

      expect(find.text('زيت دوار الشمس 1.8ل'), findsOneWidget);
      expect(find.text('سكر ناعم 1كج'), findsNothing);
    });
  });

  group('ItemFormScreen — التحقق والتوليد والخدمي', () {
    testWidgets('اسم فارغ ← خطأ؛ توليد EAN-13؛ الخدمي يخفي الكمية الافتتاحية', (
      tester,
    ) async {
      late final ItemFormViewModel vm;
      await tester.runAsync(() async {
        await _withReadyApp((items, batches, companies) async {
          vm = ItemFormViewModel(itemRepo: items, companyRepo: companies);
          await vm.load();
        });
      });
      final l10n = await _pump(tester, (_) => ItemFormScreen(viewModel: vm));

      // 1) الاسم إلزامي (تحقق متزامن من الواجهة).
      await tester.ensureVisible(find.byKey(const Key('item_form_save_btn')));
      await tester.tap(find.byKey(const Key('item_form_save_btn')));
      await pumpQuietly(tester, 8);
      expect(find.text(l10n.itemFormNameRequired), findsOneWidget);

      // 2) توليد باركود EAN-13 — 13 رقماً داخل الحقل (متزامن).
      await tester.enterText(
        find.byKey(const Key('item_form_name_field')),
        'منظف أرضيات',
      );
      await pumpQuietly(tester, 4);
      await tester.ensureVisible(
        find.byKey(const Key('item_form_generate_btn')),
      );
      await tester.tap(find.byKey(const Key('item_form_generate_btn')));
      await pumpQuietly(tester, 6);
      final field = tester.widget<TextFormField>(
        find.byKey(const Key('item_form_barcode_field')),
      );
      final code = field.controller?.text ?? '';
      expect(code.length, 13);
      expect(int.tryParse(code), isNotNull);

      // 3) الصنف الخدمي يخفي حقل الكمية الافتتاحية (تبديل متزامن).
      expect(
        find.byKey(const Key('item_form_opening_qty_field')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('item_form_service_switch')),
      );
      await tester.tap(find.byKey(const Key('item_form_service_switch')));
      await pumpQuietly(tester, 6);
      expect(
        find.byKey(const Key('item_form_opening_qty_field')),
        findsNothing,
      );
    });
  });

  group('ItemDetailScreen — الأسعار والمخزون والدفعات', () {
    testWidgets('يعرض الرصيد وقسم الدفعات برقم الدفعة', (tester) async {
      late final ItemDetailViewModel vm;
      late final int itemId;
      await tester.runAsync(() async {
        await _withReadyApp((items, batches, companies) async {
          final created = await items.createItem(
            ItemDraft(
              name: 'لبن المراعي 1ل',
              costPrice: 700,
              minStock: 4,
              openingQty: 12,
              trackBatches: true,
              prices: const [],
            ),
            warehouseId: await companies.findDefaultWarehouseId() ?? 1,
            userId: await companies.findAdminUserId() ?? 1,
            now: DateTime.utc(2026, 10, 6, 12),
          );
          itemId = created.valueOrNull!;
          await batches.createBatch(
            productId: itemId,
            warehouseId: await companies.findDefaultWarehouseId() ?? 1,
            batchNumber: 'L232',
            expiryDate: DateTime.utc(2026, 11, 1),
            qty: 12,
            costPrice: 700,
            now: DateTime.utc(2026, 10, 6, 12),
          );
          vm = ItemDetailViewModel(
            itemRepo: items,
            batchRepo: batches,
            companyRepo: companies,
            itemId: itemId,
          );
          await vm.load();
        });
      });
      final l10n = await _pump(
        tester,
        (_) => ItemDetailScreen(viewModel: vm, itemId: itemId),
      );

      expect(find.text('لبن المراعي 1ل'), findsOneWidget);
      expect(find.text(l10n.itemDetailStockSection), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(l10n.itemDetailBatchesSection),
        200,
      );
      expect(find.text('L232'), findsOneWidget);
    });
  });

  group('LowStockScreen — الحد الأدنى والبحث', () {
    testWidgets('سكر تحت الحد يظهر؛ العتبة 1 تُظهر حالة الفراغ', (
      tester,
    ) async {
      late final LowStockViewModel vm;
      await tester.runAsync(() async {
        await _withReadyApp((items, batches, companies) async {
          await _seedItems();
          vm = LowStockViewModel(itemRepo: items);
          await vm.load();
          expect(vm.state.items, hasLength(1), reason: 'سكر فقط تحت الحد');
        });
      });
      final l10n = await _pump(tester, (_) => LowStockScreen(viewModel: vm));

      expect(find.text('سكر ناعم 1كج'), findsOneWidget);
      expect(find.text('زيت دوار الشمس 1.8ل'), findsNothing);

      // العتبة: كتابة واجهةً ثم التثبيت الفوري (التأجيل 300ms إنتاجي فقط).
      await tester.enterText(
        find.byKey(const Key('low_stock_threshold_field')),
        '1',
      );
      await tester.runAsync(() async => await vm.setThreshold(1));
      await pumpQuietly(tester, 10);

      expect(find.text(l10n.lowStockEmptyTitle), findsOneWidget);
    });
  });

  group('ImportScreen — مسار الاستيراد الكامل (AC-14)', () {
    testWidgets(
      'لصق CSV ← تحليل ← صف فاشل ← الالتزام معطّل حتى الإقرار ← السليمة فقط',
      (tester) async {
        late final ImportViewModel vm;
        await tester.runAsync(() async {
          await _withReadyApp((items, batches, companies) async {
            vm = ImportViewModel(
              importService: ItemImportService(_app!.database!.db),
              companyRepo: companies,
            );
            await vm.load();
          });
        });
        await _pump(tester, (_) => ImportScreen(viewModel: vm));

        // 1) وضع اللصق: صفان سليمان + صف بلا اسم — الكتابة واجهةً
        //    (متزامنة) ثم تثبيت النص في النموذج داخل runAsync.
        const csv =
            'الاسم,الباركود,سعر التكلفة,الكمية\n'
            'شامبو هيد آند شولدرز,,1500,10\n'
            'معجون سجنال,,800,6\n'
            ',,100,3';
        await tester.enterText(find.byKey(const Key('import_csv_field')), csv);
        await tester.runAsync(() async => vm.setPasteText(csv));
        await pumpQuietly(tester, 6);

        // 2) متابعة ← الربط (الاسم يتخمَّن تلقائياً للعمود A).
        await tester.runAsync(() async => vm.prepareMapping());
        await pumpQuietly(tester, 10);
        expect(find.byKey(const Key('import_analyze_btn')), findsOneWidget);

        // 3) تحليل ← معاينة بصف فاشل واحد (FFI داخل runAsync).
        await tester.runAsync(() async => await vm.analyze());
        await pumpQuietly(tester, 10);
        expect(vm.state.stage, ImportStage.preview);

        // 4) الالتزام معطّل قبل الإقرار (AC-14) + الصف الفاشل موصوف.
        await tester.runAsync(() async {
          expect(vm.state.canCommit, isFalse);
          expect(vm.state.preview, isNotNull);
          expect(vm.state.preview!.failedRows, hasLength(1));
          expect(vm.state.preview!.validRows, hasLength(2));
        });

        // 5) الإقرار (نقرة متزامنة) ← تمكين ← التزام ناجح.
        await tester.ensureVisible(
          find.byKey(const Key('import_ack_checkbox')),
        );
        await tester.tap(find.byKey(const Key('import_ack_checkbox')));
        await pumpQuietly(tester, 6);
        await tester.runAsync(() async {
          expect(vm.state.canCommit, isTrue);
          expect(await vm.commit(), isTrue);
        });
        await pumpQuietly(tester, 10);

        // 6) أُدخل السليمان فقط — كلاهما موجودان بالبحث الدقيق.
        await tester.runAsync(() async {
          final shampoo = await _app!.items!.searchItems('شامبو');
          expect(shampoo, hasLength(1));
          final paste = await _app!.items!.searchItems('معجون');
          expect(paste, hasLength(1));
        });
      },
    );
  });
}
