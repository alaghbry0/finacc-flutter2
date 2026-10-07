/// نموذج شاشة السند (قبض RVT من عميل / صرف PMT لمورد — FR-04-02/03/10):
/// منتقي طرف بعملته + مبلغ + صندوق + تاريخ + خيار التخصيص (على الحساب
/// أو تخصيص تلقائي FIFO مع معاينة «يُخصص على: INV-x 500 / INV-y 300»)
/// + بوابة صرف عند عملة سند تخالف عملة صندوقها (FR-08-09 / 5.4-7).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/cash_repository.dart';
import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/customer_repository.dart';
import '../../../../data/repositories/exchange_rate_repository.dart';
import '../../../../data/repositories/supplier_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/cash.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/party.dart';

class VoucherViewModel extends ChangeNotifier {
  VoucherViewModel({
    required CashRepository cashRepo,
    required CustomerRepository customerRepo,
    required SupplierRepository supplierRepo,
    required ExchangeRateRepository fxRepo,
    required CompanyRepository companyRepo,
    required this.isReceipt,
  }) : _cash = cashRepo,
       _customers = customerRepo,
       _suppliers = supplierRepo,
       _fx = fxRepo,
       _companies = companyRepo;

  final CashRepository _cash;
  final CustomerRepository _customers;
  final SupplierRepository _suppliers;
  final ExchangeRateRepository _fx;
  final CompanyRepository _companies;

  /// true = سند قبض (RVT من عميل)؛ false = سند صرف (PMT لمورد).
  final bool isReceipt;

  bool _loading = true;
  bool _saving = false;
  Object? _error;

  List<CashboxWithBalance> _boxes = const <CashboxWithBalance>[];
  List<Currency> _currencies = const <Currency>[];
  Currency? _baseCurrency;
  int? _userId;

  // الطرف المختار مع عملة السياق (سطر رصيد واحد).
  int? _partyId;
  String? _partyName;
  int? _partyCurrencyId;
  String? _partyCurrencyCode;
  double? _partyBalance;

  int? _boxId;
  int? _voucherCurrencyId;
  double? _amount;
  DateTime _txDate = DateTime.now();
  bool _allocateFifo = true;
  String _notes = '';
  List<OpenInvoiceLine> _openInvoices = const <OpenInvoiceLine>[];
  bool _openInvoicesLoading = false;

  String? _saveError;

  bool get loading => _loading;
  bool get saving => _saving;
  Object? get error => _error;
  String? get saveError => _saveError;
  List<CashboxWithBalance> get boxes => _boxes;
  int? get partyId => _partyId;
  String? get partyName => _partyName;
  int? get partyCurrencyId => _partyCurrencyId;
  String? get partyCurrencyCode => _partyCurrencyCode;
  double? get partyBalance => _partyBalance;
  int? get boxId => _boxId;
  int? get voucherCurrencyId => _voucherCurrencyId;
  double? get amount => _amount;
  DateTime get txDate => _txDate;
  bool get allocateFifo => _allocateFifo;
  List<OpenInvoiceLine> get openInvoices => _openInvoices;
  bool get openInvoicesLoading => _openInvoicesLoading;
  String get notes => _notes;

  CashboxWithBalance? get selectedBox {
    for (final b in _boxes) {
      if (b.box.id == _boxId) return b;
    }
    return null;
  }

  String? get voucherCurrencyCode {
    for (final c in _currencies) {
      if (c.id == _voucherCurrencyId) return c.code;
    }
    return _partyCurrencyCode;
  }

  /// هل عملة السند تخالف عملة الصندوق؟ (مسار settlement/فرق الصرف).
  bool get isCrossCurrency {
    final box = selectedBox;
    return box != null &&
        _voucherCurrencyId != null &&
        box.box.currencyId != _voucherCurrencyId;
  }

  /// إجمالي المديونية المفتوحة بعملة السند (للتحقق والعرض).
  double get openDuesTotal {
    var total = 0.0;
    for (final line in _openInvoices) {
      total += line.remaining;
    }
    return total;
  }

