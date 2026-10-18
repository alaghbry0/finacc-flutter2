/// مستودع عروض الأسعار — جداول `quotation` / `quotation_item`
/// (§5.3 / FR-02-11) — المرحلة 4.
///
/// وحدات التنفيذ مستخرجة إلى `quotation/` بجواره (R20-D3a — نمط تقسيم
/// R19-D3d): إنشاء العرض بقراراته الثلاثة (`quotation_create_flow.dart`
/// — **المعاملة كاملة داخل ملف واحد**) والتحويل إلى فاتورة بذرّيته عبر
/// postSale (`quotation_convert_flow.dart`) وحالات المستند بمعاملتها
/// (`quotation_status_flow.dart`) والقراءات (`quotation_queries.dart`)
/// ومساعد خطأ القاعدة (`quotation_helpers.dart`) — هذا الصنف واجهة تفويض
/// رقيقة بتواقيعه العامة نفسها ومُنشئه الحقّي (يركّب مستودعي الصرف
/// والإعدادات ومحرك البيع فوق نفس القاعدة).
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/core/result.dart';
import '../../domain/models/quotation.dart';
import '../../domain/models/sale.dart';
import 'exchange_rate_repository.dart';
import 'quotation/quotation_convert_flow.dart';
import 'quotation/quotation_create_flow.dart';
import 'quotation/quotation_queries.dart';
import 'quotation/quotation_status_flow.dart';
import 'sale_repository.dart';
import 'settings_repository.dart';

/// مستودع عروض الأسعار: إنشاء/عرض/إرسال/إلغاء/تحويل إلى فاتورة.
class QuotationRepository {
  /// يركّب مستودعي الصرف والإعدادات (سياسة FR-08-09) ومحرك البيع
  /// (التحويل) فوق نفس القاعدة.
  QuotationRepository(Database db)
    : _db = db,
      _rates = ExchangeRateRepository(db),
      _settings = SettingsRepository(db),
      _sales = SaleRepository(db);

  final Database _db;
  final ExchangeRateRepository _rates;
  final SettingsRepository _settings;
  final SaleRepository _sales;

  // ─────────────────────────────────────────────────────────────────────
  // الإنشاء (FR-02-11)
  // ─────────────────────────────────────────────────────────────────────

  /// **إنشاء عرض سعر ذرّياً**: رقم QTE + الرأس + البنود + قيد تدقيق —
  /// **بلا أي حركة مخزون أو صندوق** (مستند غير ملزم).
  Future<Result<Quotation, String>> createQuotation(
    QuotationDraft draft, {
    required int userId,
    DateTime? now,
  }) async => createQuotationFlow(
    _db,
    _rates,
    _settings,
    draft,
    userId: userId,
    now: now,
  );

  // ─────────────────────────────────────────────────────────────────────
  // التحويل إلى فاتورة (FR-02-11 / AC-17) — ذرّية عبر postSale
  // ─────────────────────────────────────────────────────────────────────

  /// **تحويل عرض سعر إلى فاتورة بيع مكتملة بضغطة واحدة**.
  ///
  /// يبني `SaleDraft` من بنود العرض بنفس أسعارها وخصومها الفعلية المخزنة
  /// (الخصوم الموزعة pro-rata وقت الإنشاء تُنقل حرفياً كخصومات مبالغ —
  /// الأرقام النهائية تتطابق بالتساوي) وينادي `postSale` بـ
  /// [fromQuotationId] فيتحول العرض إلى `converted` داخل نفس معاملة
  /// الفاتورة.
  ///
  /// - [paidCash] الجزء النقدي (0 = آجل كامل).
  /// - [paymentMethod] اختياري: `null` → استنتاج من paidCash مقابل صافي
  ///   العرض (نقدي/آجل/مختلط — FR-02-03).
  /// - [issuedAt] تاريخ الفاتورة (افتراضياً [now]) — سعر صرف الفاتورة
  ///   يُحل ليومه لا يوم العرض (FR-08-05).
  Future<Result<SalePostedReceipt, String>> convertToInvoice(
    int quotationId, {
    required double paidCash,
    SalePaymentMethod? paymentMethod,
    required int userId,
    DateTime? now,
    DateTime? issuedAt,
  }) async => convertToInvoiceFlow(
    _db,
    _sales,
    quotationId,
    paidCash: paidCash,
    paymentMethod: paymentMethod,
    userId: userId,
    now: now,
    issuedAt: issuedAt,
  );

  // ─────────────────────────────────────────────────────────────────────
  // حالات المستند
  // ─────────────────────────────────────────────────────────────────────

  /// تعليم العرض «مُرسَلاً» (draft → sent فقط) + قيد تدقيق.
  Future<Result<Quotation, String>> markSent(
    int id, {
    required int userId,
    DateTime? now,
  }) => quotationChangeStatus(
    _db,
    id,
    from: const ['draft'],
    to: QuotationStatus.sent,
    action: 'quotation_sent',
    userId: userId,
    now: now,
  );

  /// إلغاء العرض (draft/sent → rejected) + قيد تدقيق — لا يمس غيره.
  ///
  /// **خرائط المخطط المجمد**: قيد CHECK على `quotation.status` لا يشمل
  /// `cancelled`، فيُخزّن الإلغاء كـ `rejected` (أقرب دلالة متاحة بلا
  /// هجرة) — الفرق الدلالي (إلغاء بيد البائع مقابل رفض العميل) يوثّق
  /// في قيد التدقيق `quotation_cancel`.
  Future<Result<Quotation, String>> cancelQuotation(
    int id, {
    required int userId,
    DateTime? now,
  }) => quotationChangeStatus(
    _db,
    id,
    from: const ['draft', 'sent'],
    to: QuotationStatus.rejected,
    action: 'quotation_cancel',
    userId: userId,
    now: now,
  );

  // ─────────────────────────────────────────────────────────────────────
  // القراءات
  // ─────────────────────────────────────────────────────────────────────

  /// قائمة العروض (الأحدث أولاً) بتصفية العميل/الحالة وحد أعلى.
  Future<List<QuotationSummary>> listQuotations({
    int? customerId,
    QuotationStatus? status,
    int limit = 50,
  }) async => quotationSummaries(
    _db,
    customerId: customerId,
    status: status,
    limit: limit,
  );

  /// تفاصيل عرض كامل: الرأس + البنود + أسماء العميل/العملة.
  Future<QuotationDetail?> quotationDetail(int id) async =>
      quotationDetailById(_db, id);
}
