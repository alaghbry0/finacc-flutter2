/// محرك النقدية والصناديق — جداول `cashbox` / `cash_tx` /
/// `expense_category` / `payment_allocation` — الوحدة 04 (FR-04).
///
/// **الخريطة الملزمة** (ملحق و + قواعد 5.4-1/4/6/7): كل كتابة معاملة
/// ذرّية واحدة (سند مرقّم RVT/PMT عبر doc_sequence + الحركة + تحديث
/// دفاتر الفواتير المخصصة + قيد التدقيق) — فشل أي خطوة يرجع الكل.
///
/// ## إشارات الأرصدة (ملحق و — حرفياً):
/// - **وارد (+) على `cashbox_id`**: receipt / capital_in / opening.
/// - **صادر (−) على `cashbox_id`**: payment / expense / owner_draw.
/// - **ذات الساقين** (box_transfer / bank_deposit / bank_withdraw):
///   `cashbox_id` = المصدر (−) و`to_cashbox_id` = الهدف (+ بالمبلغ
///   المحوّل `amount × settlement_rate` بعملة الهدف لحظة التحويل —
///   FR-04-07). البنك مجرد صندوق أنشأه المستخدم باسم بنك.
/// - **`is_voided = 1` تُستبعد دائماً** من كل الأرصدة، **والحركات
///   المعاكسة** (`reversal_of` غير فارغ) تُستبعد كذلك — فأثر الثنائي
///   (الأصل + معاكسته) على الأرصدة صفر، والمعاكسة تبقى ظاهرة في
///   السجل للتدقيق (FR-04-08).
/// - الرصيد **يجوز أن يكون سالباً** (FR-04-09) — التحذير مسؤولية
///   الواجهة، لا منع هنا أبداً.
///
/// ## اصطلاحات موثقة (قرارات معمارية لهذه الشريحة):
/// 1. **دلاء العملة**: رصيد الصندوق يُحسب **لكل عملة على حدة** (فصل
///    العملات 5.4-7): الحركة بعملة الصندوق تدلو عملتها، والساق الواردة
///    للتحويل تدلو عملة الهدف، وسند العملة المخالفة لعملة صندوقه
///    (`settlement_rate`) يدلو عملة الصندوق بالمبلغ المحوّل.
/// 2. **السند المخصص (FIFO)** يتبع حرفياً نمط تحصيل الإصدار في
///    `sale_repository`: تحديث `invoice.due_amount/paid_amount` +
///    صفوف `payment_allocation` + `customer_id/supplier_id = NULL`
///    (حتى لا تخصمه صيغ رصيد الطرف مرتين — نفس القرار الموثق هناك).
///    **السند الحر** «على الحساب» يحمل `customer_id/supplier_id` فيخصم
///    من رصيد الطرف مباشرة عبر صيغ FR-03-02/03 القائمة (`ref_type=
///    'on_account'`).
/// 3. **المديونية المفتوحة** لفاتورة = `due_amount − Σ تخصيصات السندات
///    المرقمة الحية عليها` — تخصيص الإصدار/المرتجع (`voucher_no` فارغ)
///    مستهلك داخل `due_amount` أصلاً فلا يُخصم مرتين (قاعدة 5.4-6).
/// 4. **السند بعملة مخالفة لعملة الصندوق** (عملة الطرف عبر صندوق مختلف
///    العملة): `currency_id` = عملة السند، `amount` = مبلغ الدين
///    المُسدَّد، `exchange_rate` = سعر يوم السند، `settlement_rate` =
///    (سعر عملة السند ÷ سعر عملة الصندوق) — وهو ما يُودع فعلياً في
///    الصندوق (`amount × settlement_rate` بعملة الصندوق) — والفرق عن
///    القيمة الدفترية للدين (`invoice.exchange_rate`) في `fx_gain_loss`
///    **بالعملة الأساسية** (قاعدة 5.4-7: «يُحسب الفرق في fx_gain_loss»).
/// 5. **التحويل بعملتين**: صف واحد بمبلغ المصدر؛ الهدف يستقبل
///    `amount × settlement_rate` بعملته؛ `fx_gain_loss` = (قيمة الوارد
///    بالأساس) − (قيمة الخارج بالأساس) — صفر عند التحويل بسعر اليوم
///    (فرق الصرّاف يُسجَّل مصروفاً مستقلاً إذا لزم — قرار V1).
/// 6. **الإبطال** (FR-04-08): لا حذف ولا تعديل — حركة معاكسة داخل
///    معاملة واحدة + `is_voided=1` على الأصل + استرجاع دفاتر الفواتير
///    وحذف روابط `payment_allocation` (رابط تخصيص لا حركة مالية) +
///    قيد تدقيق. **الرقم المرقّم لا يُعاد أبداً** (استمرارية الترقيم).
///    الحركات المرتبطة بمستند آخر (تحصيل الإصدار/رد المرتجع —
///    `ref_type='invoice'` مع `ref_id`) تُبطل عبر مستنداتها لا هنا.
/// 7. **سياسة FX المفقود** (FR-08-09): عملة غير الأساس بلا سعر اليوم →
///    رفض، إلا `fx.fallback=last_known` فيُستخدم آخر سعر معروف —
///    نفس نمط البيع/الشراء حرفياً.
/// 8. الوردية (shift) مؤجلة للشريحة 9 — لا كتابة لها هنا.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import '../../domain/models/cash.dart';
import 'cash/cash_box_ops.dart';
import 'cash/cash_category_ops.dart';
import 'cash/cash_quick_flows.dart';
import 'cash/cash_reads.dart';
import 'cash/cash_voucher_flow.dart';
import 'cash/cash_void_flow.dart';
import 'exchange_rate_repository.dart';
import 'settings_repository.dart';

