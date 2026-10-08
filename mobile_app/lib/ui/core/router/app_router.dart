/// هيكل التنقل — go_router (SRS §6.4).
///
/// الحراسة المركزية عبر أطوار الجلسة:
/// initializing → Splash، needsOnboarding → Onboarding، locked → Lock،
/// ready → الهيكل الرئيسي بخمسة تبويبات (الرئيسية/المخزون/البيع/النقدية/
/// المزيد) مع زر البيع البارز في الوسط.
///
/// **استعادة موقع القفل (P0-1b)**: redirect القفل يسجّل المسار المقصود
/// (المسار فقط — بلا بيانات حساسة) قبل تحويله إلى `/lock`، وبعد الفتح
/// الناجح يعود المستخدم إلى موقعه الأصلي بدل إسقاطه على `/home`.
library;

import 'package:go_router/go_router.dart';

import '../../features/cash/views/box_form_screen.dart';
import '../../features/cash/views/boxes_screen.dart';
import '../../features/cash/views/cash_home_screen.dart';
import '../../features/cash/views/categories_screen.dart';
import '../../features/cash/views/movements_screen.dart';
import '../../features/cash/views/shift_screen.dart';
import '../../features/cash/views/voucher_screen.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/inventory/views/batches_screen.dart';
import '../../features/inventory/views/categories_units_screen.dart';
import '../../features/inventory/views/import_screen.dart';
import '../../features/inventory/views/inventory_home_screen.dart';
import '../../features/inventory/views/item_detail_screen.dart';
import '../../features/inventory/views/item_form_screen.dart';
import '../../features/inventory/views/items_list_screen.dart';
import '../../features/inventory/views/low_stock_screen.dart';
import '../../features/inventory/views/stocktake_screen.dart';
import '../../features/onboarding_auth/views/lock_screen.dart';
import '../../features/onboarding_auth/views/onboarding_screen.dart';
import '../../features/parties/views/exchange_rates_screen.dart';
import '../../features/parties/views/parties_home_screen.dart';
import '../../features/parties/views/parties_list_screen.dart';
import '../../features/parties/views/party_balances_screen.dart';
import '../../features/parties/views/party_detail_screen.dart';
import '../../features/parties/views/party_form_screen.dart';
import '../../features/purchases/views/purchase_screen.dart';
import '../../features/purchases/views/purchases_home_screen.dart';
import '../../features/purchases/views/purchases_list_screen.dart';
import '../../features/purchases/views/returns_screen.dart';
import '../../features/reports/views/aging_report_screen.dart';
import '../../features/reports/views/item_movement_screen.dart';
import '../../features/reports/views/profit_report_screen.dart';
import '../../features/reports/views/reports_hub_screen.dart';
import '../../features/reports/views/sales_by_screen.dart';
import '../../features/reports/views/stock_summary_screen.dart';
import '../../features/sell/views/quotation_detail_screen.dart';
import '../../features/sell/views/quotations_screen.dart';
import '../../features/sell/views/sales_invoices_screen.dart';
import '../../features/sell/views/sell_home_screen.dart';
import '../../features/sell/views/sell_screen.dart';
import '../../features/settings/views/appearance_screen.dart';
import '../../features/settings/views/audit_log_screen.dart';
import '../../features/settings/views/backup_screen.dart';
import '../../features/settings/views/change_pin_screen.dart';
import '../../features/settings/views/company_profile_screen.dart';
import '../../features/settings/views/sale_preferences_screen.dart';
import '../../features/settings/views/settings_screen.dart';
import '../../features/splash/views/splash_screen.dart';
import '../session/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/refresh_on_return.dart';

/// يتتبع آخر مسار **خارج** وحدة المشتريات — يغذّي زر رجوع محور
/// المشتريات بوجهة «الأصل» التي دخل منها المستخدم (P2-7) بدل التصلّب
/// على مسار واحد مهما كان مدخل الوحدة (الرئيسية/البيع/عمق آخر).
class PurchasesOriginTracker {
  String? _origin;

  /// يُستدعى عند كل تغيّر للموقع — مسارات الوحدة نفسها ومسارات
  /// الحراسة (قفل/إقلاع/تأسيس) لا تُسجّل وجهاً.
  void track(String location) {
    if (location.startsWith('/purchases')) return;
    if (location == '/lock' ||
        location == '/splash' ||
        location == '/onboarding') {
      return;
    }
    _origin = location;
  }

  /// وجهة الرجوع (null = مجهول — المتصل يقرر البديل).
  String? get origin => _origin;
}

