/// نموذج عرض تقرير أعمار الديون (FR-09-05) + تذكيرات واتساب
/// (الشريحة 9): اختيار العملة، تحميل التقرير وتحديثه، وبناء رسالة
/// التذكير وفتحها عبر wa.me (واتساب العميل وإلا هاتفه — نمط
/// `pdf_preview_dialog` نفسه).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/debt_aging_repository.dart';
import '../../../../domain/models/company.dart';
import '../../../../l10n/app_localizations.dart';

/// نتيجة محاولة تذكير واتساب — تميّز «لا رقم» عن «فشل الفتح».
enum AgingRemindOutcome {
  /// فُتح واتساب برسالة التذكير.
  opened,

  /// لا رقم واتساب ولا هاتف للعميل.
  noNumber,

  /// تعذّر فتح واتساب (غير مثبّت/رفض النظام).
  failed,
}

/// حالة شاشة أعمار الديون.
class AgingState {
  const AgingState({
    required this.loading,
    this.error,
    this.currencies = const <Currency>[],
    this.currencyId,
    this.report,
    this.decimals = 2,
  });

  final bool loading;
  final Object? error;

  /// العملات النشطة (للمنسدلة) — مرتّبة: الأساس أولاً.
  final List<Currency> currencies;

  /// العملة المختارة للتقرير.
  final int? currencyId;

  /// التقرير المحمّل (قديم قد يبقى أثناء التحديث).
  final AgingReport? report;

  /// منازل العملة المختارة للعرض.
  final int decimals;

  /// لا ديون إطلاقاً (احتفالية — «لا ديون مستحقة»).
  bool get isEmpty =>
      !loading && error == null && report != null && report!.rows.isEmpty;
}

/// نموذج عرض أعمار الديون — ChangeNotifier بنمط وحدة الأطراف.
class AgingViewModel extends ChangeNotifier {
  AgingViewModel({
    required DebtAgingRepository debtRepo,
    required CompanyRepository companyRepo,
    Company? company,
    DateTime? reference,
  }) : _repo = debtRepo,
       _companies = companyRepo,
       _firm = company,
       _now = reference;

  final DebtAgingRepository _repo;
  final CompanyRepository _companies;

  /// المنشأة (اسمها في رسالة التذكير وعملتها الافتراضية) — من
  /// AppController.company.
  final Company? _firm;

  /// لحظة الاحتساب (قابلة للحقن — الاختبارات).
  final DateTime? _now;

  AgingState _state = const AgingState(loading: true);
  AgingState get state => _state;

  /// التحميل الأول — يبدأ من الصفر (هيكل عظمي حتى الجاهزية).
  Future<void> load() => _load(keepReport: false);

  /// تحديث (سحب للأسفل/عودة من مسار فرعي) — يُبقي التقرير القديم
  /// ظاهراً أثناء الجلب.
  Future<void> refresh() => _load(keepReport: true);

  Future<void> _load({required bool keepReport}) async {
    _state = AgingState(
      loading: true,
      currencies: _state.currencies,
      currencyId: _state.currencyId,
      report: keepReport ? _state.report : null,
      decimals: _state.decimals,
    );
    notifyListeners();
    try {
      final currencies = await _companies.listActiveCurrencies();
      if (currencies.isEmpty) {
        _state = AgingState(
          loading: false,
          currencies: const <Currency>[],
          report: keepReport ? _state.report : null,
          decimals: _state.decimals,
        );
        notifyListeners();
        return;
      }
      var currencyId = _state.currencyId;
      if (currencyId == null ||
          !currencies.any((currency) => currency.id == currencyId)) {
        currencyId = _preferredCurrencyId(currencies);
      }
      final report = await _repo.agingReport(
        currencyId: currencyId,
        asOf: _now ?? DateTime.now(),
      );
      _state = AgingState(
        loading: false,
        currencies: currencies,
        currencyId: currencyId,
        report: report,
        decimals: _decimalsOf(currencies, currencyId),
      );
    } catch (error) {
      _state = AgingState(
        loading: false,
        error: error,
        currencies: _state.currencies,
        currencyId: _state.currencyId,
        report: keepReport ? _state.report : null,
        decimals: _state.decimals,
      );
    }
    notifyListeners();
  }

