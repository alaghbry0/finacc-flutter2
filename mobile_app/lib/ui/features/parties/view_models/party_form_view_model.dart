/// نموذج عرض نموذج الطرف (عميل/مورد — إضافة وتعديل) — FR-03-01/03:
/// الاسم إلزامي، حد الائتمان بدلالته الثلاثية الصارمة (فارغ = بلا حد،
/// صفر = منع الآجل، رقم = الحد)، ورصيد افتتاحي بعملته وسعر يومه
/// وتاريخه، والافتتاحي مقفل في التعديل متى كانت للطرف حركات.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/customer_repository.dart';
import '../../../../data/repositories/exchange_rate_repository.dart';
import '../../../../data/repositories/supplier_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/party.dart';
import 'party_kind.dart';
import 'party_lookup.dart';

/// أخطاء التحقق القابلة للترجمة (تُعرض فوق زر الحفظ).
enum PartyFormError {
  /// الاسم فارغ.
  nameRequired,

  /// حد الائتمان ليس رقماً صالحاً (فارغ/صفر/موجب فقط).
  creditLimitInvalid,

  /// الرصيد الافتتاحي ليس رقماً موجباً.
  openingInvalid,

  /// رصيد افتتاحي غير صفري بلا عملة.
  openingCurrencyRequired,

  /// لا سعر صرف للعملة المحددة (FR-08-09 — يمنع الحفظ).
  noRate,

  /// لا مستخدم مدير (تعذر قيد التدقيق).
  noUser,
}

/// حالة نموذج الطرف — قيم الحقول كنصوص كما يكتبها المستخدم.
class PartyFormState {
  const PartyFormState({
    required this.loading,
    required this.kind,
    required this.editMode,
    required this.currencies,
    this.loadError,
    this.baseCurrency,
    this.userId,
    this.name = '',
    this.phone = '',
    this.whatsapp = '',
    this.address = '',
    this.area = '',
    this.creditLimitText = '',
    this.openingText = '',
    this.openingCurrencyId,
    required this.openingDate,
    this.notes = '',
    this.openingLocked = false,
    this.saving = false,
    this.saved = false,
    this.validationError,
    this.repoError,
  });

  final bool loading;

  /// نوع الطرف — يحدد الحقول الزائدة (واتساب/حي/حد ائتمان للعملاء).
  final PartyKind kind;

  /// وضع التعديل.
  final bool editMode;

  /// العملات النشطة — الأساسية أولاً.
  final List<Currency> currencies;

  final Object? loadError;

  final Currency? baseCurrency;
  final int? userId;

  // ── الحقول النصية ──
  final String name;
  final String phone;
  final String whatsapp;
  final String address;
  final String area;

  /// حد الائتمان كنص: فارغ = بلا حد، «0» = منع الآجل، رقم = الحد.
  final String creditLimitText;

  /// الرصيد الافتتاحي كنص.
  final String openingText;

  /// عملة الرصيد الافتتاحي (null = بلا — ممنوع مع رصيد غير صفري).
  final int? openingCurrencyId;

  /// تاريخ الرصيد الافتتاحي (اليوم افتراضياً).
  final DateTime openingDate;

  final String notes;

  /// الافتتاحي مقفل (تعديل لطرف له حركات) — للقراءة فقط في العرض.
  final bool openingLocked;

  final bool saving;
  final bool saved;
  final PartyFormError? validationError;

  /// خطأ المستودع (عربي جاهز — SnackBar).
  final String? repoError;

  /// حد الائتمان المفسر بدلالته الثلاثية — أو null عند نص غير صالح.
  double? get parsedCreditLimit {
    final text = creditLimitText.trim();
    if (text.isEmpty) return null; // بلا حد.
    return double.tryParse(text);
  }

  /// الرصيد الافتتاحي المفسر — أو null عند نص غير صالح.
  double? get parsedOpening {
    final text = openingText.trim();
    if (text.isEmpty) return 0;
    return double.tryParse(text);
  }

  /// العملة الافتتاحية المحددة ككيان (null عند عدم الاختيار).
  Currency? get selectedOpeningCurrency {
    for (final currency in currencies) {
      if (currency.id == openingCurrencyId) return currency;
    }
    return null;
  }

  static PartyFormState initial(PartyKind kind, DateTime today) =>
      PartyFormState(
        loading: true,
        kind: kind,
        editMode: false,
        currencies: const <Currency>[],
        openingDate: today,
      );
}

