/// مساعدات مسار الدفع بالكاشير: إنشاء عميل سريع من المنتقي (P1-3)
/// وجلب معطيات بوابة حد الائتمان (FR-03-05) — دوال حرة بعوامل صريحة.
library;

import '../../../../../domain/core/result.dart';
import '../../../../../domain/models/party.dart';
import '../../../../../domain/services/credit_limit.dart';
import '../../../../core/session/app_controller.dart';
import '../../view_models/customer_picker_view_model.dart';
import '../../view_models/sell_cart_view_model.dart';

/// ينشئ عميلاً جديداً من المنتقي (P1-3) — بعملة السلة للعرض ورصيد
/// صفري (لا افتتاحي)؛ الفشل يُعاد للعرض داخل النموذج المصغّر.
Future<Result<CustomerPick, String>> createQuickSellCustomer(
  AppController app,
  SellCartViewModel vm,
  String name,
  String? phone,
) async {
  final customers = app.customers;
  final companies = app.companies;
  if (customers == null || companies == null) {
    return const Err<CustomerPick, String>(
      'المستودعات غير جاهزة — أعد فتح الشاشة ثم حاول.',
    );
  }
  final userId = (await companies.findAdminUserId()) ?? 1;
  final result = await customers.createCustomer(
    CustomerDraft(name: name, phone: phone),
    userId: userId,
  );
  if (result.isErr) {
    return Err<CustomerPick, String>(result.errorOrNull!);
  }
  return Ok<CustomerPick, String>(
    CustomerPick(
      partyId: result.valueOrNull!,
      name: name,
      phone: (phone ?? '').isEmpty ? null : phone,
      currencyCode: vm.state.baseCurrency?.code ?? '',
      balance: 0,
      hasMoreCurrencies: false,
    ),
  );
}

/// يجلب معطيات بوابة حد الائتمان — null عند غياب العميل/المستودعات
/// (عميل نقدي مجهول: لا آجل أصلاً فلا فحص — FR-03-05).
Future<CreditLimitGate?> resolveSellCreditGate(
  AppController app,
  SellCartViewModel vm,
) async {
  final customerId = vm.state.customer?.id;
  final currencyId = vm.state.currencyId;
  if (customerId == null || currencyId == null) return null;
  final customers = app.customers;
  final settings = app.settings;
  if (customers == null || settings == null) return null;
  // checkCredit يقرأ الحد من جدول العميل والرصيد بصيغة FR-03-02
  // بعملة الفاتورة (لا الحقل المخزَّن في السلة — دائماً حي).
  final check = await customers.checkCredit(customerId, currencyId, 0);
  final action = await settings.getString(
    'parties.credit_limit_action',
    'warn',
  );
  return CreditLimitGate(
    creditLimit: check.creditLimit,
    action: action,
    currentBalance: check.balance,
  );
}