  /// خطة التخصيص FIFO المعاينة «يُخصص على: INV-x 500 / INV-y 300» —
  /// نفس منطق المستودع (أقدم فاتورة أولاً حتى نفاد المبلغ).
  List<VoucherAllocationApplied> get previewPlan {
    final amount = _amount;
    if (amount == null || amount <= 0 || !_allocateFifo) {
      return const <VoucherAllocationApplied>[];
    }
    final plan = <VoucherAllocationApplied>[];
    var left = amount;
    for (final line in _openInvoices) {
      if (left <= 0.005) break;
      final alloc = line.remaining < left ? line.remaining : left;
      if (alloc <= 0.005) continue;
      plan.add(
        VoucherAllocationApplied(
          invoiceId: line.invoiceId,
          invoiceNo: line.invoiceNo,
          amount: (alloc * 100).round() / 100,
        ),
      );
      left -= alloc;
    }
    return plan;
  }

  /// الباقي غير المخصَّص (على الحساب) بعد FIFO — للعرض فقط؛ المستودع
  /// يرفض تجاوز المديونية في وضع التخصيص (رسالة عربية واضحة).
  double get unallocatedRemainder {
    final amount = _amount;
    if (amount == null || !_allocateFifo) return 0;
    var allocated = 0.0;
    for (final p in previewPlan) {
      allocated += p.amount;
    }
    return amount - allocated;
  }

  /// تقدير المبلغ المودَع بعملة الصندوق عند اختلاف العملتين (بسعر
  /// اليوم إن توفر — للعرض فقط؛ الحفظ يقرأ الأسعار بنفسه).
  double? get projectedBoxDeposit {
    if (!isCrossCurrency) return _amount;
    final amount = _amount;
    final box = selectedBox;
    if (amount == null || box == null || _voucherCurrencyId == null) {
      return null;
    }
    final vRate = _rateFor(_voucherCurrencyId!);
    final bRate = _rateFor(box.box.currencyId);
    if (vRate == null || bRate == null || bRate <= 0) return null;
    return amount * vRate / bRate;
  }

  /// أسعار اليوم المخزنة (بعملة الأساس لكل عملة) — تُحمّل مرة في load().
  Map<int, double> _todayRates = const {};