class PartyFormViewModel extends ChangeNotifier {
  PartyFormViewModel({
    required CustomerRepository customerRepo,
    required SupplierRepository supplierRepo,
    required CompanyRepository companyRepo,
    required ExchangeRateRepository fxRepo,
    required PartyLookup partyLookup,
    required PartyKind partyKind,
    DateTime? reference,
    int? editPartyId,
  }) : _customers = customerRepo,
       _suppliers = supplierRepo,
       _companies = companyRepo,
       _fx = fxRepo,
       _lookup = partyLookup,
       _kind = partyKind,
       _editId = editPartyId,
       _today = (reference ?? DateTime.now());

  final CustomerRepository _customers;
  final SupplierRepository _suppliers;
  final CompanyRepository _companies;
  final ExchangeRateRepository _fx;
  final PartyLookup _lookup;
  final PartyKind _kind;

  /// معرّف الطرف في وضع التعديل (null = إنشاء).
  final int? _editId;

  /// «اليوم» المرجعي (قابل للحقن).
  final DateTime _today;

  /// قيم الافتتاحي الأصلية — تُعاد كما هي عند الحفظ والافتتاحي مقفل.
  double _origOpening = 0;
  int? _origOpeningCurrencyId;
  double? _origOpeningRate;
  DateTime? _origOpeningDate;
  String? _origImagePath;

  PartyFormState _state = PartyFormState.initial(
    PartyKind.customer,
    DateTime.now(),
  );
  PartyFormState get state => _state;

  /// تحميل بيانات النموذج: العملات + المدير + السجل في وضع التعديل
  /// (مع فحص الحركات لقفل الافتتاحي).
  Future<void> load() async {
    final today = DateTime(_today.year, _today.month, _today.day);
    _state = PartyFormState(
      loading: true,
      kind: _kind,
      editMode: _editId != null,
      currencies: _state.currencies,
      openingDate: today,
    );
    notifyListeners();
    try {
      final editId = _editId;
      final isCustomer = _kind == PartyKind.customer;
      // فهرسة حتمية: [0] عملات، [1] مدير، [2] السجل (تعديل فقط)،
      // [3] فحص الحركات (تعديل فقط) — لا فروع شرطية داخل القائمة
      // لأنها كانت تزيح الفهارس بين العميل والمورد.
      final results = await Future.wait<Object?>([
        _companies.listActiveCurrencies(),
        _companies.findAdminUserId(),
        if (editId != null)
          isCustomer ? _lookup.customer(editId) : _lookup.supplier(editId),
        if (editId != null)
          isCustomer
              ? _customers.hasMovements(editId)
              : _suppliers.hasMovements(editId),
      ]);
      final currencies = results[0] as List<Currency>;
      final userId = results[1] as int?;
      final baseCurrency = currencies.isEmpty ? null : currencies.first;
      final hasMovements = editId == null ? false : results[3] as bool;

      if (isCustomer) {
        final customer = editId == null ? null : results[2] as Customer?;
        if (editModeRecordMissing(editId, customer)) {
          _notFound(currencies, userId, baseCurrency, today);
          return;
        }
        if (customer != null) {
          _origOpening = customer.openingBalance;
          _origOpeningCurrencyId = customer.openingBalanceCurrencyId;
          _origOpeningRate = customer.openingBalanceRate;
          _origOpeningDate = _tryParse(customer.openingBalanceDate);
          _origImagePath = customer.imagePath;
          _state = PartyFormState(
            loading: false,
            kind: _kind,
            editMode: true,
            currencies: currencies,
            baseCurrency: baseCurrency,
            userId: userId,
            name: customer.name,
            phone: customer.phone ?? '',
            whatsapp: customer.whatsapp ?? '',
            address: customer.address ?? '',
            area: customer.area ?? '',
            creditLimitText: customer.creditLimit == null
                ? ''
                : _numToText(customer.creditLimit!),
            openingText: _numToText(customer.openingBalance),
            openingCurrencyId:
                customer.openingBalanceCurrencyId ?? baseCurrency?.id,
            openingDate: _origOpeningDate ?? today,
            notes: customer.notes ?? '',
            openingLocked: hasMovements,
          );
          notifyListeners();
          return;
        }
      } else {
        final supplier = editId == null ? null : results[2] as Supplier?;
        if (editModeRecordMissing(editId, supplier)) {
          _notFound(currencies, userId, baseCurrency, today);
          return;
        }
        if (supplier != null) {
          _origOpening = supplier.openingBalance;
          _origOpeningCurrencyId = supplier.openingBalanceCurrencyId;
          _origOpeningRate = supplier.openingBalanceRate;
          _origOpeningDate = _tryParse(supplier.openingBalanceDate);
          _state = PartyFormState(
            loading: false,
            kind: _kind,
            editMode: true,
            currencies: currencies,
            baseCurrency: baseCurrency,
            userId: userId,
            name: supplier.name,
            phone: supplier.phone ?? '',
            address: supplier.address ?? '',
            openingText: _numToText(supplier.openingBalance),
            openingCurrencyId:
                supplier.openingBalanceCurrencyId ?? baseCurrency?.id,
            openingDate: _origOpeningDate ?? today,
            notes: supplier.notes ?? '',
            openingLocked: hasMovements,
          );
          notifyListeners();
          return;
        }
      }
      _state = PartyFormState(
        loading: false,
        kind: _kind,
        editMode: false,
        currencies: currencies,
        baseCurrency: baseCurrency,
        userId: userId,
        openingCurrencyId: baseCurrency?.id,
        openingDate: today,
      );
    } catch (error) {
      _state = PartyFormState(
        loading: false,
        kind: _kind,
        editMode: _editId != null,
        currencies: _state.currencies,
        loadError: error,
        openingDate: DateTime(_today.year, _today.month, _today.day),
      );
    }
    notifyListeners();
  }

