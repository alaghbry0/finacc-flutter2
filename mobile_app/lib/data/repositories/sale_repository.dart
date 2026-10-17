/// محرك ترحيل فاتورة البيع الذرّي — جداول `invoice` / `invoice_item` /
/// `stock_level` / `stock_movement` / `batch` / `cash_tx` /
/// `payment_allocation` / `quotation` — المرحلة 4 (FR-02 / FR-08-09).
///
/// **الخريطة الملزمة** (قاعدة 5.4-4 + ملحق و): الحفظ = (رقم INV ذرّي +
/// الفاتورة + بنودها بـ line_cost=WAC + خصم المخزون مع FEFO + حركات
/// المخزون + حركة الصندوق للجزء النقدي + تخصيص المدفوع + تعليم عرض
/// السعر المحوَّل + قيد التدقيق) داخل **Transaction واحدة** — فشل أي خطوة
/// يرجع الكل (AC-09-أ).
///
/// خطوط حمراء مطبَّقة هنا:
/// - **منع السالب المخزوني** (5.4-5): فحص مسبق قبل المعاملة + حارس
///   `WHERE qty >= ?` داخلها — رسالة الرفض تسمّي الصنف والكمية المتاحة.
/// - **فصل العملات** (5.4-7): الفاتورة وسندها النقدي وتخصيصها كلها بعملة
///   الفاتورة وسعر يومها (Snapshot FR-08-05)؛ الأساس بالعملة الأساسية
///   يُخزَّن في `total_base` فقط.
/// - **WAC** (5.4-3): البيع **يستهلك** `product.cost_price` ويخزنه في
///   `line_cost` ولا يغيّره أبداً.
/// - **سياسة FX المفقود** (FR-08-09 / AC-13): عملة غير أساس بلا سعر اليوم
///   → رفض، إلا إذا فُعّل `fx.fallback=last_known` فيُستخدم آخر سعر مع
///   `rate_is_fallback=1` (شارة FR-02-20).
///
/// ## قرارات موثقة (انظر worklog-parts/6-b.md للتفصيل):
/// 1. **الباقي للعميل** (`changeDue`): الزيادة النقدية فوق الصافي تُعاد في
///    الإيصال ولا تدخل الصندوق (`cash_tx.amount` = الصافي المدفوع حصراً
///    لأن عموده CHECK(amount > 0) ولا معنى لسند بمبلغ الباقي) ولا الدين.
/// 2. **payment_allocation**: العمود `cash_tx_id` NOT NULL فلا يمكن إدراجه
///    لجزء آجل بلا سند — التخصيص يوثّق **الجزء المدفوع نقداً** وقت
///    الإصدار (سند القبض ← الفاتورة)، والأثر الآجل محفوظ في
///    `invoice.due_amount` وفق اصطلاح CustomerRepository (لا يُنقصه أحد).
///    سند قبض الإصدار يُكتب بـ `customer_id = NULL` حتى لا تخصمه صيغة
///    رصيد العميل (FR-03-02) مرتين.
/// 3. **دفع متعدد الدفعات**: سطر فاتورة واحد لكل سطر سلة؛ تفصيل الدفعات
///    يُسجَّل حركة مخزون مستقلة لكل دفعة (راجعة بالفاتورة) +
///    `invoice_item.batch_id` = أول دفعة FEFO وملخص الدفعات في ملاحظة
///    السطر (AC-05: «أسطر الفاتورة أظهرت رقم الدفعة»).
/// 4. **المسودة (draft)** خارج نطاق هذا المحرك — البناء هنا للمكتملة فقط
///    (`status='completed'` وفق آلة الحالات 5.4-2).
/// 5. **الضريبة** 0% في V1 لهذا المحرك (`tax_rate=0`) — الأعمدة جاهزة
///    بالمخطط ووحدة الضريبة لاحقة.
/// 6. **userId** يُمرَّر صراحة (لا مساعد مستخدم حالي في طبقة البيانات —
///    الطلب مسجَّل في التسليم للمنسّق).
/// 7. **البونص/الكميات المجانية** (موجة UX-4 — القرار التحاسبي الملزم
///    من UX-audit-invoice §3): `CartLine.freeQty` ≥ 0 عمود مستقل
///    `invoice_item.free_qty` (هجرة v5). **المنصرف الكلي = qty + freeQty**
///    (فحص التوفر + FEFO + `line_cost = roundCost(الكل×WAC)` + حركة
///    المخزون −الكل + stock_level)، و**الإيراد من qty حصراً** —
///    subtotal/total/total_base/الائتمان لا ترى البونص إطلاقاً (تسعير
///    `SalePricing` فوق qty وحدها)، فCOGS يرتفع والربح ينخفض بالمقدار
///    الحرفي للمجاني. حركة المخزون وملاحظة السطر تحملان «بونص: N»
///    والتدقيق يسجل `free=`. رسائل العجز تشمل المجاني بالمطلوب.
///
/// ## الإبطال (FR-02-15 — R17-c):
/// `voidInvoice` تُنشئ **حركات معاكسة كاملة** داخل Transaction واحدة —
/// لا حذف فيزيائي لأي صف:
/// - **المخزون**: المنصرف الكلي (qty + freeQty — البونص خرج من المخزون
///   وقت البيع فيُرجَع كاملاً) يعود لمخزن الفاتورة **بتكلفة الوحدة
///   الأصلية** `line_cost ÷ الكلي` (لا WAC جاري — قاعدة 5.4-3 مرآة
///   SRN)، ولدفعات البيع الأصلية نفسها عند تتبعها من حركات البيع
///   (بصيغة ملاحظة الدفعة القائمة)؛ غير المتتبع يُرجَع مخزوناً عاماً.
///   حركة العودة `movement_type='sale_return'` بمرجع الفاتورة المُبطلة.
/// - **الصندوق**: سند قبض الإصدار يُبطَل بنمط `cash_repository.voidMovement`
///   حرفياً (`is_voided=1` على الأصل + سطر معاكس حي مستبعد من الأرصدة
///   عبر `reversal_of`) — فأثر الثنائي على الصندوق صفر. **تخصيصات
///   السندات اللاحقة** (RVT FIFO على الفاتورة) تُسترد بحركة حقيقية
///   معاكسة الاتجاه (محسوبة في الأرصدة) + حذف رابط `payment_allocation`
///   + عكس نصيب الفاتورة من `fx_gain_loss` — فالصندوق يعود لما قبل
///   الفاتورة كاملة.
/// - **رصيد العميل**: `status='void'` يستبعد الفاتورة من صيغة الرصيد
///   (FR-03-02 تعدّ `status='completed'` حصراً) فتُعاد قيمته دون أي
///   كتابة إضافية — لا `due_amount` يُمسّ (لقطة تاريخية للسجل).
/// - **الحارسان**: مكتملة حصراً (completed → void — آلة الحالات 5.4-2)،
///   و**رفض قطعي إن وُجدت مرتجعات مكتملة مرتبطة** (يُلغى المرتجع
///   أولاً — FR-02-15) + حراسة حالة داخل المعاملة (التزامن).
/// - **audit**: `action='void_invoice'` برقم الفاتورة والسبب والقيم
///   المعكوسة. **الرقم لا يُعاد** (doc_sequence تصاعدية دائماً).
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import '../../domain/models/invoice_void.dart';
import '../../domain/models/sale.dart';
import 'batch_repository.dart';
import 'customer_repository.dart';
import 'exchange_rate_repository.dart';
import 'sale/sale_post_flow.dart';
import 'sale/sale_reads.dart';
import 'sale/sale_void_flow.dart';
import 'settings_repository.dart';

