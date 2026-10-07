/// مستودع عروض الأسعار — جداول `quotation` / `quotation_item`
/// (§5.3 / FR-02-11) — المرحلة 4.
///
/// **عرض السعر مستند غير ملزم**: يُرقَّم `QTE-YYYY-NNNNN` ذرّياً (قاعدة
/// 5.4-1) ولا يخصم مخزوناً ولا يحرك صندوقاً ولا يدين أحداً إطلاقاً —
/// بضعة صفوف مستندية + قيد تدقيق فقط.
///
/// **التحويل إلى فاتورة (AC-17)**: يُبنى `SaleDraft` من بنود العرض بنفس
/// أسعارها وخصومها الفعلية، ثم يُنفَّذ `SaleRepository.postSale` — والربط
/// الذرّي عبر `SaleDraft.fromQuotationId`: تحديث العرض إلى `converted` +
/// `converted_invoice_id` يجري **داخل معاملة postSale نفسها** (فشل أي
/// طرف — مخزون ناقص مثلاً — يرجع الفاتورة والعرض معاً). سعر صرف
/// **الفاتورة** هو سعر يوم التحويل (Snapshot FR-08-05) لا سعر يوم العرض.
///
/// ## قرارات موثقة (انظر worklog-parts/6-b.md):
/// 1. جدول `quotation` بلا عمود `rate_is_fallback` ولا `converted_at`
///    (المخطط مجمّد §5.3): لحظة التحويل تُخزَّن في `updated_at`، وشارة
///    «سعر تقديري» (FR-02-20) تظهر على الفاتورة الناتجة (عمودها هناك)
///    لا على العرض — طلب هجرة مرفوع للمنسّق إن أُريدت على العرض نفسه.
/// 2. `quotation.discount_amount` يخزَّن **إجمالي الخصم الفعلي**
///    (أسطر + رأس) بنفس دلالة `invoice.discount_amount` — لا عمود
///    مستقل لخصوم الأسطر بالمخطط.
/// 3. عند الإنشاء يوزَّع خصم الرأس pro-rata داخل بنود العرض (مثل
///    الفاتورة تماماً) فيتحول التحويل إلى نسخ أرقام حرفي بلا إعادة توزيع.
/// 4. الإلغاء من draft/sent فقط؛ والتحويل كذلك — وطلبات التحويل المتزامنة
///    يحميها شرط `status IN ('draft','sent')` داخل معاملة الفاتورة.
library;

import 'package:sqflite/sqflite.dart';

