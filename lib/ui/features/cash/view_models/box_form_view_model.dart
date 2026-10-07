/// نموذج نموذج الصندوق (/cash/box-form — إضافة/تعديل): اسم + عملة من
/// عملات المنشأة + تعيين افتراضي (FR-04-01).
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/cash_repository.dart';
import '../../../../data/repositories/company_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/cash.dart';
import '../../../../domain/models/company.dart';

class BoxFormViewModel extends ChangeNotifier {
  BoxFormViewModel({
    required CashRepository cashRepo,
    required CompanyRepository companyRepo,
    this.userId,
    this.editBox,
  }) : _cash = cashRepo,
       _companies = companyRepo;

  final CashRepository _cash;
  final CompanyRepository _companies;

  /// معرّف المستخدم للتدقيق (null = لم يُعثر على مدير بعد).
  final int? userId;

  /// الصندوق عند التعديل (اسمه وعمله وافتراضيته) — `null` عند الإضافة.
  final CashboxInfo? editBox;

  bool _loading = true;
  bool _saving = false;
  Object? _error;

  List<Currency> _currencies = const <Currency>[];
  final Set<int> _usedCurrencyIds = <int>{};

  String _name = '';
  int? _currencyId;
  bool _makeDefault = false;
  String? _saveError;

  bool get loading => _loading;
  bool get saving => _saving;
  Object? get error => _error;
  List<Currency> get currencies => _currencies;
  String get name => _name;
  int? get currencyId => _currencyId;
  bool get makeDefault => _makeDefault;
  String? get saveError => _saveError;
  bool get isEdit => editBox != null;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _companies.listActiveCurrencies(),
        _cash.listBoxes(includeArchived: true),
      ]);
      _currencies = results[0]! as List<Currency>;
      final boxes = results[1]! as List<CashboxWithBalance>;
      _usedCurrencyIds
        ..clear()
        ..addAll(boxes.map((b) => b.box.currencyId));
      if (editBox != null) {
        _name = editBox!.name;
        _currencyId = editBox!.currencyId;
        _makeDefault = editBox!.isDefault;
      } else {
        _currencyId = _currencies.isEmpty ? null : _currencies.first.id;
        // الافتراضي: أول عملة غير مستخدمة بصندوق آخر (تنويع أوعية النقد).
        for (final c in _currencies) {
          if (!_usedCurrencyIds.contains(c.id)) {
            _currencyId = c.id;
            break;
          }
        }
      }
      _loading = false;
    } catch (e) {
      _error = e;
      _loading = false;
    }
    notifyListeners();
  }

  void setName(String value) {
    _name = value;
    _saveError = null;
    notifyListeners();
  }

  void setCurrency(int? currencyId) {
    _currencyId = currencyId;
    _saveError = null;
    notifyListeners();
  }

  void setMakeDefault(bool value) {
    _makeDefault = value;
    notifyListeners();
  }

  Future<Result<Object?, String>> save() async {
    if (_name.trim().isEmpty) {
      return const Err('اسم الصندوق مطلوب — أدخل الاسم ثم احفظ.');
    }
    if (_currencyId == null) {
      return const Err('اختر عملة الصندوق أولاً.');
    }
    if (isEdit && _makeDefault && editBox!.isArchived) {
      return const Err('الصندوق مؤرشف — أزل الأرشفة قبل تعيينه افتراضياً.');
    }
    _saving = true;
    _saveError = null;
    notifyListeners();
    final Result<Object?, String> result;
    if (isEdit) {
      final renamed = await _cash.renameBox(editBox!.id, _name.trim());
      if (renamed.isErr) {
        result = Err(renamed.errorOrNull!);
      } else if (_makeDefault && !editBox!.isDefault) {
        final set = await _cash.setDefaultBox(editBox!.id, userId: userId);
        result = set.isErr
            ? Err(set.errorOrNull!)
            : const Ok<Object?, String>(null);
      } else {
        result = const Ok<Object?, String>(null);
      }
    } else {
      final added = await _cash.addBox(
        _name.trim(),
        _currencyId!,
        makeDefault: _makeDefault,
        userId: userId,
      );
      result = added;
    }
    _saving = false;
    if (result.isErr) {
      _saveError = result.errorOrNull!;
    }
    notifyListeners();
    return result;
  }
}
