/// نموذج «الحركة السريعة» — النافذة الموحدة للمصروف/مسحوبات المالك/
/// إيداع المالك/التحويل بين صندوقين/إيداع بنكي/سحب بنكي (FR-04-02):
/// نموذج واحد ذكي يبدّل الحقول حسب النوع + بوابات أسعار اليوم للعملات
/// غير الأساس (FR-08-09) + تحذير الرصيد السالب المتوقع (FR-04-09 —
/// تحذير بلا منع).
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/cash_repository.dart';
import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/exchange_rate_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/cash.dart';
import '../../../../domain/models/company.dart';

class QuickMovementViewModel extends ChangeNotifier {
  QuickMovementViewModel({
    required CashRepository cashRepo,
    required ExchangeRateRepository fxRepo,
    required CompanyRepository companyRepo,
    required this.initialKind,
  }) : _cash = cashRepo,
       _fx = fxRepo,
       _companies = companyRepo;

  final CashRepository _cash;
  final ExchangeRateRepository _fx;
  final CompanyRepository _companies;

  /// النوع الابتدائي (حسب الزر الذي فتح النافذة).
  final QuickMovementKind initialKind;

  bool _loading = true;
  bool _saving = false;
  Object? _error;

  List<CashboxWithBalance> _boxes = const <CashboxWithBalance>[];
  List<ExpenseCategoryInfo> _categories = const <ExpenseCategoryInfo>[];
  Currency? _baseCurrency;
  int? _userId;

  QuickMovementKind _kind = QuickMovementKind.expense;
  int? _boxId;
  int? _targetBoxId;
  int? _categoryId;
  double? _amount;
  DateTime _txDate = DateTime.now();
  String _description = '';

  String? _saveError;
  bool get loading => _loading;
  bool get saving => _saving;
  Object? get error => _error;
  String? get saveError => _saveError;
  List<CashboxWithBalance> get boxes => _boxes;
  List<ExpenseCategoryInfo> get categories => _categories;
  Currency? get baseCurrency => _baseCurrency;
  QuickMovementKind get kind => _kind;
  int? get boxId => _boxId;
  int? get targetBoxId => _targetBoxId;
  int? get categoryId => _categoryId;
  double? get amount => _amount;
  DateTime get txDate => _txDate;
  String get description => _description;

  bool get needsCategory => _kind == QuickMovementKind.expense;
  bool get needsTargetBox => _kind.needsTargetBox;

  CashboxWithBalance? get selectedBox {
    for (final b in _boxes) {
      if (b.box.id == _boxId) return b;
    }
    return null;
  }

  CashboxWithBalance? get selectedTargetBox {
    for (final b in _boxes) {
      if (b.box.id == _targetBoxId) return b;
    }
    return null;
  }

  ExpenseCategoryInfo? get selectedCategory {
    for (final c in _categories) {
      if (c.id == _categoryId) return c;
    }
    return null;
  }

  /// عملات اليوم الناقصة الأسعار بين المعنيّة بالحركة (صندوق المصدر،
  /// والهدف عند اختلاف عملته) — فارغة = لا بوابة صرف مطلوبة.
  List<String> get missingRateCurrencyCodes {
    final codes = <String>[];
    final base = _baseCurrency;
    final box = selectedBox;
    if (base != null && box != null && box.box.currencyId != base.id) {
      codes.add(box.box.currencyCode);
    }
    if (_kind.needsTargetBox) {
      final target = selectedTargetBox;
      if (base != null &&
          target != null &&
          target.box.currencyId != base.id &&
          target.box.currencyId != box?.box.currencyId) {
        codes.add(target.box.currencyCode);
      }
    }
    return codes;
  }

  /// الرصيد المتوقع للمصدر بعد الحركة (للتحذير البصري — لا منع):
  /// الصادر يطرح والوارد يزيد.
  double? get projectedSourceBalance {
    final box = selectedBox;
    final amount = _amount;
    if (box == null || amount == null) return null;
    switch (_kind) {
      case QuickMovementKind.expense:
      case QuickMovementKind.ownerDraw:
      case QuickMovementKind.boxTransfer:
      case QuickMovementKind.bankDeposit:
        return box.nativeBalance - amount;
      case QuickMovementKind.capitalIn:
      case QuickMovementKind.bankWithdraw:
        return box.nativeBalance + amount;
    }
  }

  /// هل سيتحول رصيد المصدر إلى سالب؟ (FR-04-09 — تحذير فقط).
  bool get sourceWillGoNegative => (projectedSourceBalance ?? 0) < -0.005;