  /// هل السجل المطلوب تعديله غير موجود؟
  static bool editModeRecordMissing(int? editId, Object? record) =>
      editId != null && record == null;

  void _notFound(
    List<Currency> currencies,
    int? userId,
    Currency? baseCurrency,
    DateTime today,
  ) {
    _state = PartyFormState(
      loading: false,
      kind: _kind,
      editMode: true,
      currencies: currencies,
      baseCurrency: baseCurrency,
      userId: userId,
      openingDate: today,
      loadError: StateError('الطرف رقم #$_editId غير موجود.'),
    );
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────
  // محدِّثات الحقول
  // ─────────────────────────────────────────────────────────────────────

  void setName(String value) => _mutate(name: value);

  void setPhone(String value) => _mutate(phone: value);

  void setWhatsapp(String value) => _mutate(whatsapp: value);

  void setAddress(String value) => _mutate(address: value);

  void setArea(String value) => _mutate(area: value);

  void setCreditLimitText(String value) =>
      _mutate(creditLimitText: value, clearValidationError: true);

  void setOpeningText(String value) =>
      _mutate(openingText: value, clearValidationError: true);

  void setOpeningCurrency(int? currencyId) {
    if (currencyId == null) {
      _mutate(clearOpeningCurrency: true, clearValidationError: true);
    } else {
      _mutate(openingCurrencyId: currencyId, clearValidationError: true);
    }
  }

  void setOpeningDate(DateTime date) => _mutate(openingDate: date);

  void setNotes(String value) => _mutate(notes: value);

  // ─────────────────────────────────────────────────────────────────────
  // الحفظ
  // ─────────────────────────────────────────────────────────────────────

  /// يتحقق ثم ينفّذ الإنشاء/التعديل — يعيد true عند النجاح.
  Future<bool> save() async {
    if (_state.saving || _state.saved) return false;

    final name = _state.name.trim();
    if (name.isEmpty) {
      _mutate(validationError: PartyFormError.nameRequired);
      return false;
    }
    // حد الائتمان بدلالته الثلاثية: فارغ = null (بلا حد)؛ رقم = الحد.
    final creditText = _state.creditLimitText.trim();
    double? creditLimit;
    if (creditText.isNotEmpty) {
      final parsed = double.tryParse(creditText);
      if (parsed == null || parsed < 0) {
        _mutate(validationError: PartyFormError.creditLimitInvalid);
        return false;
      }
      creditLimit = parsed;
    }
    final opening = _state.parsedOpening;
    if (opening == null || opening < 0) {
      _mutate(validationError: PartyFormError.openingInvalid);
      return false;
    }
    if (opening != 0 && _state.openingCurrencyId == null) {
      _mutate(validationError: PartyFormError.openingCurrencyRequired);
      return false;
    }
    final userId = _state.userId;
    if (userId == null) {
      _mutate(validationError: PartyFormError.noUser);
      return false;
    }

    // الافتتاحي المقفل: القيم الأصلية كما سُجّلت — أي تعديل عليها ممنوع
    // بعد أول حركة (نصّ المهمة؛ المستودع لا يقبل إلا مسودة سليمة).
    final effectiveOpening = _state.openingLocked ? _origOpening : opening;
    final effectiveCurrency = _state.openingLocked
        ? _origOpeningCurrencyId
        : (opening == 0 ? null : _state.openingCurrencyId);
    final effectiveDate = _state.openingLocked
        ? (_origOpeningDate ?? _state.openingDate)
        : _state.openingDate;
    final effectiveRate = _state.openingLocked
        ? _origOpeningRate
        : await _resolveRate(effectiveCurrency, effectiveDate);
    if (effectiveOpening != 0 && effectiveRate == null) {
      _mutate(validationError: PartyFormError.noRate);
      return false;
    }

    _mutate(saving: true, clearValidationError: true, clearRepoError: true);

    final Result<Object, String> result;
    if (_kind == PartyKind.customer) {
      final draft = CustomerDraft(
        name: name,
        phone: _clean(_state.phone),
        whatsapp: _clean(_state.whatsapp),
        address: _clean(_state.address),
        area: _clean(_state.area),
        creditLimit: creditLimit,
        openingBalance: effectiveOpening,
        openingBalanceCurrencyId: effectiveCurrency,
        openingBalanceRate: effectiveRate,
        openingBalanceDate: effectiveDate,
        notes: _clean(_state.notes),
        imagePath: _origImagePath,
      );
      result = _state.editMode
          ? await _customers.updateCustomer(
              _editId!,
              draft,
              userId: userId,
              now: _today,
            )
          : await _customers.createCustomer(draft, userId: userId, now: _today);
    } else {
      final draft = SupplierDraft(
        name: name,
        phone: _clean(_state.phone),
        address: _clean(_state.address),
        openingBalance: effectiveOpening,
        openingBalanceCurrencyId: effectiveCurrency,
        openingBalanceRate: effectiveRate,
        openingBalanceDate: effectiveDate,
        notes: _clean(_state.notes),
      );
      result = _state.editMode
          ? await _suppliers.updateSupplier(
              _editId!,
              draft,
              userId: userId,
              now: _today,
            )
          : await _suppliers.createSupplier(draft, userId: userId, now: _today);
    }
    switch (result) {
      case Ok<Object, String>():
        _mutate(saving: false, saved: true);
        return true;
      case final Err<Object, String> err:
        _mutate(saving: false, repoError: err.error);
        return false;
    }
  }

  /// سعر الصرف as-of للعملة الافتتاحية: الأساس = 1 دائماً؛ غيره سعر
  /// اليوم نفسه ثم آخر سعر معروف قبله (احتياطي معلن) — أو null (منع
  /// الحفظ وفق FR-08-09 حتى يُدخل السعر).
  Future<double?> _resolveRate(int? currencyId, DateTime date) async {
    if (currencyId == null) return null;
    if (currencyId == _state.baseCurrency?.id) return 1;
    final exact = await _fx.rateFor(currencyId, date);
    if (exact != null) return exact;
    return _fx.latestBefore(currencyId, date);
  }

  // ─────────────────────────────────────────────────────────────────────
  // مساعدات خاصة
  // ─────────────────────────────────────────────────────────────────────

  void _mutate({
    String? name,
    String? phone,
    String? whatsapp,
    String? address,
    String? area,
    String? creditLimitText,
    String? openingText,
    int? openingCurrencyId,
    bool clearOpeningCurrency = false,
    DateTime? openingDate,
    String? notes,
    bool? saving,
    bool? saved,
    PartyFormError? validationError,
    bool clearValidationError = false,
    String? repoError,
    bool clearRepoError = false,
  }) {
    _state = PartyFormState(
      loading: _state.loading,
      kind: _state.kind,
      editMode: _state.editMode,
      currencies: _state.currencies,
      loadError: _state.loadError,
      baseCurrency: _state.baseCurrency,
      userId: _state.userId,
      name: name ?? _state.name,
      phone: phone ?? _state.phone,
      whatsapp: whatsapp ?? _state.whatsapp,
      address: address ?? _state.address,
      area: area ?? _state.area,
      creditLimitText: creditLimitText ?? _state.creditLimitText,
      openingText: openingText ?? _state.openingText,
      openingCurrencyId: clearOpeningCurrency
          ? null
          : (openingCurrencyId ?? _state.openingCurrencyId),
      openingDate: openingDate ?? _state.openingDate,
      notes: notes ?? _state.notes,
      openingLocked: _state.openingLocked,
      saving: saving ?? _state.saving,
      saved: saved ?? _state.saved,
      validationError: clearValidationError
          ? null
          : (validationError ?? _state.validationError),
      repoError: clearRepoError ? null : (repoError ?? _state.repoError),
    );
    notifyListeners();
  }

  /// نص فارغ (فراغات فقط) → `null`.
  static String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// نص عرض للرقم (بلا كسور زائدة) — لتعبئة الحقول مسبقاً.
  static String _numToText(double value) {
    if (value == value.truncateToDouble() && value.abs() < 1e15) {
      return value.truncate().toString();
    }
    return value.toString();
  }

  static DateTime? _tryParse(String? ymd) {
    if (ymd == null || ymd.isEmpty) return null;
    final parsed = DateTime.tryParse(ymd);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}
