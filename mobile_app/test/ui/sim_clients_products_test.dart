/// اختبارات جولة V5 — شاشة العملاء والموردين بنمط Simple Invoice Manager
/// (البنية السباعية: ترويسة فرعية + بانر تعليمي + تبويبات + زر إضافة
/// أزرق + رقائق التصفية + صفوف أطراف) وشاشة المنتجات (البانر + شارة
/// الجرد + السعر بالعملة). نماذج محمّلة مسبقاً (seams) والبذر عبر FFI
/// داخل runAsync — نمط اختبارات المخزن والأطراف القائمة.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/repositories/item_repository.dart';
import 'package:mobile_app/domain/models/item.dart';
import 'package:mobile_app/domain/models/party.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/ui/core/session/app_controller.dart';
import 'package:mobile_app/ui/core/widgets/sim_list_widgets.dart';
import 'package:mobile_app/ui/features/inventory/views/items_list_screen.dart';
import 'package:mobile_app/ui/features/inventory/view_models/item_list_view_model.dart';
import 'package:mobile_app/ui/features/parties/views/sim_clients_screen.dart';
import 'package:mobile_app/ui/features/parties/view_models/party_kind.dart';
import 'package:mobile_app/ui/features/parties/view_models/party_list_view_model.dart';
import 'package:mobile_app/ui/features/parties/view_models/party_repo_gate.dart';
import 'package:provider/provider.dart';

import '../helpers/app_for_tests.dart';

AppController? _app;

final DateTime _today = DateTime.utc(2026, 10, 6, 12);

/// بذرة أصناف قياسية (نمط اختبارات المخزن): زيت وسكر بكميات.
Future<void> _seedItems() async {
  final items = ItemRepository(_app!.database!.db);
  final warehouseId = await _app!.companies!.findDefaultWarehouseId() ?? 1;
  final userId = await _app!.companies!.findAdminUserId() ?? 1;
  final now = DateTime.utc(2026, 10, 6, 12);

  await items.createItem(
    const ItemDraft(
      name: 'زيت دوار الشمس 1.8ل',
      costPrice: 2200,
      minStock: 5,
      openingQty: 20,
    ),
    warehouseId: warehouseId,
    userId: userId,
    now: now,
  );
  await items.createItem(
    const ItemDraft(
      name: 'سكر ناعم 1كج',
      costPrice: 900,
      minStock: 5,
      openingQty: 2,
    ),
    warehouseId: warehouseId,
    userId: userId,
    now: now,
  );
}

Future<void> _createCustomer(
  String name, {
  String? phone,
  double opening = 0,
}) async {
  final result = await _app!.customers!.createCustomer(
    CustomerDraft(
      name: name,
      phone: phone,
      openingBalance: opening,
      openingBalanceCurrencyId: opening == 0
          ? null
          : await _currencyId('YER'),
      openingBalanceRate: opening == 0 ? null : 1,
      openingBalanceDate: opening == 0 ? null : _today,
    ),
    userId: await _app!.companies!.findAdminUserId() ?? 1,
    now: _today,
  );
  expect(result.isOk, isTrue, reason: 'بذر عميل: $name');
}

Future<void> _createSupplier(String name, {double opening = 0}) async {
  final result = await _app!.suppliers!.createSupplier(
    SupplierDraft(
      name: name,
      openingBalance: opening,
      openingBalanceCurrencyId: opening == 0
          ? null
          : await _currencyId('YER'),
      openingBalanceRate: opening == 0 ? null : 1,
      openingBalanceDate: opening == 0 ? null : _today,
    ),
    userId: await _app!.companies!.findAdminUserId() ?? 1,
    now: _today,
  );
  expect(result.isOk, isTrue, reason: 'بذر مورد: $name');
}

Future<int> _currencyId(String code) async {
  final rows = await _app!.database!.db.query(
    'currency',
    columns: ['id'],
    where: 'code = ?',
    whereArgs: [code],
    limit: 1,
  );
  return rows.first['id'] as int;
}

