/// نموذج محور المشتريات (/purchases) — بطاقة بطلة: إحصاءات مشتريات اليوم
/// (عدد الفواتير + قيمة بعملة الأساس لفواتير العملة الأساسية فقط — بلا خلط
/// عملات قط) + آخر المشتريات للوصول السريع.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/purchase_repository.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/purchase.dart';

class PurchasesHomeState {
  const PurchasesHomeState({
    required this.loading,
    required this.recent,
    this.todayCount = 0,
    this.todayTotalBase = 0,
    this.baseCurrencyCode,
    this.error,
  });

  final bool loading;
  final List<PurchaseInvoiceSummary> recent;

  /// عدد فواتير الشراء الصادرة اليوم (بكل العملات).
  final int todayCount;

  /// قيمة مشتريات اليوم بعملة الأساس — تُجمع من فواتير العملة الأساسية
  /// حصراً (فصل العملات 5.4-7: بلا خلط)، فهي الرقم الوحيد القابل للجمع.
  final double todayTotalBase;

  /// رمز عملة الأساس (لتسمية البلاطة).
  final String? baseCurrencyCode;

  final Object? error;

  static const PurchasesHomeState initial = PurchasesHomeState(
    loading: true,
    recent: <PurchaseInvoiceSummary>[],
  );
}

class PurchasesHomeViewModel extends ChangeNotifier {
  PurchasesHomeViewModel({
    required PurchaseRepository purchaseRepo,
    required CompanyRepository companyRepo,
  }) : _purchases = purchaseRepo,
       _companies = companyRepo;

  final PurchaseRepository _purchases;
  final CompanyRepository _companies;

  PurchasesHomeState _state = PurchasesHomeState.initial;
  PurchasesHomeState get state => _state;

  Future<void> load() async {
    _state = PurchasesHomeState.initial;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _purchases.recentPurchases(limit: 50),
        _companies.findBaseCurrency(),
      ]);
      final recent = results[0]! as List<PurchaseInvoiceSummary>;
      final base = results[1] as Currency?;
      final today = DateTime.now();
      var todayCount = 0;
      var todayTotalBase = 0.0;
      for (final invoice in recent) {
        final local = invoice.issuedAt.toLocal();
        if (local.year == today.year &&
            local.month == today.month &&
            local.day == today.day) {
          todayCount++;
          if (base != null && invoice.currencyCode == base.code) {
            todayTotalBase += invoice.total;
          }
        }
      }
      _state = PurchasesHomeState(
        loading: false,
        recent: recent,
        todayCount: todayCount,
        todayTotalBase: todayTotalBase,
        baseCurrencyCode: base?.code,
      );
    } catch (error) {
      _state = PurchasesHomeState(
        loading: false,
        recent: const <PurchaseInvoiceSummary>[],
        error: error,
      );
    }
    notifyListeners();
  }
}