// ─────────────────────────────────────────────────────────────────────
// المستودع — واجهة ثابتة تفوّض إلى الملفات المركزة بمجلد cash/
// (تقسيم R18-D3a: الأنواع + المساعدات + العمليات + التدفقات + القراءات
// — بلا أي تغيير سلوك أو توقيع عام أو SQL).
// ─────────────────────────────────────────────────────────────────────

/// مستودع النقدية — الصناديق والفئات والسندات والحركات والإبطال.
class CashRepository {
  /// يبنى فوق قاعدة مفتوحة؛ يركّب المستودعات الشريكة فوق نفس القاعدة.
  CashRepository(Database db)
    : _db = db,
      _rates = ExchangeRateRepository(db),
      _settings = SettingsRepository(db);

  final Database _db;
  final ExchangeRateRepository _rates;
  final SettingsRepository _settings;

  // ─────────────────────────────────────────────────────────────────────

  /// بذر **idempotent** لفئة «رواتب» (بديل وحدة الموظفين المؤجلة —
  /// SRS §9) — يُستدعى عند إقلاع الجلسة؛ التنفيذ شرطي فلا يكرر أبداً.
  Future<void> ensureSeeded() async => seedCashRepository(_db);

  /// فئات المصاريف (FR-04-05) — «رواتب» أولاً ومحمية من الأرشفة.
  Future<List<ExpenseCategoryInfo>> listCategories({
    bool includeArchived = false,
  }) async => listExpenseCategories(_db, includeArchived: includeArchived);

  /// إضافة فئة — الاسم المكرر المؤرشف يُوقظ بدل الرفض (إضافة idempotent).
  Future<Result<ExpenseCategoryInfo, String>> addCategory(String name) async =>
      addExpenseCategory(_db, name);

  /// إعادة تسمية فئة.
  Future<Result<ExpenseCategoryInfo, String>> renameCategory(
    int id,
    String name,
  ) async => renameExpenseCategory(_db, id, name);

  /// أرشفة فئة — «رواتب» محمية (بديل V1 لوحدة الموظفين).
  Future<Result<void, String>> archiveCategory(int id) async =>
      archiveExpenseCategory(_db, id);

