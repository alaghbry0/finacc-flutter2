/// مستودع المنشأة والعملات — جدولا `company` و`currency` (§5.3).
///
/// يملك التنفيذ الذرّي لتأسيس المنشأة (FR-13-01): كل الصفوف داخل
/// Transaction واحدة — فشل أي خطوة يرجع الكل.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import '../../domain/models/company.dart';
import '../../domain/use_cases/setup_company.dart';

class CompanyRepository {
  CompanyRepository(this._db);

  final Database _db;

  /// هل أُسست المنشأة؟ (قرار التوجيه الأولي: onboarding أم القفل/الدخول).
  Future<bool> hasCompany() async {
    final rows = await _db.rawQuery(
      'SELECT EXISTS(SELECT 1 FROM company LIMIT 1) AS ok',
    );
    return (rows.first['ok'] as int) == 1;
  }

  /// المنشأة (أو null قبل التأسيس).
  Future<Company?> findCompany() async {
    final rows = await _db.query('company', limit: 1);
    if (rows.isEmpty) return null;
    return Company.fromRow(rows.first);
  }

  /// العملة الأساسية (YER افتراضياً بعد البذور).
  Future<Currency?> findBaseCurrency() async {
    final rows = await _db.query('currency', where: 'is_base = 1', limit: 1);
    if (rows.isEmpty) return null;
    return Currency.fromRow(rows.first);
  }

  /// العملات النشطة (لاختر العملة الأساسية في Onboarding).
  Future<List<Currency>> listActiveCurrencies() async {
    final rows = await _db.query(
      'currency',
      where: 'is_active = 1',
      orderBy: 'is_base DESC, code ASC',
    );
    return rows.map(Currency.fromRow).toList();
  }

  /// **التأسيس الذرّي** — ينشئ المنشأة/المخزن/الصندوق/المدير/السنة المالية
  /// وعبارة المرور داخل معاملة واحدة، ويعيد كيان المنشأة المكتمل.
  ///
  /// [now] يُستخدم للطوابع الزمنية (قابل للحقن في الاختبارات).
  Future<Company> executeSetup(SetupCompanyDraft draft, DateTime now) async {
    final iso = now.toUtc().toIso8601String();

    return _db.transaction((txn) async {
      // 1) العملة الأساسية: تُثبَّت الآن ولا تُغيَّر بعدها (FR-08-01).
      //    البذور تجعل YER أساسية افتراضياً؛ اختيار Onboarding يعيد الضبط.
      await txn.update('currency', {'is_base': 0}, where: 'is_base = 1');
      final updated = await txn.update(
        'currency',
        {'is_base': 1},
        where: 'code = ?',
        whereArgs: [draft.currencyCode],
      );
      if (updated == 0) {
        throw StateError('العملة ${draft.currencyCode} غير موجودة');
      }
      final currencyRows = await txn.rawQuery(
        'SELECT id FROM currency WHERE code = ? AND is_base = 1',
        [draft.currencyCode],
      );
      final currencyId = currencyRows.first['id'] as int;

      // 2) المنشأة.
      final companyId = await txn.insert('company', {
        'name': draft.companyName,
        'phone': draft.phone,
        'currency_id': currencyId,
        'tax_rate': draft.taxRate,
        'invoice_prefix': 'INV',
        'created_at': iso,
        'updated_at': iso,
        'created_by': null,
      });

      // 3) المخزن الرئيسي (invoice.warehouse_id NOT NULL — بدونه تفشل
      //    أول فاتورة — جوهر FR-13-01).
      await txn.insert('warehouse', {
        'name': draft.warehouseName,
        'is_default': 1,
        'created_at': iso,
        'updated_at': iso,
      });

      // 4) الصندوق الرئيسي بالعملة الأساسية.
      final cashboxId = await txn.insert('cashbox', {
        'name': draft.cashboxName,
        'currency_id': currencyId,
        'is_default': 1,
        'created_at': iso,
        'updated_at': iso,
      });

      // 5) مدير واحد (V1 — FR-12-01) بـ PIN مهشَّر.
      final adminId = await txn.insert('app_user', {
        'username': 'admin',
        'display_name': draft.adminDisplayName,
        'role': 'admin',
        'pin_hash': draft.pinHash,
        'default_cashbox_id': cashboxId,
        'is_active': 1,
        'created_at': iso,
        'updated_at': iso,
      });

      // 6) السنة المالية الحالية (مفتوحة).
      await txn.insert('fiscal_year', {
        'year': draft.fiscalYear,
        'start_date': _dateOnly(draft.fiscalStart),
        'end_date': _dateOnly(draft.fiscalEnd),
        'status': 'open',
        'created_at': iso,
        'updated_at': iso,
      });

      // 7) مُتحقق عبارة المرور (حالة أمان نظامية — ليست إعداداً قابلاً
      //    للضبط؛ تُستخدم عند قفل 10 محاولات — AC-15).
      await txn.insert('settings', {
        'key': 'security.passphrase_hash',
        'value': '"${draft.passphraseHash}"',
        'updated_at': iso,
      });

      // 8) قيد تدقيق للتأسيس (audit_log محمي بـ triggers — إضافة فقط).
      await txn.insert('audit_log', {
        'user_id': adminId,
        'action': 'app_setup',
        'entity': 'company',
        'entity_id': companyId,
        'details': draft.companyName,
        'at': iso,
      });

      return Company(
        id: companyId,
        name: draft.companyName,
        currencyId: currencyId,
        phone: draft.phone,
        taxRate: draft.taxRate,
      );
    });
  }

  /// معرّف المخزن الافتراضي (أنشأه التأسيس — FR-13-01).
  ///
  /// واجهات V1 تشغّل مستودعاً واحداً فاعلياً؛ هذه القراءة هي المدخل
  /// الموحّد له (بنية تعدد المخازن باقية في البيانات لـ V1.1).
  Future<int?> findDefaultWarehouseId() async {
    final rows = await _db.query(
      'warehouse',
      columns: ['id'],
      where: 'is_default = 1 AND is_archived = 0',
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  /// معرّف الصندوق الافتراضي (أنشأه التأسيس بالعملة الأساسية).
  Future<int?> findDefaultCashboxId() async {
    final rows = await _db.query(
      'cashbox',
      columns: ['id'],
      where: 'is_default = 1 AND is_archived = 0',
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  /// مستخدم المدير الوحيد (V1 — FR-12-01) لربط قيود التدقيق بالمنفّذ.
  Future<int?> findAdminUserId() async {
    final rows = await _db.query(
      'app_user',
      columns: ['id'],
      where: "role = 'admin' AND is_active = 1",
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }
}

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// خطأ تنفيذ التأسيس موصوفاً بكلمات المستخدم (نمط §6.3).
Result<T, DomainError> setupError<T>(Object error) => Err(
  DomainError(
    'تعذّر إتمام التأسيس: $error. تحقق من البيانات وأعد المحاولة، '
    'ولم يُكتب أي شيء في القاعدة.',
    actionLabel: 'إعادة المحاولة',
  ),
);
