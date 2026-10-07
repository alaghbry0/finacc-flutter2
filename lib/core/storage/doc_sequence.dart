/// الترقيم الذري للمستندات — SRS v1.5 §5.4-1 + ملحق د.
///
/// القاعدة الملزمة:
/// - كل مستند يُرقَّم تلقائياً بصيغة `PREFIX-YYYY-NNNNN` عبر `doc_sequence`.
/// - الاستهلاك داخل **Transaction الحفظ نفسها** (UPSERT ذرّي) — **يُمنع MAX+1**.
/// - لا إعادة استخدام للأرقام أبداً (الفراغ مسموح؛ الإلغاء لا يُعيد الرقم).
///
/// تنفيذ ملاحظ على توافق إصدارات SQLite:
/// - المسار الأساسي: UPSERT بعبارة واحدة (`ON CONFLICT DO UPDATE`) — يتطلب
///   SQLite ≥ 3.24 (متوفر عبر sqlite3.wasm في المعاينة الويب، وسلسلة أدوات
///   الاختبار FFI، وأندرويد 10+).
/// - المسار الاحتياطي (أجهزة أندرويد 8/9 القديمة — NFR-07): ثلاث عبارات
///   (`INSERT OR IGNORE` → `UPDATE +1` → `SELECT`) داخل نفس الـ Transaction
///   التي تفتحها sqflite بـ `BEGIN IMMEDIATE` — ذرّيتها مكفولة بتسلسل
///   الكُتّاب في SQLite، ونتيجتها مطابقة للمسار الأساسي.
///
/// كلا المسارين لا يستخدمان `MAX+1` إطلاقاً (المصدر هو عدّاد `last_no`
/// في صفّ الجدول نفسه).
library;

import 'package:sqflite/sqflite.dart';

/// أنواع المستندات المرقّمة — ملحق د (SRS v1.5).
///
/// الرمز المُخزَّن في عمود `doc_sequence.doc_type` هو بادئة المستند نفسها.
enum DocSequenceType {
  /// فاتورة بيع — `INV-YYYY-NNNNN`.
  invoice('INV'),

  /// عرض سعر — `QTE-YYYY-NNNNN`.
  quotation('QTE'),

  /// فاتورة شراء — `PUR-YYYY-NNNNN`.
  purchase('PUR'),

  /// مرتجع بيع — `SRN-YYYY-NNNNN`.
  saleReturn('SRN'),

  /// مرتجع شراء — `PRN-YYYY-NNNNN`.
  purchaseReturn('PRN'),

  /// سند قبض — `RVT-YYYY-NNNNN`.
  receiptVoucher('RVT'),

  /// سند صرف — `PMT-YYYY-NNNNN`.
  paymentVoucher('PMT');

  const DocSequenceType(this.prefix);

  /// بادئة المستند كما تظهر في الرقم الكامل.
  final String prefix;
}

/// أداء الترقيم الذرّي فوق قاعدة بيانات مفتوحة أو معاملة نشطة.
class DocSequenceService {
  /// ينشئ الخدمة فوق قاعدة بيانات أو فوق `Transaction` نشطة.
  ///
  /// عند تمرير [Database] يُغلَّف كل استهلاك تلقائياً بمعاملة فورية خاصة
  /// به (ذرّية مستقلة). أما عند إنشاء الخدمة فوق معاملة الحفظ نفسها
  /// (النمط الملزم عند إصدار مستند) فيُنفَّذ الاستهلاك داخلها مباشرة.
  ///
  /// [forceLegacyPath] يجبر المسار الاحتياطي — لاختبارات الوحدة على
  /// المسارين معاً.
  DocSequenceService(this._db, {bool forceLegacyPath = false})
    : _forceLegacy = forceLegacyPath;

  final DatabaseExecutor _db;
  final bool _forceLegacy;
  bool? _supportsUpsert;

  /// يستهلك الرقم التالي لنوع مستند في سنة معينة **ذرّياً** ويعيده.
  Future<int> nextNumber(DocSequenceType type, int year) async {
    final executor = _db;
    if (executor is Database) {
      // BEGIN IMMEDIATE — قفل الكتابة مقدماً؛ تسلسل كامل مع أي كاتب متوازٍ.
      return executor.transaction((txn) => _consume(txn, type, year));
    }
    // داخل Transaction المتصل — نفس الذرّية ضمن معاملة الحفظ.
    return _consume(executor, type, year);
  }