  /// إلغاء أرشفة فئة.
  Future<Result<void, String>> unarchiveCategory(int id) async =>
      unarchiveExpenseCategory(_db, id);

  // ─────────────────────────────────────────────────────────────────────

  /// الصناديق بأرصدتها الحية — رصيد بعملة الصندوق + دلاء العملات الأخرى
  /// (إشارات ملحق و — انظر رأس الملف). السالب مسموح ويعود للواجهة.
  Future<List<CashboxWithBalance>> listBoxes({
    bool includeArchived = false,
  }) async => listBoxesWithBalances(_db, includeArchived: includeArchived);

  /// إضافة صندوق — العملة من عملات المنشأة (FR-04-01).
  Future<Result<CashboxInfo, String>> addBox(
    String name,
    int currencyId, {
    bool makeDefault = false,
    int? userId,
  }) async => addCashbox(
    _db,
    name,
    currencyId,
    makeDefault: makeDefault,
    userId: userId,
  );

  /// إعادة تسمية صندوق.
  Future<Result<void, String>> renameBox(int id, String name) async =>
      renameCashbox(_db, id, name);

  /// أرشفة صندوق (FR-04-01) — يُمنع الأرشفة للصندوق الافتراضي ولآخر
  /// صندوق نشط؛ الرصيد غير الصفري **لا يُمنع** (FR-04-09) لكن الواجهة
  /// تطلب تأكيداً صريحاً قبلها.
  Future<Result<void, String>> archiveBox(int id, {int? userId}) async =>
      archiveCashbox(_db, id, userId: userId);

  /// إلغاء أرشفة صندوق.
  Future<Result<void, String>> unarchiveBox(int id) async =>
      unarchiveCashbox(_db, id);

  /// تعيين الصندوق الافتراضي (FR-04-01) — ذرّياً (واحد فقط افتراضي).
  Future<Result<void, String>> setDefaultBox(int id, {int? userId}) async =>
      setDefaultCashbox(_db, id, userId: userId);

  // ─────────────────────────────────────────────────────────────────────

  /// الفواتير المفتوحة لطرف بعملة — الأقدم أولاً (FIFO).
  ///
  /// المتبقي = `due_amount − تخصيصات السندات المرقمة الحية` (القرار 3).
  Future<List<OpenInvoiceLine>> openInvoicesForParty({
    required VoucherPartyType partyType,
    required int partyId,
    required int currencyId,
  }) async => partyOpenInvoices(
    _db,
    partyType: partyType,
    partyId: partyId,
    currencyId: currencyId,
  );

  // ─────────────────────────────────────────────────────────────────────

  /// معاينة رقم RVT/PMT القادم للسنة (آخر مُصدر + 1) — عرضٌ فقط بلا
  /// استهلاك؛ الترقيم الحقيقي يستهلك ذرّياً داخل معاملة ترحيل السند
  /// نفسها (قاعدة 5.4-1). مرآة لنمط `previewNextInvoiceNo` في المبيعات.
  ///
  /// [isReceipt]: سند قبض (RVT) أم صرف (PMT). [year]: سنة تاريخ السند
  /// `txDate.year` — لا سنة اليوم — لأن الترحيل يرقّم بسنة `txDate`
  /// نفسها فيتطابق المعروض مع المرقَّم عند الحفظ.
  Future<String> previewNextVoucherNo({
    required bool isReceipt,
    required int year,
  }) async => previewVoucherNo(_db, isReceipt: isReceipt, year: year);

  /// **ترحيل سند قبض/صرف** — معاملة ذرّية واحدة: رقم RVT/PMT + حركة
  /// الصندوق + تحديث دفاتر الفواتير المخصصة (FIFO) + صفوف التخصيص +
  /// قيد التدقيق (الخريطة برأس الملف — القرارات 2/3/4).
  Future<Result<VoucherPostedReceipt, String>> createVoucher(
    VoucherDraft draft, {
    required int userId,
    DateTime? now,
  }) async => createVoucherFlow(
    _db,
    _rates,
    _settings,
    draft,
    userId: userId,
    now: now,
  );