  /// تبديل عملة التقرير — يبدأ تحميلاً نظيفاً للعملة الجديدة.
  Future<void> setCurrency(int currencyId) async {
    if (currencyId == _state.currencyId) return;
    _state = AgingState(
      loading: true,
      currencies: _state.currencies,
      currencyId: currencyId,
      decimals: _decimalsOf(_state.currencies, currencyId),
    );
    notifyListeners();
    try {
      final report = await _repo.agingReport(
        currencyId: currencyId,
        asOf: _now ?? DateTime.now(),
      );
      _state = AgingState(
        loading: false,
        currencies: _state.currencies,
        currencyId: currencyId,
        report: report,
        decimals: _decimalsOf(_state.currencies, currencyId),
      );
    } catch (error) {
      _state = AgingState(
        loading: false,
        error: error,
        currencies: _state.currencies,
        currencyId: currencyId,
        decimals: _decimalsOf(_state.currencies, currencyId),
      );
    }
    notifyListeners();
  }

  /// رقم واتساب العميل (واتسابه وإلا هاتفه) بأرقام صرفة — أو `null`.
  String? whatsappDigits(AgingCustomerRow row) {
    final primary = (row.whatsapp ?? '').trim().isEmpty
        ? row.phone
        : row.whatsapp;
    final digits = (primary ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : digits;
  }

  /// رسالة التذكير المعربة (قالب l10n) باسم المنشأة والإجمالي بعملة
  /// التقرير الحالية — جاهزة للإرسال أو العرض.
  String reminderMessage(AppLocalizations l10n, AgingCustomerRow row) {
    final firm = (_firm?.name ?? '').trim();
    final company = firm.isEmpty ? l10n.agingReminderCompanyFallback : firm;
    final code = _state.report?.currencyCode ?? '';
    final total = _formatAmount(row.total, _state.decimals);
    return l10n.agingReminderMessage(
      row.name,
      company,
      code.isEmpty ? total : '$total $code',
    );
  }

  /// يفتح واتساب برسالة التذكير — `noNumber` عند غياب أي رقم.
  Future<AgingRemindOutcome> remind(
    AgingCustomerRow row,
    String message,
  ) async {
    final digits = whatsappDigits(row);
    if (digits == null) return AgingRemindOutcome.noNumber;
    final text = message.trim();
    final uri = Uri.parse(
      'https://wa.me/$digits'
      '${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}',
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return opened ? AgingRemindOutcome.opened : AgingRemindOutcome.failed;
    } catch (_) {
      return AgingRemindOutcome.failed;
    }
  }

  /// عملة المنشأة إن كانت ضمن النشطة، وإلا الأولى (الأساس أولاً).
  int _preferredCurrencyId(List<Currency> currencies) {
    final firmCurrencyId = _firm?.currencyId;
    if (firmCurrencyId != null &&
        currencies.any((currency) => currency.id == firmCurrencyId)) {
      return firmCurrencyId;
    }
    return currencies.first.id;
  }

  int _decimalsOf(List<Currency> currencies, int currencyId) {
    for (final currency in currencies) {
      if (currency.id == currencyId) return currency.decimals;
    }
    return 2;
  }

  /// تنسيق مبلغ بأرقام غربية وفواصل آلاف (نمط `AmountText.format`) —
  /// نص واتساب خارج الشجرة فلا سياق أرقام له.
  String _formatAmount(double value, int decimals) {
    final pattern = decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}';
    return NumberFormat(pattern, 'en_US').format(value);
  }
}
