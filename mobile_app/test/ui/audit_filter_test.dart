/// اختبارات تصفية سجل التدقيق بالتصنيف — SQL + نموذج العرض.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/audit_repository.dart';
import 'package:mobile_app/domain/models/audit_event.dart';
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
    // بذورة أحداث متنوعة: أمني + إعدادات + غير معروف.
    await app.db.insert('audit_log', {
      'user_id': 1,
      'action': 'pin_change',
      'at': '2026-10-08T09:00:00Z',
    });
    await app.db.insert('audit_log', {
      'user_id': 1,
      'action': 'settings_change',
      'details': 'security.autolock_minutes=15',
      'at': '2026-10-09T09:00:00Z',
    });
    await app.db.insert('audit_log', {
      'user_id': null,
      'action': 'future_action_x',
      'at': '2026-10-10T09:00:00Z',
    });
  });

  tearDown(() async {
    await app.close();
  });

  group('AuditRepository.page بالتصفية', () {
    test('بدون تصفية: الكل (تأسيس + 3 بذور)', () async {
      final page = await repo.page();
      expect(page.totalCount, 4);
    });

    test('تصفية الأمان: أحداث pin/lockout فقط', () async {
      final page = await repo.page(category: AuditCategory.security);
      expect(page.events, hasLength(1));
      expect(page.events.first.action, 'pin_change');
      expect(page.totalCount, 1);
    });

    test('تصفية الإعدادات: settings_change فقط', () async {
      final page = await repo.page(category: AuditCategory.settings);
      expect(page.events, hasLength(1));
      expect(page.events.first.action, 'settings_change');
    });

    test('تصفية التأسيس: app_setup فقط', () async {
      final page = await repo.page(category: AuditCategory.setup);
      expect(page.events, hasLength(1));
      expect(page.events.first.action, 'app_setup');
    });

    test('تصفية «أخرى»: كل ما ليس ضمن الرموز المعروفة', () async {
      final page = await repo.page(category: AuditCategory.other);
      expect(page.events, hasLength(1));
      expect(page.events.first.action, 'future_action_x');
    });

    test('العدّادات لكل تصنيف متطابقة مع التصفية', () async {
      final counts = await repo.counts();
      expect(counts[AuditCategory.setup], 1);
      expect(counts[AuditCategory.security], 1);
      expect(counts[AuditCategory.settings], 1);
      expect(counts[AuditCategory.other], 1);
      expect(counts.values.fold<int>(0, (a, b) => a + b), 4);
    });

    test('الترقيم داخل التصنيف المصفّى (إجمالي التصنيف لا الكل)', () async {
      for (var i = 0; i < 45; i++) {
        await app.db.insert('audit_log', {
          'user_id': 1,
          'action': 'pin_change',
          'at':
              '2026-11-${((i % 28) + 1).toString().padLeft(2, '0')}T09:00:00Z',
        });
      }
      final page = await repo.page(limit: 20, category: AuditCategory.security);
      expect(page.events, hasLength(20));
      expect(page.totalCount, 46, reason: '1 + 45 أمنية');
      expect(page.hasMore, isTrue);
    });
  });

  group('AuditLogViewModel.setFilter', () {
    test('تبديل التصنيف يعيد التحميل بالتصفية ويحدّث العدّادات', () async {
      final vm = AuditLogViewModel(repository: repo);
      await vm.load();
      expect(vm.state.filter, isNull);
      expect(vm.state.events, hasLength(4));

      await vm.setFilter(AuditCategory.security);
      expect(vm.state.filter, AuditCategory.security);
      expect(vm.state.events, hasLength(1));
      expect(vm.state.totalCount, 1);
      expect(vm.state.counts[AuditCategory.security], 1);

      // العودة إلى الكل.
      await vm.setFilter(null);
      expect(vm.state.filter, isNull);
      expect(vm.state.events, hasLength(4));
      vm.dispose();
    });

    test('التبديل لنفس التصنيف لا يعيد التحميل', () async {
      final vm = AuditLogViewModel(repository: repo);
      await vm.load();
      await vm.setFilter(AuditCategory.security);
      final stateAfterFirst = vm.state;
      await vm.setFilter(AuditCategory.security);
      expect(
        identical(stateAfterFirst, vm.state),
        isTrue,
        reason: 'لا إعادة تحميل لنفس القيمة',
      );
      vm.dispose();
    });

    test('loadMore يحترم التصنيف المصفّى', () async {
      for (var i = 0; i < 45; i++) {
        await app.db.insert('audit_log', {
          'user_id': 1,
          'action': 'settings_change',
          'at':
              '2026-12-${((i % 28) + 1).toString().padLeft(2, '0')}T09:00:00Z',
        });
      }
      final vm = AuditLogViewModel(repository: repo);
      await vm.load();
      await vm.setFilter(AuditCategory.settings);
      expect(vm.state.events, hasLength(40));
      await vm.loadMore();
      expect(vm.state.events, hasLength(46), reason: '46 settings_change');
      expect(
        vm.state.events.every((e) => e.category == AuditCategory.settings),
        isTrue,
      );
      vm.dispose();
    });
  });
}