/// يفتح قاعدة مؤسّسة ويحضّر الجلسة (نمط اختبارات المخزن).
Future<void> _withReadyApp() async {
  final seeded = await openSeededApp();
  addTearDown(seeded.$1.close);
  final controller = AppController(forTesting: seeded.$1);
  await controller.decidePhaseForTest();
  controller.unlockSession();
  _app = controller;
}

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

  group('SimClientsScreen — بنية شاشة العملاء SIM', () {
    testWidgets('الترويسة والبانر والتبويبات وزر الإضافة وبطاقة العميل', (
      tester,
    ) async {
      late final PartyListViewModel customerVm;
      late final PartyListViewModel supplierVm;
      await tester.runAsync(() async {
        await _withReadyApp();
        await _createCustomer(
          'عبدالله السامعي',
          phone: '777123456',
          opening: 500,
        );
        await _createSupplier('مصنع ماء فين', opening: 300);
        customerVm = PartyListViewModel(
          gate: CustomerRepoGate(_app!.customers!),
          companyRepo: _app!.companies!,
          partyKind: PartyKind.customer,
        );
        supplierVm = PartyListViewModel(
          gate: SupplierRepoGate(_app!.suppliers!),
          companyRepo: _app!.companies!,
          partyKind: PartyKind.supplier,
        );
        await customerVm.load();
        await supplierVm.load();
        expect(customerVm.state.rows, isNotEmpty, reason: 'بذر قبل العرض');
      });
      final l10n = await _pump(
        tester,
        (_) => SimClientsScreen(
          customerViewModel: customerVm,
          supplierViewModel: supplierVm,
        ),
      );

      // البنية السباعية الكاملة.
      expect(find.byType(SimSubHeader), findsOneWidget);
      expect(find.text(l10n.simClientsTitle), findsOneWidget);
      expect(find.text(l10n.simClientsTutorial), findsOneWidget);
      expect(find.text(l10n.simClientsTabClient), findsOneWidget);
      expect(find.text(l10n.simClientsTabSupplier), findsOneWidget);
      expect(find.text(l10n.simAddClientAction), findsOneWidget);

      // بطاقة العميل: الاسم والهاتف ورمز العملة.
      expect(find.text('عبدالله السامعي'), findsOneWidget);
      expect(find.text('777123456'), findsOneWidget);
      expect(find.text('YER'), findsWidgets);
    });

    testWidgets('تبديل تبويب المورد يعرض الموردين ويبدّل زر الإضافة', (
      tester,
    ) async {
      late final PartyListViewModel customerVm;
      late final PartyListViewModel supplierVm;
      await tester.runAsync(() async {
        await _withReadyApp();
        await _createCustomer('عميل أول', opening: 100);
        await _createSupplier('مورد أول', opening: 200);
        customerVm = PartyListViewModel(
          gate: CustomerRepoGate(_app!.customers!),
          companyRepo: _app!.companies!,
          partyKind: PartyKind.customer,
        );
        supplierVm = PartyListViewModel(
          gate: SupplierRepoGate(_app!.suppliers!),
          companyRepo: _app!.companies!,
          partyKind: PartyKind.supplier,
        );
        await customerVm.load();
        await supplierVm.load();
      });
      final l10n = await _pump(
        tester,
        (_) => SimClientsScreen(
          customerViewModel: customerVm,
          supplierViewModel: supplierVm,
        ),
      );

      expect(find.text('عميل أول'), findsOneWidget);
      expect(find.text('مورد أول'), findsNothing);

      await tester.tap(find.text(l10n.simClientsTabSupplier));
      await pumpQuietly(tester, 12);

      expect(find.text('مورد أول'), findsOneWidget);
      expect(find.text('عميل أول'), findsNothing);
      // زر الإضافة صار «اضافة مورد جديد».
      expect(find.text(l10n.simAddSupplierAction), findsOneWidget);
      expect(find.text(l10n.simAddClientAction), findsNothing);
    });

    testWidgets('أيقونة البحث تكشف الحقل ثم تصفي به', (tester) async {
      late final PartyListViewModel customerVm;
      late final PartyListViewModel supplierVm;
      await tester.runAsync(() async {
        await _withReadyApp();
        await _createCustomer('عبدالله السامعي', opening: 500);
        await _createCustomer('سالم الحضرمي', opening: 100);
        customerVm = PartyListViewModel(
          gate: CustomerRepoGate(_app!.customers!),
          companyRepo: _app!.companies!,
          partyKind: PartyKind.customer,
        );
        supplierVm = PartyListViewModel(
          gate: SupplierRepoGate(_app!.suppliers!),
          companyRepo: _app!.companies!,
          partyKind: PartyKind.supplier,
        );
        await customerVm.load();
        await supplierVm.load();
      });
      final l10n = await _pump(
        tester,
        (_) => SimClientsScreen(
          customerViewModel: customerVm,
          supplierViewModel: supplierVm,
        ),
      );

      // الحقل مخفي افتراضياً (نمط SIM: أيقونة تكشفه) — المطوي بالشجرة
      // لكنه غير قابل لللمس (AnimatedCrossFade يبقي الطرفين بالشجرة).
      expect(
        find.byKey(const Key('parties_search_field')).hitTestable(),
        findsNothing,
      );

      // أيقونة الترويسة تُحدَّد بتلميحها (أيقونة البحث موجودة أيقونتها
      // داخل الحقل نفسه فتتعدد مطابقات byIcon).
      await tester.tap(find.byTooltip(l10n.partiesListSearchHint));
      await pumpQuietly(tester, 12);
      expect(
        find.byKey(const Key('parties_search_field')).hitTestable(),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('parties_search_field')),
        'عبدالله',
      );
      await tester.runAsync(() async => await customerVm.setQuery('عبدالله'));
      await pumpQuietly(tester, 12);

      expect(find.text('عبدالله السامعي'), findsOneWidget);
      expect(find.text('سالم الحضرمي'), findsNothing);
    });

    testWidgets('البانر التعليمي يفتح حوار الخطوات', (tester) async {
      late final PartyListViewModel customerVm;
      late final PartyListViewModel supplierVm;
      await tester.runAsync(() async {
        await _withReadyApp();
        customerVm = PartyListViewModel(
          gate: CustomerRepoGate(_app!.customers!),
          companyRepo: _app!.companies!,
          partyKind: PartyKind.customer,
        );
        supplierVm = PartyListViewModel(
          gate: SupplierRepoGate(_app!.suppliers!),
          companyRepo: _app!.companies!,
          partyKind: PartyKind.supplier,
        );
        await customerVm.load();
        await supplierVm.load();
      });
      final l10n = await _pump(
        tester,
        (_) => SimClientsScreen(
          customerViewModel: customerVm,
          supplierViewModel: supplierVm,
        ),
      );

      await tester.tap(find.text(l10n.simClientsTutorial));
      await pumpQuietly(tester, 12);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.simClientsHelpSteps), findsOneWidget);
    });
  });

  group('ItemsListScreen — نمط SIM للمنتجات', () {
    testWidgets('البانر وشارة «جرد ممكن» والسعر بالعملة', (tester) async {
      late final ItemListViewModel vm;
      await tester.runAsync(() async {
        await _withReadyApp();
        await _seedItems();
        vm = ItemListViewModel(
          itemRepo: _app!.items!,
          companyRepo: _app!.companies!,
        );
        await vm.load();
        expect(vm.state.items, hasLength(2), reason: 'بذر قبل العرض');
      });
      final l10n = await _pump(
        tester,
        (_) => ItemsListScreen(viewModel: vm),
      );

      // البانر التعليمي بنمط SIM.
      expect(find.text(l10n.simProductsTitle), findsOneWidget);
      expect(find.text(l10n.simProductsTutorial), findsOneWidget);

      // الصنفان بشارة الجرد — «زيت» متوفر (20) و«سكر» متوفر (2 فوق الصفر).
      expect(find.text('زيت دوار الشمس 1.8ل'), findsOneWidget);
      expect(find.text('سكر ناعم 1كج'), findsOneWidget);
      expect(find.text(l10n.simStockOn), findsNWidgets(2));
    });
  });
}