// ─────────────────────────────────────────────────────────────────────
// المستودع — واجهة ثابتة تفوّض إلى الملفات المركزة بمجلد sale/
// (تقسيم R18-D3a: الأنواع + الاستعلامات + تدفقا الترحيل والإبطال +
// القراءات — بلا أي تغيير سلوك أو توقيع عام أو SQL).
// ─────────────────────────────────────────────────────────────────────

/// مستودع المبيعات — ترحيل POS الذرّي وقراءات الفواتير.
class SaleRepository {
  /// يبنى فوق قاعدة مفتوحة؛ يركّب المستودعات الشريكة (تواقيعها ملزمة)
  /// فوق نفس القاعدة دون إعادة إنشاء.
  SaleRepository(Database db)
    : _db = db,
      _rates = ExchangeRateRepository(db),
      _settings = SettingsRepository(db),
      _customers = CustomerRepository(db),
      _batches = BatchRepository(db);

  final Database _db;
  final ExchangeRateRepository _rates;
  final SettingsRepository _settings;
  final CustomerRepository _customers;
  final BatchRepository _batches;

  /// معاينة رقم INV القادم للسنة (آخر مُصدر + 1) — عرضٌ فقط بلا استهلاك؛
  /// الترقيم الحقيقي يستهلك ذرّياً داخل معاملة الترحيل نفسها.
  ///
  /// (R18-D1: كان هذا المنطق داخل نموذج سلة الكاشير — نُقل للمستودع
  /// ليبقى لمس `core/storage/doc_sequence` في طبقة البيانات حصراً.)
  Future<String> previewNextInvoiceNo(int year) async =>
      previewSaleInvoiceNo(_db, year);