import '../../core/storage/doc_sequence.dart';
import '../../domain/core/result.dart';
import '../../domain/models/quotation.dart';
import '../../domain/models/sale.dart';
import '../../domain/services/sale_pricing.dart';
import 'exchange_rate_repository.dart';
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
  }) async {
    final at = now ?? DateTime.now();
    final issuedIso = draft.issuedAt.toUtc().toIso8601String();

    // التسعير النقي المشترك مع الفاتورة (خصومات pro-rata موثقة هناك).
    final cartLines = [
      for (final line in draft.lines)
        CartLine(
          productId: line.productId,
          qty: line.qty,
          unitPrice: line.unitPrice,
          lineDiscountType: line.lineDiscountType,
          lineDiscountValue: line.lineDiscountValue,
          notes: line.notes,
        ),
    ];
    final failure = SalePricing.validateCart(
      cartLines,
      invoiceDiscountType: draft.invoiceDiscountType,
      invoiceDiscountValue: draft.invoiceDiscountValue,
    );
    if (failure != null) return Err(failure);
    final priced = SalePricing.priceCart(
      cartLines,
      invoiceDiscountType: draft.invoiceDiscountType,
      invoiceDiscountValue: draft.invoiceDiscountValue,
    );

    try {
      // الأصناف — أسماء لقطة البنود + رفض المفقود (لا فحص مخزون إطلاقاً:
      // العرض لا يلتزم شيئاً).
      final productIds = draft.lines.map((l) => l.productId).toSet();
      final productRows = await _db.rawQuery(
        'SELECT id, name, unit_id FROM product '
        'WHERE id IN (${List.filled(productIds.length, '?').join(',')})',
        productIds.toList(),
      );
      final namesById = {
        for (final row in productRows)
          row['id'] as int: (row['name'] as String, row['unit_id'] as int?),
      };
      for (final id in productIds) {
        if (!namesById.containsKey(id)) {
          return Err('الصنف رقم #$id غير موجود.');
        }
      }

      // سياسة FX (FR-08-09) — نفس قاعدة البيع بلا عمود شارة هنا
      // (القرار 1 برأس الملف): بلا سعر اليوم → رفض إلا بـ fx.fallback.
      final currencyRows = await _db.query(
        'currency',
        columns: ['code', 'is_base'],
        where: 'id = ?',
        whereArgs: [draft.currencyId],
        limit: 1,
      );
      if (currencyRows.isEmpty) {
        return Err('العملة رقم #${draft.currencyId} غير موجودة.');
      }
      final isBase = (currencyRows.first['is_base'] as int? ?? 0) == 1;
      final currencyCode = currencyRows.first['code'] as String;
      var rate = 1.0;
      if (!isBase) {
        final today = await _rates.rateFor(draft.currencyId, draft.issuedAt);
        if (today != null && today > 0) {
          rate = today;
        } else if ((await _settings.getString('fx.fallback', 'off')) ==
            'last_known') {
          final lastKnown = await _rates.latestBefore(
            draft.currencyId,
            draft.issuedAt,
          );
          if (lastKnown == null || lastKnown <= 0) {
            return Err(
              'لا يوجد أي سعر صرف معروف لعملة $currencyCode — '
              'أدخل سعراً أولاً ثم أنشئ العرض.',
            );
          }
          rate = lastKnown;
        } else {
          return Err(
            'لا يوجد سعر صرف لعملة $currencyCode بتاريخ اليوم — '
            'أدخل سعر اليوم أولاً (لا يُحفظ بسعر افتراضي).',
          );
        }
      }

      return await _db.transaction((txn) async {
        // رقم QTE ذرّي داخل المعاملة (قاعدة 5.4-1).
        final year = draft.issuedAt.year;
        final seq = DocSequenceService(txn);
        final number = await seq.nextNumber(DocSequenceType.quotation, year);
        final quotationNo = formatDocNumber(
          DocSequenceType.quotation,
          year,
          number,
        );

        final quotationId = await txn.insert('quotation', {
          'quotation_no': quotationNo,
          'customer_id': draft.customerId,
          'warehouse_id': draft.warehouseId,
          'currency_id': draft.currencyId,
          'exchange_rate': rate,
          'issued_at': issuedIso,
          'valid_until': draft.validUntil == null
              ? null
              : _dateOnly(draft.validUntil!),
          'status': 'draft',
          'subtotal': priced.totals.subtotal,
          'discount_amount': roundMoney(priced.totals.totalDiscount),
          'tax_rate': 0,
          'tax_amount': 0,
          'total': priced.totals.grandTotal,
          'notes_internal': draft.notesInternal,
          'notes_printed': draft.notesPrinted,
          'created_at': at.toUtc().toIso8601String(),
          'updated_at': at.toUtc().toIso8601String(),
          'created_by': userId,
        });

        for (final pricedLine in priced.lines) {
          final (name, unitId) = namesById[pricedLine.line.productId]!;
          await txn.insert('quotation_item', {
            'quotation_id': quotationId,
            'product_id': pricedLine.line.productId,
            'line_desc': name,
            'qty': pricedLine.line.qty,
            'unit_id': unitId,
            'unit_factor': 1,
            'unit_price': pricedLine.line.unitPrice,
            'discount_percent':
                pricedLine.line.lineDiscountType == SaleDiscountType.percent
                ? pricedLine.line.lineDiscountValue
                : 0,
            'discount_amount': pricedLine.effectiveDiscount,
            'tax_percent': 0,
            'line_total': pricedLine.netFinal,
            'notes': (pricedLine.line.notes ?? '').trim().isEmpty
                ? null
                : pricedLine.line.notes!.trim(),
            'created_at': at.toUtc().toIso8601String(),
          });
        }

        await txn.insert('audit_log', {
          'user_id': userId,
          'action': 'quotation_create',
          'entity': 'quotation',
          'entity_id': quotationId,
          'details':
              'no=$quotationNo total=${priced.totals.grandTotal} '
              'currency=$currencyCode rate=$rate',
          'at': at.toUtc().toIso8601String(),
        });

        final rows = await txn.query(
          'quotation',
          where: 'id = ?',
          whereArgs: [quotationId],
          limit: 1,
        );
        return Ok<Quotation, String>(Quotation.fromRow(rows.first));
      });
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e));
    } on StateError catch (e) {
      return Err(e.message);
    }
  }

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
  }) async {
    final at = now ?? DateTime.now();
    final rows = await _db.query(
      'quotation',
      where: 'id = ?',
      whereArgs: [quotationId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return Err('عرض السعر رقم #$quotationId غير موجود.');
    }
    final quotation = Quotation.fromRow(rows.first);
    if (!quotation.status.convertible) {
      return Err(
        'عرض السعر غير قابل للتحويل — حالته الحالية '
        '«${quotation.status.code}».',
      );
    }

    final itemRows = await _db.query(
      'quotation_item',
      where: 'quotation_id = ?',
      whereArgs: [quotationId],
      orderBy: 'id ASC',
    );
    if (itemRows.isEmpty) {
      return Err('عرض السعر بلا بنود — لا يُحوَّل إلى فاتورة.');
    }

    // البنود بنفس أسعارها وخصومها الفعلية (خصم الرأس موزَّع فيها أصلاً).
    final lines = [
      for (final row in itemRows)
        CartLine(
          productId: row['product_id'] as int,
          qty: (row['qty'] as num?)?.toDouble() ?? 0,
          unitPrice: (row['unit_price'] as num?)?.toDouble() ?? 0,
          lineDiscountType: SaleDiscountType.amount,
          lineDiscountValue: (row['discount_amount'] as num?)?.toDouble() ?? 0,
          notes: row['notes'] as String?,
        ),
    ];

    // نوع الدفع: معلناً أو مستنتجاً من المبلغ مقابل صافي العرض.
    final method =
        paymentMethod ?? SalePricing.derivePayStatus(quotation.total, paidCash);

    return _sales.postSale(
      SaleDraft(
        customerId: quotation.customerId,
        currencyId: quotation.currencyId,
        lines: lines,
        paidCash: paidCash,
        paymentMethod: method,
        warehouseId: quotation.warehouseId,
        notesInternal: quotation.notesInternal,
        notesPrinted: quotation.notesPrinted,
        issuedAt: issuedAt ?? at,
        fromQuotationId: quotationId,
      ),
      userId: userId,
      now: at,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // حالات المستند
  // ─────────────────────────────────────────────────────────────────────

  /// تعليم العرض «مُرسَلاً» (draft → sent فقط) + قيد تدقيق.
  Future<Result<Quotation, String>> markSent(
    int id, {
    required int userId,
    DateTime? now,
  }) => _changeStatus(
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
  }) => _changeStatus(
    id,
    from: const ['draft', 'sent'],
    to: QuotationStatus.rejected,
    action: 'quotation_cancel',
    userId: userId,
    now: now,
  );

  Future<Result<Quotation, String>> _changeStatus(
    int id, {
    required List<String> from,
    required QuotationStatus to,
    required String action,
    required int userId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final iso = at.toUtc().toIso8601String();
    try {
      return await _db.transaction((txn) async {
        final updated = await txn.update(
          'quotation',
          {'status': to.code, 'updated_at': iso},
          where:
              'id = ? AND status IN (${List.filled(from.length, '?').join(',')})',
          whereArgs: [id, ...from],
        );
        if (updated == 0) {
          final rows = await txn.query(
            'quotation',
            columns: ['status'],
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (rows.isEmpty) return Err('عرض السعر رقم #$id غير موجود.');
          return Err(
            'لا يمكن نقل العرض من حالته الحالية '
            '«${rows.first['status']}» إلى «${to.code}».',
          );
        }
        await txn.insert('audit_log', {
          'user_id': userId,
          'action': action,
          'entity': 'quotation',
          'entity_id': id,
          'details': 'status=${to.code}',
          'at': iso,
        });
        final rows = await txn.query(
          'quotation',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        return Ok<Quotation, String>(Quotation.fromRow(rows.first));
      });
    } on DatabaseException catch (e) {
      return Err(_describeDbError(e));
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // القراءات
  // ─────────────────────────────────────────────────────────────────────

  /// قائمة العروض (الأحدث أولاً) بتصفية العميل/الحالة وحد أعلى.
  Future<List<QuotationSummary>> listQuotations({
    int? customerId,
    QuotationStatus? status,
    int limit = 50,
  }) async {
    final where = [
      if (customerId != null) 'q.customer_id = ?',
      if (status != null) 'q.status = ?',
    ];
    final rows = await _db.rawQuery(
      '''
      SELECT q.id, q.quotation_no, q.issued_at, q.valid_until, q.customer_id,
             q.total, q.status, q.converted_invoice_id,
             c.name AS customer_name, cu.code AS currency_code
      FROM quotation q
      LEFT JOIN customer c ON c.id = q.customer_id
      JOIN currency cu ON cu.id = q.currency_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY q.issued_at DESC, q.id DESC
      LIMIT ?
    ''',
      [?customerId, ?status?.code, limit],
    );
    return [
      for (final row in rows)
        QuotationSummary(
          id: row['id'] as int,
          quotationNo: row['quotation_no'] as String,
          issuedAt: DateTime.parse(row['issued_at'] as String),
          validUntil: row['valid_until'] == null
              ? null
              : DateTime.tryParse(row['valid_until'] as String),
          customerId: row['customer_id'] as int?,
          customerName: row['customer_name'] as String?,
          currencyCode: row['currency_code'] as String?,
          total: (row['total'] as num?)?.toDouble() ?? 0,
          status: QuotationStatus.fromCode(row['status'] as String),
          convertedInvoiceId: row['converted_invoice_id'] as int?,
        ),
    ];
  }

  /// تفاصيل عرض كامل: الرأس + البنود + أسماء العميل/العملة.
  Future<QuotationDetail?> quotationDetail(int id) async {
    final rows = await _db.rawQuery(
      '''
      SELECT q.*, c.name AS customer_name, c.phone AS customer_phone,
             cu.code AS currency_code
      FROM quotation q
      LEFT JOIN customer c ON c.id = q.customer_id
      JOIN currency cu ON cu.id = q.currency_id
      WHERE q.id = ?
      LIMIT 1
    ''',
      [id],
    );
    if (rows.isEmpty) return null;
    final itemRows = await _db.query(
      'quotation_item',
      where: 'quotation_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );
    return QuotationDetail(
      quotation: Quotation.fromRow(rows.first),
      items: [for (final row in itemRows) QuotationItemLine.fromRow(row)],
      customerName: rows.first['customer_name'] as String?,
      customerPhone: rows.first['customer_phone'] as String?,
      currencyCode: rows.first['currency_code'] as String?,
    );
  }

  /// يصوغ خطأ قاعدة البيانات بكلمات المستخدم.
  String _describeDbError(DatabaseException e) {
    if (e.isUniqueConstraintError()) {
      final text = e.toString();
      if (text.contains('quotation_no')) {
        return 'تعارض في رقم عرض السعر — أعد المحاولة';
      }
      return 'قيمة مكررة تخالف قيد التفرد في القاعدة';
    }
    if (_isCheckFailure(e)) {
      return 'قيمة حالة غير مسموح بها لعرض السعر';
    }
    return 'تعذر حفظ عرض السعر في القاعدة: $e';
  }
}

/// هل الخطأ خرقاً لقيد CHECK؟ (لا مساعد جاهز في sqflite — نقرأ الرسالة).
bool _isCheckFailure(DatabaseException e) =>
    e.toString().toUpperCase().contains('CHECK');

/// `YYYY-MM-DD` بتاريخ التقويم المحلي (نمط المستودعات).
String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
