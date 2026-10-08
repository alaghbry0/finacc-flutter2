/// نموذج شاشة الوردية (FR-04-04 — الشريحة 9): الوردية الحية بمعادلتها
/// الشاملة (تحديث تلقائي كل 30 ثانية بينما الشاشة ظاهرة) + فتح/إقفال
/// + سجل آخر الورديات المقفلة. المنطق كله هنا — الشاشة عرض وإدخال.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/cash_repository.dart';
import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/shift_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/cash.dart';

/// حالة شاشة الوردية — skeleton/error/ready بنمط المستودعات القائمة.
class ShiftState {
  const ShiftState({
    required this.loading,
    required this.boxes,
    required this.current,
    required this.equation,
    required this.recent,
    this.error,
  });

  static const ShiftState initial = ShiftState(
    loading: true,
    boxes: <CashboxWithBalance>[],
    current: null,
    equation: ShiftEquation.empty(),
    recent: <ShiftRow>[],
  );

  final bool loading;
  final List<CashboxWithBalance> boxes;
  final ShiftRow? current;
  final ShiftEquation equation;
  final List<ShiftRow> recent;
  final Object? error;

  /// الصندوق الذي تجري عليه الوردية — الافتراضي إن لا وردية مفتوحة.
  CashboxWithBalance? boxFor(int? boxId) {
    if (boxes.isEmpty) return null;
    if (boxId != null) {
      for (final box in boxes) {
        if (box.box.id == boxId) return box;
      }
    }
    for (final box in boxes) {
      if (box.box.isDefault) return box;
    }
    return boxes.first;
  }

  /// المتوقع حتى الآن = الرصيد الافتتاحي + صافي المعادلة الحية.
  double get expectedSoFar =>
      (current?.openingCount ?? 0) + equation.expectedDelta;
}

class ShiftViewModel extends ChangeNotifier {
  ShiftViewModel({
    required ShiftRepository shiftRepo,
    required CashRepository cashRepo,
    required CompanyRepository companyRepo,
    required UserRepository userRepo,
  }) : _shifts = shiftRepo,
       _cash = cashRepo,
       _companies = companyRepo,
       _users = userRepo;

  final ShiftRepository _shifts;
  final CashRepository _cash;
  final CompanyRepository _companies;
  final UserRepository _users;

  ShiftState _state = ShiftState.initial;
  ShiftState get state => _state;

  int? _userId;
  String? _userName;
  int? _activeBoxId;

  bool _opening = false;
  bool get opening => _opening;

  bool _closing = false;
  bool get closing => _closing;

  String? _actionError;
  String? get actionError => _actionError;

  Timer? _ticker;