  // ─────────────────────────────────────────────────────────────────────

  /// **ترحيل فاتورة بيع مكتملة** — معاملة واحدة (انظر رأس الملف للخريطة).
  ///
  /// [userId] منفّذ العملية (يُخزَّن في created_by والتدقيق).
  /// [now] لحظة الكتابة الفعلية (created_at/updated_at/audit) — تاريخ
  /// العمل `draft.issuedAt` وحده يحدد سنة الترقيم وسعر الصرف.
  ///
  /// الترتيب: تحقّق نقّي → تحميلات مسبقة (عملة/سياسة FX/أصناف/مخزون/
  /// ائتمان/صندوق) → معاملة واحدة (رقم ← فاتورة ← بنود + WAC + FEFO +
  /// مخزون ← نقدي ← تخصيص ← ربط عرض السعر ← تدقيق) → إيصال.
  Future<Result<SalePostedReceipt, String>> postSale(
    SaleDraft draft, {
    required int userId,
    DateTime? now,
  }) async => postSaleFlow(
    _db,
    _rates,
    _settings,
    _customers,
    _batches,
    draft,
    userId: userId,
    now: now,
  );

  // ─────────────────────────────────────────────────────────────────────

  /// **إبطال فاتورة بيع مكتملة** — معاملة واحدة (انظر رأس الملف § الإبطال).
  ///
  /// [userId] منفّذ الإبطال (المدير — الصلاحية تُحسم في الواجهة)
  /// و[reason] سبب اختياري يُخزَّن في قيد التدقيق وحده.
  ///
  /// الترتيب: تحققات مسبقة (نوع/حالة/مرتجعات) → معاملة واحدة (حرارة
  /// الحالة ← عكس المخزون ودفعاته ← إبطال سند الإصدار وسطره المعاكس ←
  /// استرداد تخصيصات السندات اللاحقة ← `status='void'` ← تدقيق) → إيصال.
  Future<Result<VoidInvoiceReceipt, String>> voidInvoice(
    int invoiceId, {
    required int userId,
    String? reason,
    DateTime? now,
  }) async => voidSaleInvoiceFlow(
    _db,
    invoiceId,
    userId: userId,
    reason: reason,
    now: now,
  );

  // ─────────────────────────────────────────────────────────────────────

  /// تفاصيل فاتورة بيع كاملة: الرأس + البنود + اسم العميل + العملة.
  ///
  /// `null` إن لم توجد (أو ليست فاتورة بيع).
  Future<SaleInvoiceDetail?> invoiceDetail(int invoiceId) async =>
      saleInvoiceDetail(_db, invoiceId);

  /// آخر فواتير البيع (الأحدث أولاً) — لتقرير/بحث الشاشات.
  Future<List<SaleInvoiceSummary>> recentSales({
    int limit = 50,
    int? customerId,
  }) async => recentSalesList(_db, limit: limit, customerId: customerId);

  /// إجماليات مبيعات فترة (شاملة الطرفين) — بالعملة الأساسية عبر
  /// `total_base` (نفس أساس DashboardRepository — FR-09-01).
  Future<SalesPeriodTotals> salesTotals(DateTime from, DateTime to) async =>
      salesTotalsForPeriod(_db, from, to);
}
