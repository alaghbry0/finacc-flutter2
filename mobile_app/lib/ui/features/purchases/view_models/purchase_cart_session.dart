/// حامل جلسة فاتورة الشراء — فاتورة حية واحدة طوال جلسة التطبيق.
///
/// **لماذا؟** (نفس قرار سلة الكاشير FR-02-13): يعبّئ التاجر فاتورة الشراء
/// الطويلة (أصناف + دفعات صلاحية + خصومات) ثم يتفقد المخزون أو الموردين
/// ويعود فيجدها كما تركها. حامل طبقي بلا أي تعديل على الملفات المشتركة.
///
/// عند نجاح الترحيل تُفرَّغ الفاتورة داخلياً (شراء جديد) — وبقاء المورد
/// والعملة والمخزن راحة التاجر.
library;

import 'package:sqflite/sqflite.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/exchange_rate_repository.dart';
import '../../../../data/repositories/purchase_repository.dart';
import 'purchase_cart_view_model.dart';

/// جلسة فاتورة شراء واحدة لكل تشغيل تطبيق.
class PurchaseCartSession {
  PurchaseCartViewModel? _viewModel;

  /// يعيد نموذج الفاتورة الحي — ينشئه عند أول طلب ثم يعيد نفس الكائن
  /// مهما تنقّل المستخدم بين الشاشات.
  PurchaseCartViewModel attach({
    required CompanyRepository companyRepo,
    required ExchangeRateRepository fxRepo,
    required PurchaseRepository purchaseRepo,
    required Database database,
  }) {
    return _viewModel ??= PurchaseCartViewModel(
      companyRepo: companyRepo,
      fxRepo: fxRepo,
      purchaseRepo: purchaseRepo,
      database: database,
    );
  }

  /// يعيد الجلسة لحالتها الأولى (بداية نظيفة).
  void reset() => _viewModel = null;

  /// الفاتورة الحالية إن وُجدت (للفحص).
  PurchaseCartViewModel? get current => _viewModel;
}

/// الجلسة التطبيقية الوحيدة لفاتورة الشراء.
final PurchaseCartSession purchaseCartSession = PurchaseCartSession();