  /// تحديث المعادلة الحية كل 30 ثانية — يُستدعى عند بناء الشاشة
  /// ويُلغى في [stopAutoRefresh] (لا مؤقتات يتيمة).
  void startAutoRefresh() {
    _ticker ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.current != null) unawaited(refreshLive());
    });
  }

  /// يوقف التحديث التلقائي — يُستدعى عند إخلاء الشاشة (dispose الواجهة).
  void stopAutoRefresh() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  /// التحميل الكامل: الصناديق + المستخدم + الوردية الجارية بمعادلتها
  /// + سجل المقفلات. يبدأ من الصندوق الافتراضي (أو صندوق وردية مفتوحة
  /// قائمة على غير الافتراضي).
  Future<void> load() async {
    _state = ShiftState.initial;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _cash.listBoxes(),
        _companies.findAdminUserId(),
        _users.adminDisplayName(),
      ]);
      final boxes = results[0]! as List<CashboxWithBalance>;
      _userId = results[1] as int?;
      _userName = results[2] as String?;

      // صندوق النشاط: وردية مفتوحة قائمة أياً كان صندوقها، وإلا الافتراضي
      // (أول صندوق غير مؤرشف عند غياب علم is_default).
      ShiftRow? current;
      for (final box in boxes) {
        current = await _shifts.currentShift(box.box.id);
        if (current != null) break;
      }
      if (current != null) {
        _activeBoxId = current.cashboxId;
      } else {
        final fallback = boxes
            .where((b) => b.box.isDefault && !b.box.isArchived)
            .firstOrNull;
        _activeBoxId =
            fallback?.box.id ??
            boxes.where((b) => !b.box.isArchived).firstOrNull?.box.id;
      }
      final equation = current == null
          ? const ShiftEquation.empty()
          : await _shifts.equationFor(
              cashboxId: current.cashboxId,
              fromIso: current.openedAt,
              toIso: DateTime.now().toUtc().toIso8601String(),
            );
      final recent = _activeBoxId == null
          ? const <ShiftRow>[]
          : await _shifts.recentShifts(cashboxId: _activeBoxId!);

      _state = ShiftState(
        loading: false,
        boxes: boxes,
        current: current,
        equation: equation,
        recent: recent,
      );
    } catch (error) {
      _state = ShiftState(
        loading: false,
        boxes: const <CashboxWithBalance>[],
        current: null,
        equation: const ShiftEquation.empty(),
        recent: const <ShiftRow>[],
        error: error,
      );
    }
    notifyListeners();
  }

  /// تحديث المعادلة الحية فقط (نبضة المؤقت أو الرجوع للشاشة) — بلا
  /// وميض skeleton: تُحدَّث الأرقام في مكانها.
  Future<void> refreshLive() async {
    final current = _state.current;
    if (current == null) return;
    try {
      final equation = await _shifts.equationFor(
        cashboxId: current.cashboxId,
        fromIso: current.openedAt,
        toIso: DateTime.now().toUtc().toIso8601String(),
      );
      _state = ShiftState(
        loading: false,
        boxes: _state.boxes,
        current: current,
        equation: equation,
        recent: _state.recent,
      );
      notifyListeners();
    } catch (_) {
      // نبضة فاشلة تُتجاهل — النبضة التالية أو السحب اليدوي يعيدانها.
    }
  }

  /// يفتح الوردية على [boxId] برصيد افتتاحي — رسائل الرفض العربية من
  /// المستودع كما هي.
  Future<Result<ShiftRow, String>> openShift(
    int boxId,
    double openingCount,
  ) async {
    if (_opening) return const Err('جارٍ فتح الوردية بالفعل.');
    _opening = true;
    _actionError = null;
    notifyListeners();
    final result = await _shifts.openShift(
      cashboxId: boxId,
      openingCount: openingCount,
      userId: _userId,
    );
    _opening = false;
    if (result.isErr) {
      _actionError = result.errorOrNull;
      notifyListeners();
      return result;
    }
    await load();
    return result;
  }

  /// يُقفل الوردية الجارية بالعدّ الفعلي والملاحظات — يعيد الناتج
  /// الكامل (الصف + المعادلة) لخطوة PDF.
  Future<Result<ShiftCloseResult, String>> closeShift({
    required double counted,
    String? notes,
  }) async {
    final current = _state.current;
    if (current == null) {
      return const Err('لا توجد وردية مفتوحة — افتح الوردية أولاً.');
    }
    if (_closing) return const Err('جارٍ إقفال الوردية بالفعل.');
    _closing = true;
    _actionError = null;
    notifyListeners();
    final result = await _shifts.closeShift(
      shiftId: current.id,
      counted: counted,
      notes: notes,
    );
    _closing = false;
    if (result.isErr) {
      _actionError = result.errorOrNull;
      notifyListeners();
      return result;
    }
    await load();
    return result;
  }

  /// مستودع الوردية — للشاشة عند إعادة حساب معادلة وردية مقفلة (PDF).
  ShiftRepository get shiftRepo => _shifts;

  /// اسم مستخدم الإدارة (لهوية التقرير).
  String? get userName => _userName;

  /// معرف المستخدم الحالي (لفتح الوردية).
  int? get userId => _userId;

  /// يظهر خطأ الإجراء الأخير مرة واحدة ثم يُمسح (SnackBar pattern).
  String? consumeActionError() {
    final error = _actionError;
    _actionError = null;
    notifyListeners();
    return error;
  }
}