  /// المبلغ الواصل للهدف بعملته (عند اختلاف العملتين) — تقديري بسعر
  /// اليوم إن توفر، `null` عند توافق العملتين أو غياب السعر.
  double? get projectedTargetAmount {
    if (!_kind.needsTargetBox) return null;
    final box = selectedBox;
    final target = selectedTargetBox;
    final amount = _amount;
    if (box == null || target == null || amount == null) return null;
    if (box.box.currencyId == target.box.currencyId) return null;
    final cross = _crossRate(box.box.currencyId, target.box.currencyId);
    if (cross == null) return null;
    return amount * cross;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _cash.listBoxes(),
        _cash.listCategories(),
        _companies.findBaseCurrency(),
        _companies.findAdminUserId(),
        _fx.todayRates(DateTime.now()),
      ]);
      _boxes = results[0]! as List<CashboxWithBalance>;
      _categories = results[1]! as List<ExpenseCategoryInfo>;
      _baseCurrency = results[2] as Currency?;
      _userId = results[3] as int?;
      _todayRates = results[4]! as Map<int, double>;
      _kind = initialKind;
      // الافتراضي أولاً؛ ثم أول صندوق نشط.
      CashboxWithBalance? preferred;
      for (final b in _boxes) {
        if (b.box.isDefault) {
          preferred = b;
          break;
        }
      }
      preferred ??= _boxes.isEmpty ? null : _boxes.first;
      _boxId = preferred?.box.id;
      _targetBoxId = _firstOtherBoxId();
      if (_categories.isNotEmpty && _kind == QuickMovementKind.expense) {
        _categoryId = _categories.first.id;
      }
      _loading = false;
    } catch (e) {
      _error = e;
      _loading = false;
    }
    notifyListeners();
  }

  void setKind(QuickMovementKind kind) {
    if (_kind == kind) return;
    _kind = kind;
    if (kind == QuickMovementKind.expense && _categoryId == null) {
      _categoryId = _categories.isEmpty ? null : _categories.first.id;
    }
    if (kind.needsTargetBox && _targetBoxId == null) {
      _targetBoxId = _firstOtherBoxId();
    }
    _saveError = null;
    notifyListeners();
  }

  void setBox(int? boxId) {
    _boxId = boxId;
    if (_targetBoxId == boxId) {
      _targetBoxId = _firstOtherBoxId(exclude: boxId);
    }
    _saveError = null;
    notifyListeners();
  }

  void setTargetBox(int? boxId) {
    if (boxId == _boxId) return;
    _targetBoxId = boxId;
    _saveError = null;
    notifyListeners();
  }

  void setCategory(int? categoryId) {
    _categoryId = categoryId;
    notifyListeners();
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

  void setDescription(String value) {
    _description = value;
  }

  int? _firstOtherBoxId({int? exclude}) {
    for (final b in _boxes) {
      if (b.box.id != (exclude ?? _boxId)) return b.box.id;
    }
    return null;
  }

  /// يحفظ سعر اليوم لعملة (بوابة الصرف) ثم يعيد الحسابات الحية.
  Future<bool> saveTodayRate(String currencyCode, double rate) async {
    final currencyId = _currencyIdByCode(currencyCode);
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

  /// **ترحيل الحركة** — يفشل برسالة عربية تُعرض كما هي (الفاتورة/الحركة
  /// لا تُكتب عند أي رفض).
  Future<Result<QuickMovementReceipt, String>> save() async {
    final amount = _amount;
    final boxId = _boxId;
    if (amount == null || amount <= 0) {
      return const Err('أدخل مبلغاً أكبر من صفر أولاً.');
    }
    if (boxId == null) {
      return const Err('اختر الصندوق أولاً.');
    }
    if (needsCategory && _categoryId == null) {
      return const Err('اختر فئة المصروف أولاً.');
    }
    if (needsTargetBox && (_targetBoxId == null || _targetBoxId == boxId)) {
      return const Err('اختر صندوقاً هدفاً مختلفاً عن المصدر.');
    }
    _saving = true;
    _saveError = null;
    notifyListeners();
    final draft = QuickMovementDraft(
      kind: _kind,
      cashboxId: boxId,
      amount: amount,
      txDate: _txDate,
      toCashboxId: _targetBoxId,
      expenseCategoryId: _categoryId,
      description: _description.trim().isEmpty ? null : _description.trim(),
    );
    final Result<QuickMovementReceipt, String> result;
    switch (_kind) {
      case QuickMovementKind.expense:
        result = await _cash.createExpense(draft, userId: _userId ?? 1);
      case QuickMovementKind.ownerDraw:
        result = await _cash.createOwnerDraw(draft, userId: _userId ?? 1);
      case QuickMovementKind.capitalIn:
        result = await _cash.createCapitalIn(draft, userId: _userId ?? 1);
      case QuickMovementKind.boxTransfer:
      case QuickMovementKind.bankDeposit:
      case QuickMovementKind.bankWithdraw:
        result = await _cash.createTransfer(draft, userId: _userId ?? 1);
    }
    _saving = false;
    if (result.isErr) {
      _saveError = result.errorOrNull!;
    }
    notifyListeners();
    return result;
  }

  /// أسعار اليوم المخزنة (بعملة الأساس لكل عملة) — تُحمّل مرة في load().
  Map<int, double> _todayRates = const {};

  double? _crossRate(int fromCurrencyId, int toCurrencyId) {
    // سعر اليوم فقط (تقدير العرض) — الحفظ الفعلي يقرأ الأسعار بنفسه.
    final fromIsBase = _baseCurrency?.id == fromCurrencyId;
    final toIsBase = _baseCurrency?.id == toCurrencyId;
    if (fromIsBase && toIsBase) return 1;
    if (fromIsBase) {
      final r = _todayRates[toCurrencyId];
      return r == null || r <= 0 ? null : 1 / r;
    }
    if (toIsBase) {
      return _todayRates[fromCurrencyId];
    }
    final from = _todayRates[fromCurrencyId];
    final to = _todayRates[toCurrencyId];
    if (from == null || to == null || from <= 0 || to <= 0) return null;
    return from / to;
  }

  int? _currencyIdByCode(String code) {
    // من الصناديق المعروضة فقط — عملات الصناديق هي المعنيّة هنا.
    for (final b in _boxes) {
      if (b.box.currencyCode == code) return b.box.currencyId;
    }
    return null;
  }
}