  /// عملة السند غير الأساس بلا سعر اليوم — تفتح بوابة الصرف قبل الحفظ.
  bool get voucherRateMissing {
    if (_baseCurrency == null || _voucherCurrencyId == _baseCurrency!.id) {
      return false;
    }
    return _todayRates[_voucherCurrencyId!] == null;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _cash.listBoxes(),
        _companies.listActiveCurrencies(),
        _companies.findBaseCurrency(),
        _companies.findAdminUserId(),
        _fx.todayRates(DateTime.now()),
      ]);
      _boxes = results[0]! as List<CashboxWithBalance>;
      _currencies = results[1]! as List<Currency>;
      _baseCurrency = results[2] as Currency?;
      _userId = results[3] as int?;
      _todayRates = results[4]! as Map<int, double>;
      CashboxWithBalance? preferred;
      for (final b in _boxes) {
        if (b.box.isDefault) {
          preferred = b;
          break;
        }
      }
      preferred ??= _boxes.isEmpty ? null : _boxes.first;
      _boxId = preferred?.box.id;
      _voucherCurrencyId = preferred?.box.currencyId;
      _loading = false;
    } catch (e) {
      _error = e;
      _loading = false;
    }
    notifyListeners();
  }

  /// اختيار الطرف (سطر رصيد واحد = طرف + عملة سياق).
  void setParty(PartyBalance pick) {
    _partyId = pick.partyId;
    _partyName = pick.name;
    _partyCurrencyCode = pick.currencyCode;
    _partyBalance = pick.balance;
    _partyCurrencyId = _currencyIdByCode(pick.currencyCode);
    _voucherCurrencyId = _partyCurrencyId ?? _voucherCurrencyId;
    _saveError = null;
    notifyListeners();
    unawaited(_reloadOpenInvoices());
  }

  void setBox(int? boxId) {
    _boxId = boxId;
    _saveError = null;
    notifyListeners();
  }

  void setVoucherCurrency(int? currencyId) {
    if (_voucherCurrencyId == currencyId) return;
    _voucherCurrencyId = currencyId;
    _saveError = null;
    notifyListeners();
    unawaited(_reloadOpenInvoices());
  }

  void setAmount(double? amount) {
    _amount = amount;
    _saveError = null;
    notifyListeners();
  }

  void setDate(DateTime date) {
    _txDate = date;
    notifyListeners();
  }

  void setAllocateFifo(bool value) {
    _allocateFifo = value;
    notifyListeners();
  }

  void setNotes(String value) {
    _notes = value;
  }

  /// أطراف بحث (لمنتقي السند) — سطر لكل (طرف × عملة) لا دمج: اختيار
  /// السطر يحدد الطرف وعملة سياقه معاً.
  Future<List<PartyBalance>> searchParties(String query) async {
    final trimmed = query.trim();
    if (isReceipt) {
      return _customers.listWithBalances(search: trimmed);
    }
    return _suppliers.listWithBalances(search: trimmed);
  }

  Future<void> _reloadOpenInvoices() async {
    final partyId = _partyId;
    final currencyId = _voucherCurrencyId;
    if (partyId == null || currencyId == null) {
      _openInvoices = const <OpenInvoiceLine>[];
      notifyListeners();
      return;
    }
    _openInvoicesLoading = true;
    notifyListeners();
    try {
      _openInvoices = await _cash.openInvoicesForParty(
        partyType: isReceipt
            ? VoucherPartyType.customer
            : VoucherPartyType.supplier,
        partyId: partyId,
        currencyId: currencyId,
      );
      // تخصيص FIFO افتراضياً عند وجود مديونية مفتوحة بعملة السند.
      _allocateFifo = _openInvoices.isNotEmpty;
    } catch (_) {
      _openInvoices = const <OpenInvoiceLine>[];
    }
    _openInvoicesLoading = false;
    notifyListeners();
  }

  /// يحفظ سعر اليوم لعملة السند (بوابة الصرف).
  Future<bool> saveTodayRate(double rate) async {
    final currencyId = _voucherCurrencyId;
    if (currencyId == null) return false;
    final result = await _fx.setRate(
      currencyId: currencyId,
      date: DateTime.now(),
      rate: rate,
      userId: _userId ?? 1,
    );
    if (result.isOk) {
      _todayRates[currencyId] = rate;
      notifyListeners();
    }
    return result.isOk;
  }

  /// **ترحيل السند** — رقم RVT/PMT + الحركة + التخصيص داخل معاملة
  /// واحدة (المستودع). أي رفض يعيد رسالة عربية تُعرض كما هي.
  Future<Result<VoucherPostedReceipt, String>> save() async {
    final amount = _amount;
    final partyId = _partyId;
    final boxId = _boxId;
    final currencyId = _voucherCurrencyId;
    if (partyId == null) {
      return const Err('اختر الطرف أولاً (عميلاً للقبض أو مورداً للصرف).');
    }
    if (boxId == null) {
      return const Err('اختر الصندوق أولاً.');
    }
    if (currencyId == null) {
      return const Err('اختر عملة السند أولاً.');
    }
    if (amount == null || amount <= 0) {
      return const Err('أدخل مبلغاً أكبر من صفر أولاً.');
    }
    if (_allocateFifo && openDuesTotal <= 0.005) {
      return const Err(
        'لا مديونية مفتوحة بعملة السند لتخصيصها — اختر «على الحساب».',
      );
    }
    _saving = true;
    _saveError = null;
    notifyListeners();
    final result = await _cash.createVoucher(
      VoucherDraft(
        partyType: isReceipt
            ? VoucherPartyType.customer
            : VoucherPartyType.supplier,
        partyId: partyId,
        cashboxId: boxId,
        amount: amount,
        currencyId: currencyId,
        txDate: _txDate,
        allocateFifo: _allocateFifo,
        description: _notes.trim().isEmpty ? null : _notes.trim(),
      ),
      userId: _userId ?? 1,
    );
    _saving = false;
    if (result.isErr) {
      _saveError = result.errorOrNull!;
    }
    notifyListeners();
    return result;
  }

  double? _rateFor(int currencyId) {
    if (_baseCurrency?.id == currencyId) return 1;
    return _todayRates[currencyId];
  }

  int? _currencyIdByCode(String code) {
    for (final c in _currencies) {
      if (c.code == code) return c.id;
    }
    return null;
  }
}
