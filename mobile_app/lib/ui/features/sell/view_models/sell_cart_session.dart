/// حامل جلسة سلة الكاشير — سلة واحدة حية طوال جلسة التطبيق.
///
/// **لماذا؟** شاشات الميزة تبني نماذجها محلياً (نمط المستودع/الأطراف)
/// فتُدمَّر عند مغادرة الشاشة — بينما سلة الكاشير **يجب أن تنجو من
/// التنقل** (FR-02-13 بحدود الذاكرة): يضيف الكاشير أصنافاً، يتفقد الفواتير
/// أو عروض الأسعار، ثم يعود ف يجد سلته كما تركتها. هذا الحامل الطبقي
/// يحقق البقاء بلا أي تعديل على AppController/main (ملفات المنسّق).
///
/// عند نجاح الترحيل تُفرَّغ السلة داخلياً (فاتورة جديدة) — وبقاء العميل
/// والعملة والمخزن راحة الكاشير.
library;

import 'package:sqflite/sqflite.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/exchange_rate_repository.dart';
import '../../../../data/repositories/item_repository.dart';
import '../../../../data/repositories/quotation_repository.dart';
import '../../../../data/repositories/sale_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import 'sell_cart_view_model.dart';

/// جلسة سلة واحدة لكل تشغيل تطبيق.
class SellCartSession {
  SellCartViewModel? _viewModel;

  /// يعيد نموذج السلة الحي — ينشئه عند أول طلب ثم يعيد نفس الكائن
  /// مهما تنقّل المستخدم بين الشاشات.
  ///
  /// [settingsRepo] (UX-2a): سياسات الكاشير الحية (البيع فوق المتاح /
  /// إظهار الخصومات / تحذير الهامش) — اختياري لتوافق الاستدعاءات القائمة.
  SellCartViewModel attach({
    required ItemRepository itemRepo,
    required CompanyRepository companyRepo,
    required ExchangeRateRepository fxRepo,
    required SaleRepository saleRepo,
    required QuotationRepository quotationRepo,
    required Database database,
    SettingsRepository? settingsRepo,
  }) {
    return _viewModel ??= SellCartViewModel(
      itemRepo: itemRepo,
      companyRepo: companyRepo,
      fxRepo: fxRepo,
      saleRepo: saleRepo,
      quotationRepo: quotationRepo,
      database: database,
      settingsRepo: settingsRepo,
    );
  }

  /// يعيد الجلسة لحالتها الأولى (الاختبارات فقط — بداية نظيفة لكل قاعدة).
  void reset() => _viewModel = null;

  /// السلة الحالية إن وُجدت (للاختبارات والفحص).
  SellCartViewModel? get current => _viewModel;
}

/// الجلسة التطبيقية الوحيدة للسلة.
final SellCartSession sellCartSession = SellCartSession();