  // ─────────────────────────────────────────────────────────────────────

  /// مصروف — فئة إلزامية (FR-04-03: مصروف ← فئة مصروف).
  Future<Result<QuickMovementReceipt, String>> createExpense(
    QuickMovementDraft draft, {
    required int userId,
    DateTime? now,
  }) async => createExpenseFlow(
    _db,
    _rates,
    _settings,
    draft,
    userId: userId,
    now: now,
  );

  /// مسحوبات المالك (owner_draw) — بند مستقل خارج المصاريف (ملحق و).
  Future<Result<QuickMovementReceipt, String>> createOwnerDraw(
    QuickMovementDraft draft, {
    required int userId,
    DateTime? now,
  }) => createOwnerDrawFlow(
    _db,
    _rates,
    _settings,
    draft,
    userId: userId,
    now: now,
  );

  /// إيداع المالك (capital_in) — رأس مال.
  Future<Result<QuickMovementReceipt, String>> createCapitalIn(
    QuickMovementDraft draft, {
    required int userId,
    DateTime? now,
  }) => createCapitalInFlow(
    _db,
    _rates,
    _settings,
    draft,
    userId: userId,
    now: now,
  );

  /// تحويل بين صندوقين / إيداع بنكي / سحب بنكي — صف واحد بساقين
  /// (القرار 5): المصدر يخرج بمبلغه، والهدف يستقبل المحوّل
  /// `amount × settlement_rate` بعملته (FR-04-07).
  Future<Result<QuickMovementReceipt, String>> createTransfer(
    QuickMovementDraft draft, {
    required int userId,
    DateTime? now,
  }) async => createTransferFlow(
    _db,
    _rates,
    _settings,
    draft,
    userId: userId,
    now: now,
  );

  // ─────────────────────────────────────────────────────────────────────

  /// **إبطال حركة** — معاملة واحدة: حركة معاكسة (بإشارات مستعادة —
  /// للتحويل باعتبار الساقين معكوسة) + `is_voided=1` على الأصل +
  /// استرجاع دفاتر الفواتير + حذف روابط التخصيص + قيد تدقيق.
  ///
  /// القيود: حركة ملغاة/معاكسة لا تُبطل؛ الحركات المرتبطة بمستند آخر
  /// (تحصيل الإصدار/رد المرتجع) تُبطل عبر مستنداتها؛ الأنواع المؤجلة
  /// (V1.1) مرفوضة برسالة واضحة. **الرقم المرقّم لا يُعاد أبداً.**
  Future<Result<int, String>> voidMovement(
    int id, {
    required int userId,
    String? reason,
    DateTime? now,
  }) async =>
      voidCashMovementFlow(_db, id, userId: userId, reason: reason, now: now);

  // ─────────────────────────────────────────────────────────────────────

  /// سجل حركات الصندوق بمرشحات (صندوق/نوع/فترة/بحث نصي في الوصف
  /// والرقم واسم الطرف) — الأحدث أولاً.
  Future<List<CashMovementRow>> journal({
    int? cashboxId,
    String? txType,
    DateTime? from,
    DateTime? to,
    String? search,
    int limit = 300,
  }) async => cashJournal(
    _db,
    cashboxId: cashboxId,
    txType: txType,
    from: from,
    to: to,
    search: search,
    limit: limit,
  );

  /// تفاصيل حركة واحدة + تخصيصاتها — `null` إن لم توجد.
  Future<CashMovementDetail?> movementDetail(int id) async =>
      cashMovementDetail(_db, id);

  /// صافي النقدية لكل عملة (بطاقة المحور) — تجميع دلاء كل الصناديق
  /// بعملة كل دلو (لا خلط عملات — الأمانة المحاسبية 5.4-7).
  Future<List<CashNetLine>> netCashByCurrency() async => cashNetByCurrency(_db);
}