  /// يقرأ آخر رقم استُهلك (دون استهلاك) — للعرض والإعدادات.
  Future<int> lastIssuedNumber(DocSequenceType type, int year) async {
    final rows = await _db.rawQuery(
      'SELECT last_no FROM doc_sequence WHERE doc_type = ? AND year = ?',
      [type.prefix, year],
    );
    if (rows.isEmpty) return 0;
    return rows.first['last_no'] as int;
  }

  /// يضبط رقم البداية لنوع مستند — **مسموح فقط قبل إصدار أول مستند من
  /// نوعه** (FR-13-02). يرمي [StateError] خلاف ذلك.
  Future<void> setStartNumber(
    DocSequenceType type,
    int year,
    int startNumber,
  ) async {
    if (startNumber < 1) {
      throw ArgumentError('رقم البداية يجب أن يكون ≥ 1');
    }
    final last = await lastIssuedNumber(type, year);
    if (last > 0) {
      throw StateError(
        'لا يمكن تعديل رقم البداية بعد إصدار أول مستند من هذا النوع '
        '($type ${type.prefix}-$year) — تحرير الرقم معطل دائماً.',
      );
    }
    await _db.rawInsert(
      'INSERT INTO doc_sequence(doc_type, year, last_no) VALUES(?, ?, ?) '
      'ON CONFLICT(doc_type, year) DO UPDATE SET last_no = excluded.last_no',
      [type.prefix, year, startNumber - 1],
    );
  }

  Future<int> _consume(
    DatabaseExecutor executor,
    DocSequenceType type,
    int year,
  ) async {
    final docType = type.prefix;
    if (await _useUpsert(executor)) {
      // المسار الأساسي — UPSERT ذرّي بعبارة واحدة.
      await executor.execute(
        'INSERT INTO doc_sequence(doc_type, year, last_no) VALUES(?, ?, 1) '
        'ON CONFLICT(doc_type, year) DO UPDATE SET last_no = doc_sequence.last_no + 1',
        <Object>[docType, year],
      );
    } else {
      // المسار الاحتياطي — ثلاث عبارات داخل نفس المعاملة الفورية.
      await executor.execute(
        'INSERT OR IGNORE INTO doc_sequence(doc_type, year, last_no) '
        'VALUES(?, ?, 0)',
        <Object>[docType, year],
      );
      await executor.execute(
        'UPDATE doc_sequence SET last_no = last_no + 1 '
        'WHERE doc_type = ? AND year = ?',
        <Object>[docType, year],
      );
    }
    // القراءة داخل نفس المعاملة ترى كتابتها الخاصة — القيمة مملوكة لهذه
    // المعاملة حصراً (تسلسل الكُتّاب في SQLite يمنع أي تداخل).
    final rows = await executor.rawQuery(
      'SELECT last_no FROM doc_sequence WHERE doc_type = ? AND year = ?',
      <Object>[docType, year],
    );
    return rows.first['last_no'] as int;
  }

  Future<bool> _useUpsert(DatabaseExecutor executor) async {
    if (_forceLegacy) return false;
    final cached = _supportsUpsert;
    if (cached != null) return cached;
    final rows = await executor.rawQuery('SELECT sqlite_version() AS v');
    final version = (rows.first['v'] as String?) ?? '3.0';
    final parts = version.split('.');
    final major = int.tryParse(parts.isNotEmpty ? parts[0] : '3') ?? 3;
    final minor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final supported = major > 3 || (major == 3 && minor >= 24);
    _supportsUpsert = supported;
    return supported;
  }
}

/// صيغة الرقم الكامل: `PREFIX-YYYY-NNNNN` (خمس خانات مُصفَّرة يساراً).
String formatDocNumber(DocSequenceType type, int year, int number) {
  final padded = number.toString().padLeft(5, '0');
  return '${type.prefix}-$year-$padded';
}
