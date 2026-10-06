/// اختبارات مستودع سجل التدقيق — ترقيم الصفحات والترتيب والانضمام (FR-12-04).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/storage/app_database.dart';
import 'package:mobile_app/data/repositories/audit_repository.dart';

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

  test('الصفحة الأولى بعد التأسيس: حدث app_setup مع اسم المنفّذ', () async {
    final page = await repo.page();
    expect(page.totalCount, greaterThanOrEqualTo(1));
    expect(page.events, isNotEmpty);
    final setup = page.events.firstWhere((e) => e.action == 'app_setup');
    expect(setup.entity, 'company');
    expect(setup.userName, 'أبو نور', reason: 'انضمام app_user لاسم المنفّذ');
    expect(page.hasMore, isFalse);
  });

  test('الترتيب تنازلي بالزمن (الأحدث أولاً)', () async {
    // نضيف حدثين أحدث من التأسيس بفاصل زمني.
    final db = app.db;
    await db.insert('audit_log', {
      'user_id': 1,
      'action': 'login',
      'at': '2026-10-06T14:00:00Z',
    });
    await db.insert('audit_log', {
      'user_id': 1,
      'action': 'pin_change',
      'at': '2026-10-06T15:00:00Z',
    });
    final page = await repo.page(limit: 10);
    final times = page.events.map((e) => e.atUtc).toList();
    for (var i = 1; i < times.length; i++) {
      expect(
        times[i - 1].isAfter(times[i]) || times[i - 1] == times[i],
        isTrue,
        reason: 'الأحدث يجب أن يسبق',
      );
    }
    expect(page.events.first.action, 'pin_change');
  });

  test('الترقيم: limit/offset وhasMore ودقة totalCount', () async {
    final db = app.db;
    for (var i = 0; i < 5; i++) {
      final day = (8 + i).toString().padLeft(2, '0');
      await db.insert('audit_log', {
        'user_id': 1,
        'action': 'probe_$i',
        'at': '2026-10-$day\u005410:00:00Z',
      });
    }
    final first = await repo.page(limit: 3, offset: 0);
    expect(first.events, hasLength(3));
    expect(first.hasMore, isTrue);
    expect(first.totalCount, 6, reason: 'تأسيس + 5 أحداث');

    final second = await repo.page(limit: 3, offset: 3);
    expect(second.events, hasLength(3));
    expect(second.hasMore, isFalse, reason: '3+3 = الإجمالي 6 — لا المزيد');

    final third = await repo.page(limit: 3, offset: 6);
    expect(third.events, isEmpty);
    expect(third.hasMore, isFalse);

    // لا تداخل بين الصفحات.
    final ids = [...first.events, ...second.events].map((e) => e.id).toSet();
    expect(ids, hasLength(6));
  });

  test('حدث بلا مستخدم: userName فارغ لا يكسر الانضمام', () async {
    await app.db.insert('audit_log', {
      'user_id': null,
      'action': 'system_probe',
      'at': '2026-10-06T18:00:00Z',
    });
    final page = await repo.page(limit: 1);
    final probe = page.events.first;
    expect(probe.action, 'system_probe');
    expect(probe.userName, isNull);
  });

  test('حدث منفرد بلا منشأة: قاعدة فارغة تماماً سليمة', () async {
    final fresh = await openUniqueFileApp();
    addTearDown(fresh.close);
    final freshRepo = AuditRepository(fresh.db);
    final page = await freshRepo.page();
    expect(page.events, isEmpty);
    expect(page.totalCount, 0);
    expect(page.hasMore, isFalse);
  });
}
