/// اختبارات نموذج عرض سجل التدقيق — التحميل والترقيم والأخطاء.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/audit_repository.dart';
import 'package:mobile_app/ui/features/settings/view_models/audit_log_view_model.dart';

import '../helpers/app_for_tests.dart';

void main() {
  setUpAll(initFfiForTests);

  late AppDatabase app;
  late AuditRepository repo;

  setUp(() async {
    final seeded = await openSeededApp();
    app = seeded.$1;
    repo = AuditRepository(app.db);
  });

  tearDown(() async {
    await app.close();
  });

  test('الحالة الابتدائية: تحميل ثم حدث التأسيس', () async {
    final vm = AuditLogViewModel(repository: repo);
    expect(vm.state.loading, isTrue);
    await vm.load();
    expect(vm.state.loading, isFalse);
    expect(vm.state.error, isNull);
    expect(vm.state.events, isNotEmpty);
    expect(vm.state.events.first.action, 'app_setup');
    expect(vm.state.hasMore, isFalse);
    vm.dispose();
  });

  test('loadMore يلحق الصفحة التالية ويحافظ على الترتيب', () async {
    for (var i = 0; i < 50; i++) {
      final day = ((i % 28) + 1).toString().padLeft(2, '0');
      await app.db.insert('audit_log', {
        'user_id': 1,
        'action': 'probe_$i',
        'at': '2026-10-$day${'T'}10:00:00Z',
      });
    }
    final vm = AuditLogViewModel(repository: repo);
    await vm.load();
    final firstCount = vm.state.events.length;
    expect(firstCount, 40, reason: 'حجم الصفحة');
    expect(vm.state.hasMore, isTrue);
    expect(vm.state.totalCount, 51);

    await vm.loadMore();
    expect(vm.state.events.length, 51);
    expect(vm.state.hasMore, isFalse);
    // لا ازدواج في المعرفات.
    expect(vm.state.events.map((e) => e.id).toSet().length, 51);
    vm.dispose();
  });

  test('loadMore لا يعمل مرتين متوازيتين ولا عند النهاية', () async {
    final vm = AuditLogViewModel(repository: repo);
    await vm.load();
    expect(vm.state.hasMore, isFalse);
    await vm.loadMore(); // لا المزيد — تجاهل صامت.
    expect(vm.state.events.length, vm.state.totalCount);
    vm.dispose();
  });

  test('خطأ التحميل: حالة خطأ قابلة لإعادة المحاولة', () async {
    final vm = AuditLogViewModel(repository: repo);
    await app.close(); // إغلاق القاعدة يجعل القراءة تفشل.
    await vm.load();
    expect(vm.state.loading, isFalse);
    expect(vm.state.error, isNotNull);
    expect(vm.state.events, isEmpty);
    vm.dispose();
  });
}
