/// نموذج إدارة الصناديق (/cash/boxes — FR-04-01): قائمة بأرصدة حية +
/// تعيين افتراضي + أرشفة بتأكيد (رصيد ≠ 0 يحذّر أولاً) + إلغاء أرشفة.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/cash_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/cash.dart';

class BoxesState {
  const BoxesState({
    required this.loading,
    required this.boxes,
    required this.archived,
    this.error,
    this.busyBoxId,
  });

  final bool loading;
  final List<CashboxWithBalance> boxes;

  /// صناديق مؤرشفة (قسم منفصل قابل لإلغاء الأرشفة).
  final List<CashboxWithBalance> archived;

  final Object? error;

  /// صندوق قيد التنفيذ عليه الآن (تعطيل أزراره).
  final int? busyBoxId;

  static const BoxesState initial = BoxesState(
    loading: true,
    boxes: <CashboxWithBalance>[],
    archived: <CashboxWithBalance>[],
  );
}

class BoxesViewModel extends ChangeNotifier {
  BoxesViewModel({required CashRepository cashRepo, this.userId})
    : _cash = cashRepo;

  final CashRepository _cash;

  /// معرّف المستخدم للتدقيق (null = لم يُعثر على مدير بعد).
  final int? userId;

  BoxesState _state = BoxesState.initial;
  BoxesState get state => _state;

  Future<void> load() async {
    _state = BoxesState(loading: true, boxes: const [], archived: const []);
    notifyListeners();
    try {
      final all = await _cash.listBoxes(includeArchived: true);
      _state = BoxesState(
        loading: false,
        boxes: [
          for (final b in all)
            if (!b.box.isArchived) b,
        ],
        archived: [
          for (final b in all)
            if (b.box.isArchived) b,
        ],
      );
    } catch (error) {
      _state = BoxesState(
        loading: false,
        boxes: const [],
        archived: const [],
        error: error,
      );
    }
    notifyListeners();
  }

  Future<Result<void, String>> setDefault(int boxId) => _run(boxId, () async {
    final r = await _cash.setDefaultBox(boxId, userId: userId);
    return r;
  });

  Future<Result<void, String>> archive(int boxId) => _run(boxId, () async {
    return _cash.archiveBox(boxId, userId: userId);
  });

  Future<Result<void, String>> unarchive(int boxId) => _run(boxId, () async {
    return _cash.unarchiveBox(boxId);
  });

  Future<Result<void, String>> _run(
    int boxId,
    Future<Result<void, String>> Function() action,
  ) async {
    _state = BoxesState(
      loading: false,
      boxes: _state.boxes,
      archived: _state.archived,
      busyBoxId: boxId,
    );
    notifyListeners();
    final result = await action();
    if (result.isOk) {
      await load();
    } else {
      _state = BoxesState(
        loading: false,
        boxes: _state.boxes,
        archived: _state.archived,
      );
      notifyListeners();
    }
    return result;
  }
}
