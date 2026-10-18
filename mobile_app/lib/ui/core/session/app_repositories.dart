/// حاوية مستودعات الجلسة — الستة عشر مستودعاً كوحدة واحدة.
///
/// فصل R20-D1 (الفرصة 4 من تحليل R19-D1): كانت ستة عشر حقلًا متفرقة
/// بـ`AppController` تُبنى سطراً سطراً في `_adopt` وتُصفَّر سطراً سطراً
/// في المسح الكامل — الآن إنشاؤها وتصفيرها عملية واحدة (`_repos = ...`
/// / `_repos = null`) فلا يمكن أن تتفرق الحالة أبداً.
///
/// دورة حياتها ملك `AppController` حصراً (تُبنى مع كل قاعدة مفتوحة
/// وتُمحى عند المسح/الاستعادة) — لا منطق جلسة ولا إخطار هنا إطلاقاً،
/// والمستودع نفسه لا يعلم بوجود الحاوية.
library;

import '../../../core/storage/app_database.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../../data/repositories/batch_repository.dart';
import '../../../data/repositories/cash_repository.dart';
import '../../../data/repositories/company_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../data/repositories/exchange_rate_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/print_template_repository.dart';
import '../../../data/repositories/purchase_repository.dart';
import '../../../data/repositories/quotation_repository.dart';
import '../../../data/repositories/return_repository.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../../../data/repositories/user_repository.dart';

/// مستودعات الجلسة الستة عشر فوق قاعدة مفتوحة — بناء واحد، تصفير واحد.
class AppRepositories {
  /// يبني المستودعات الستة عشر فوق [db] (نفس ترتيب البناء التاريخي
  /// في `_adopt` — ترتيب لا يعتمد عليه أحد لكنه حُفظ عمداً).
  AppRepositories(AppDatabase db)
    : companies = CompanyRepository(db.db),
      users = UserRepository(db.db),
      settings = SettingsRepository(db.db),
      dashboard = DashboardRepository(db.db),
      audit = AuditRepository(db.db),
      items = ItemRepository(db.db),
      batches = BatchRepository(db.db),
      customers = CustomerRepository(db.db),
      suppliers = SupplierRepository(db.db),
      fxRates = ExchangeRateRepository(db.db),
      sales = SaleRepository(db.db),
      quotations = QuotationRepository(db.db),
      purchases = PurchaseRepository(db.db),
      returns = ReturnRepository(db.db),
      cash = CashRepository(db.db),
      printTemplates = PrintTemplateRepository(db.db);

  /// مستودع المنشأة.
  final CompanyRepository companies;

  /// مستودع المستخدمين.
  final UserRepository users;

  /// مستودع الإعدادات (مفاتيح settings).
  final SettingsRepository settings;

  /// مستودع لوحة المؤشرات.
  final DashboardRepository dashboard;

  /// مستودع سجل التدقيق.
  final AuditRepository audit;

  /// مستودع الأصناف.
  final ItemRepository items;

  /// مستودع الدفعات وتواريخ الصلاحية.
  final BatchRepository batches;

  /// مستودع العملاء.
  final CustomerRepository customers;

  /// مستودع الموردين.
  final SupplierRepository suppliers;

  /// مستودع أسعار الصرف اليومية.
  final ExchangeRateRepository fxRates;

  /// مستودع ترحيل فواتير البيع.
  final SaleRepository sales;

  /// مستودع عروض الأسعار وتحويلها.
  final QuotationRepository quotations;

  /// مستودع المشتريات.
  final PurchaseRepository purchases;

  /// مستودع المرتجعات المرتبطة.
  final ReturnRepository returns;

  /// مستودع النقدية والصناديق.
  final CashRepository cash;

  /// مستودع قوالب الطباعة.
  final PrintTemplateRepository printTemplates;
}