/// يبني الموجّه فوق متحكم الجلسة (refreshListenable = تغيّر الطور).
GoRouter buildAppRouter(AppController controller) {
  // متتبع أصل دخول محور المشتريات (رجوع ذكي — P2-7).
  final purchasesOrigin = PurchasesOriginTracker();
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: controller,
    // إشعارات didPopNext للشاشات ذات المسارات الفرعية (نموذج/تعديل)
    // — تفعيل RefreshOnReturn (إصلاح ثبات القوائم بعد الحفظ).
    observers: [routeObserver],
    redirect: (context, state) {
      final phase = controller.phase;
      final location = state.matchedLocation;
      switch (phase) {
        case AppPhase.initializing:
        case AppPhase.error:
          return location == '/splash' ? null : '/splash';
        case AppPhase.needsOnboarding:
          return location == '/onboarding' ? null : '/onboarding';
        case AppPhase.locked:
          // سجّل الموقع المقصود قبل القفل — يُستعاد بعد الفتح (P0-1b).
          // المسار فقط؛ `/lock` نفسه لا يُسجّل (منع الحلقات).
          controller.noteLockedFrom(state.uri.path);
          return location == '/lock' ? null : '/lock';
        case AppPhase.ready:
          if (location == '/splash' ||
              location == '/onboarding' ||
              location == '/lock') {
            // فتح ناجح: العودة لموقع ما قبل القفل إن وُجد (مرة واحدة).
            return controller.consumeUnlockDestination() ?? '/home';
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/lock', builder: (context, state) => const LockScreen()),
      // وحدة الأطراف (المرحلة 3) — مسارات علوية بخارج الهيكل (شاشة كاملة
      // بزر رجوع)؛ التنقل بينها بـ go() يبني المكدس فيظهر زر الرجوع تلقائياً.
      GoRoute(
        path: '/parties',
        builder: (context, state) => const PartiesHomeScreen(),
        routes: [
          GoRoute(
            path: 'customers',
            builder: (context, state) => const CustomersListScreen(),
            routes: [
              GoRoute(
                path: 'form',
                builder: (context, state) => CustomerFormScreen(
                  editId: int.tryParse(state.uri.queryParameters['edit'] ?? ''),
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => CustomerDetailScreen(
                  customerId:
                      int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => CustomerFormScreen(
                      editId:
                          int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'suppliers',
            builder: (context, state) => const SuppliersListScreen(),
            routes: [
              GoRoute(
                path: 'form',
                builder: (context, state) => SupplierFormScreen(
                  editId: int.tryParse(state.uri.queryParameters['edit'] ?? ''),
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => SupplierDetailScreen(
                  supplierId:
                      int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => SupplierFormScreen(
                      editId:
                          int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'receivables',
            builder: (context, state) => const ReceivablesScreen(),
          ),
          GoRoute(
            path: 'payables',
            builder: (context, state) => const PayablesScreen(),
          ),
          GoRoute(
            path: 'rates',
            builder: (context, state) => const ExchangeRatesScreen(),
          ),
        ],
      ),
      // وحدة المشتريات والمرتجعات (المرحلة 5) — مسارات علوية خارج الهيكل
      // (نمط الأطراف): شاشة كاملة بزر رجوع، والتنقل بينها بـ go().
      GoRoute(
        path: '/purchases',
        builder: (context, state) =>
            PurchasesHomeScreen(origin: purchasesOrigin.origin),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const PurchaseScreen(),
          ),
          GoRoute(
            path: 'invoices',
            builder: (context, state) => const PurchasesListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => PurchaseDetailScreen(
                  invoiceId:
                      int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                ),
              ),
            ],
          ),
          // مرتجع بيع SRN عن فاتورة بيع أصلية (FR-02-07).
          GoRoute(
            path: 'returns/sale',
            builder: (context, state) => SaleReturnScreen(
              preselectedInvoiceId: int.tryParse(
                state.uri.queryParameters['invoice'] ?? '',
              ),
            ),
          ),
          // مرتجع شراء PRN عن فاتورة شراء أصلية (FR-02-08).
          GoRoute(
            path: 'returns/purchase',
            builder: (context, state) => PurchaseReturnScreen(
              preselectedInvoiceId: int.tryParse(
                state.uri.queryParameters['purchase'] ?? '',
              ),
            ),
          ),
        ],
      ),
      // وحدة التقارير (الشريحة 9→10) — مركز التقارير جذر المسار: بطاقات
      // الأقسام (الأرباح عبر خريطة الترحيل، أعمار الديون، روابط الرقابة
      // العميقة) وتُلحق بها تقارير الشريحة 10 الباقية فور جاهزيتها.
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsHubScreen(),
        routes: [
          GoRoute(
            path: 'aging',
            builder: (context, state) => const AgingReportScreen(),
          ),
          // الأرباح والخسائر (FR-09-02) — الصيغة الملزمة عبر Posting Map.
          GoRoute(
            path: 'profit',
            builder: (context, state) => const ProfitReportScreen(),
          ),
          // حركة صنف (FR-09-03) — بطاقة الصنف بالباقي التراكمي.
          GoRoute(
            path: 'item-movement',
            builder: (context, state) => const ItemMovementScreen(),
          ),
          // ملخص حركة المخزون (FR-09-04) — وارد/صادر/مرتجع/تسوية لكل صنف.
          GoRoute(
            path: 'stock-summary',
            builder: (context, state) => const StockSummaryScreen(),
          ),
          // المبيعات حسب (FR-09-06) — العميل/الفئة/الصنف/اليوم + نسب التغير.
          GoRoute(
            path: 'sales-by',
            builder: (context, state) => const SalesByScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (context, state) => const InventoryHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'items',
                    builder: (context, state) => const ItemsListScreen(),
                  ),
                  GoRoute(
                    path: 'item-form',
                    builder: (context, state) => const ItemFormScreen(),
                  ),
                  GoRoute(
                    path: 'item/:id',
                    builder: (context, state) => ItemDetailScreen(
                      itemId:
                          int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => ItemFormScreen(
                          editId:
                              int.tryParse(state.pathParameters['id'] ?? '') ??
                              -1,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'low-stock',
                    builder: (context, state) => const LowStockScreen(),
                  ),
                  GoRoute(
                    path: 'batches',
                    builder: (context, state) => const BatchesScreen(),
                  ),
                  GoRoute(
                    path: 'import',
                    builder: (context, state) => const ImportScreen(),
                  ),
                  GoRoute(
                    path: 'categories-units',
                    builder: (context, state) => const CategoriesUnitsScreen(),
                  ),
                  // الجرد الفعلي (FR-01-08 — الشريحة 10): دفتري/فعلي +
                  // تسوية ذرّية بتكلفة لقطة داخل معاملة واحدة.
                  GoRoute(
                    path: 'stocktake',
                    builder: (context, state) => const StocktakeScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sell',
                builder: (context, state) => const SellHomeScreen(),
                routes: [
                  // الكاشير — السلة محفوظة بجلسة تطبيقية (SellCartSession)
                  // فتنجو من التنقل بين الشاشات (FR-02-13).
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const SellScreen(),
                  ),
                  GoRoute(
                    path: 'invoices',
                    builder: (context, state) => const SalesInvoicesScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => SaleInvoiceDetailScreen(
                          invoiceId:
                              int.tryParse(state.pathParameters['id'] ?? '') ??
                              -1,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'quotations',
                    builder: (context, state) => const QuotationsScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => QuotationDetailScreen(
                          quotationId:
                              int.tryParse(state.pathParameters['id'] ?? '') ??
                              -1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // وحدة النقدية والصناديق (الشريحة 6 — FR-04) — تبويب رابع
          // بمسارات فرعية داخل الفرع (السجل/الصناديق/النموذج/السندات).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cash',
                builder: (context, state) => const CashHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'boxes',
                    builder: (context, state) => const BoxesScreen(),
                  ),
                  GoRoute(
                    path: 'box-form',
                    builder: (context, state) => BoxFormScreen(
                      editId: int.tryParse(
                        state.uri.queryParameters['edit'] ?? '',
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'box-form/:id',
                    builder: (context, state) => BoxFormScreen(
                      editId:
                          int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                    ),
                  ),
                  GoRoute(
                    path: 'movements',
                    builder: (context, state) => MovementsScreen(
                      initialBoxId: int.tryParse(
                        state.uri.queryParameters['box'] ?? '',
                      ),
                    ),
                  ),
                  // سند قبض (receipt — RVT من عميل) / صرف (payment — PMT لمورد).
                  GoRoute(
                    path: 'voucher/:type',
                    builder: (context, state) => VoucherScreen(
                      isReceipt: state.pathParameters['type'] == 'receipt',
                    ),
                  ),
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) => const CategoriesScreen(),
                  ),
                  // الوردية بالمعادلة الشاملة (الشريحة 9 — FR-04-04).
                  GoRoute(
                    path: 'shift',
                    builder: (context, state) => const ShiftScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'change-pin',
                    builder: (context, state) => const ChangePinScreen(),
                  ),
                  GoRoute(
                    path: 'audit-log',
                    builder: (context, state) => const AuditLogScreen(),
                  ),
                  // النسخ الاحتياطي والاستعادة (الشريحة 8 — FR-11).
                  GoRoute(
                    path: 'backup',
                    builder: (context, state) => const BackupScreen(),
                  ),
                  // بيانات المنشأة (UX-2a) — المحرر الكامل + رافع الشعار.
                  GoRoute(
                    path: 'company',
                    builder: (context, state) => const CompanyProfileScreen(),
                  ),
                  // تفضيلات البيع (UX-2a) — سياسات الكاشير الخمس.
                  GoRoute(
                    path: 'sale-prefs',
                    builder: (context, state) => const SalePreferencesScreen(),
                  ),
                  // العرض والمظهر (UX-2a) — ثيم/أرقام/حجم خط/تباين عالي.
                  GoRoute(
                    path: 'appearance',
                    builder: (context, state) => const AppearanceScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  // تغذية متتبع أصل المشتريات بكل تغيّر موقع (رجوع حسب الأصل — P2-7).
  router.routerDelegate.addListener(() {
    purchasesOrigin.track(router.routerDelegate.currentConfiguration.uri.path);
  });
  return router;
}
