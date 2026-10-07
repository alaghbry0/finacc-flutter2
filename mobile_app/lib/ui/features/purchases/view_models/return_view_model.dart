/// نموذج عرض المرتجعات المرتبطة (SRN مرتجع بيع / PRN مرتجع شراء) —
/// المرحلة 5 / FR-02-07 / FR-02-08.
///
/// شاشة واحدة بنمط واحد لكلا النوعين (نفس الهوية البصرية بشارة نوع
/// المستند): يعرض بنود الفاتورة الأصلية مع **المتاح للإرجاع لكل بند**
/// (`saleReturnableLines` / `purchaseReturnableLines`)، ويستقبل الكميات
/// المرتجعة، ثم يرحّل عبر `ReturnRepository.postSaleReturn` /
/// `postPurchaseReturn` الذرّيين مع اتجاه رد القيمة (نقدي / حساب /
/// مختلط).
///
/// خطوط حمراء:
/// - **الارتباط الحصري**: لا مرتجع حر — الشاشة تُفتح بمعرّف الفاتورة
///   الأصلية حصراً؛ فاتورة غير موجودة/غير مكتملة → حالة فارغة واضحة.
/// - **سقف الكميات**: الكمية المدخلة ترفض فور تجاوز المتاح (ويعيد المحرك
///   فحصه داخل المعاملة).
/// - **اتجاه المبلغ**: خصم الحساب يتطلب طرفاً مسجلاً (عميل للبيع / مورد
///   للشراء) — بيع نقدي مجهول → رد نقدي حصراً.
/// - **المعاينة تقدير لحظي** — الرقم النهائي (بخصمه التناسبي Snapshot)
///   يحسبه المحرك ويظهر في الإيصال.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../data/repositories/return_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/services/purchase_pricing.dart';

/// نوع المرتجع — يحدد المصدر والمسودة والتسميات.
enum ReturnKind {
  /// مرتجع بيع SRN عن فاتورة بيع (FR-02-07).
  sale('sale', 'sale_return'),

  /// مرتجع شراء PRN عن فاتورة شراء (FR-02-08).
  purchase('purchase', 'purchase_return');

  const ReturnKind(this.originalDocType, this.returnDocType);

  /// doc_type للفاتورة الأصلية.
  final String originalDocType;

  /// doc_type لمستند المرتجع.
  final String returnDocType;

  /// هل البند الأصلي بيعاً؟
  bool get isSale => this == ReturnKind.sale;
}

/// رأس الفاتورة الأصلية (معلومات العرض).
class ReturnOriginalInfo {
  const ReturnOriginalInfo({
    required this.invoiceNo,
    required this.partyName,
    required this.currencyCode,
    this.partyId,
    this.issuedAt,
  });

  final String invoiceNo;

  /// اسم الطرف (عميل/مورد) — null لبيع نقدي مجهول.
  final String? partyName;

  /// معرّف الطرف (null = بيع نقدي مجهول — لا خصم حساب).
  final int? partyId;

  final String? currencyCode;
  final DateTime? issuedAt;

  /// هل يمكن خصم قيمة المرتجع من حساب الطرف؟
  bool get canRefundCredit => partyId != null;
}

class ReturnScreenState {
  const ReturnScreenState({
    required this.loading,
    required this.kind,
    this.original,
    required this.lines,
    required this.returnQtyByItem,
    required this.posting,
    this.postError,
    this.lastReceipt,
    this.error,
  });

  final bool loading;
  final ReturnKind kind;
  final ReturnOriginalInfo? original;

  /// بنود الفاتورة الأصلية مع المتاح لكل بند.
  final List<ReturnableLine> lines;

  /// الكميات المرتجعة المدخلة (مفتاحها invoiceItemId — القيم > 0).
  final Map<int, double> returnQtyByItem;

  final bool posting;
  final String? postError;
  final ReturnPostedReceipt? lastReceipt;
  final Object? error;

  static ReturnScreenState initialFor(ReturnKind kind) => ReturnScreenState(
    loading: true,
    kind: kind,
    lines: const <ReturnableLine>[],
    returnQtyByItem: const <int, double>{},
    posting: false,
  );

  /// البنود التي لها كمية إرجاع > 0.
  List<ReturnableLine> get selectedLines => [
    for (final line in lines)
      if ((returnQtyByItem[line.invoiceItemId] ?? 0) > 0) line,
  ];

  /// هل أُدخلت أي كمية؟
  bool get hasAnyQty => returnQtyByItem.values.any((q) => q > 0);

  /// إجمالي الكميات المحددة.
  double get totalQty => returnQtyByItem.values.fold(0, (sum, q) => sum + q);
}

/// نموذج عرض المرتجع الموحّد — يُبنى محلياً بالشاشة (نمط المستودعات).
class ReturnViewModel extends ChangeNotifier {
  ReturnViewModel({
    required Database database,
    required ReturnRepository returnRepo,
    required this.kind,
    required this.originalInvoiceId,
    DateTime Function()? clock,
  }) : _db = database,
       _returns = returnRepo,
       _clock = clock ?? DateTime.now {
    _state = ReturnScreenState.initialFor(kind);
  }

  final Database _db;
  final ReturnRepository _returns;
  final ReturnKind kind;
  final int originalInvoiceId;
  final DateTime Function() _clock;

  late ReturnScreenState _state;
  ReturnScreenState get state => _state;

  int? _userId;

  // ───────────────────────────────────────────────────────────────────
  // التحميل
  // ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    _state = ReturnScreenState.initialFor(kind);
    notifyListeners();
    try {
      // منفّذ العملية (تدقيق) — أول مدير نشط (نفس اصطلاح findAdminUserId).
      final userRows = await _db.query(
        'app_user',
        columns: ['id'],
        where: "role = 'admin' AND is_active = 1",
        orderBy: 'id ASC',
        limit: 1,
      );
      if (userRows.isNotEmpty) _userId = userRows.first['id'] as int;
      final header = await _loadOriginalHeader();
      if (header == null) {
        // فاتورة غير موجودة أو نوع/حالة غير مطابقين → لا بنود قابلة.
        _state = ReturnScreenState(
          loading: false,
          kind: kind,
          original: null,
          lines: const <ReturnableLine>[],
          returnQtyByItem: const <int, double>{},
          posting: false,
        );
        notifyListeners();
        return;
      }
      final lines = kind.isSale
          ? await _returns.saleReturnableLines(originalInvoiceId)
          : await _returns.purchaseReturnableLines(originalInvoiceId);
      _state = ReturnScreenState(
        loading: false,
        kind: kind,
        original: header,
        lines: lines,
        returnQtyByItem: const <int, double>{},
        posting: false,
      );
    } catch (error) {
      _state = ReturnScreenState(
        loading: false,
        kind: kind,
        lines: const <ReturnableLine>[],
        returnQtyByItem: const <int, double>{},
        posting: false,
        error: error,
      );
    }
    notifyListeners();
  }

  /// رأس الفاتورة الأصلية (نوع/حالة مطابقين) — null عند عدم المطابقة.
  Future<ReturnOriginalInfo?> _loadOriginalHeader() async {
    final rows = await _db.rawQuery(
      '''
      SELECT i.invoice_no, i.issued_at, i.doc_type, i.status,
             i.customer_id, i.supplier_id,
             (SELECT c.name FROM customer c WHERE c.id = i.customer_id)
               AS customer_name,
             (SELECT s.name FROM supplier s WHERE s.id = i.supplier_id)
               AS supplier_name,
             (SELECT cu.code FROM currency cu WHERE cu.id = i.currency_id)
               AS currency_code
      FROM invoice i
      WHERE i.id = ?
      LIMIT 1
      ''',
      [originalInvoiceId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    if (row['doc_type'] != kind.originalDocType) return null;
    if (row['status'] != 'completed') return null;
    return ReturnOriginalInfo(
      invoiceNo: row['invoice_no'] as String,
      partyId: (kind.isSale ? row['customer_id'] : row['supplier_id']) as int?,
      partyName: kind.isSale
          ? row['customer_name'] as String?
          : row['supplier_name'] as String?,
      currencyCode: row['currency_code'] as String?,
      issuedAt: row['issued_at'] == null
          ? null
          : DateTime.parse(row['issued_at'] as String),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // الكميات المرتجعة والمعاينة الحية
  // ───────────────────────────────────────────────────────────────────

  /// الكمية المرتجعة لبند — 0 تصفّره؛ > المتاح تُرفض فوراً.
  void setReturnQty(int invoiceItemId, double qty) {
    if (qty.isNaN || qty.isInfinite || qty < 0) {
      _postErrorNotice('الكمية المرتجعة غير صالحة.');
      return;
    }
    ReturnableLine? line;
    for (final l in _state.lines) {
      if (l.invoiceItemId == invoiceItemId) {
        line = l;
        break;
      }
    }
    if (line == null) return;
    if (qty > line.availableQty + _qtyEpsilon) {
      _postErrorNotice(
        'الكمية المطلوب إرجاعها من «${line.lineDesc ?? 'بند'}» ($qty) '
        'تتجاوز المتاح للإرجاع (${_num(line.availableQty)}).',
      );
      return;
    }
    final quantities = {..._state.returnQtyByItem};
    if (qty <= 0) {
      quantities.remove(invoiceItemId);
    } else {
      quantities[invoiceItemId] = qty;
    }
    _state = _copyWith(quantities: quantities, postError: null);
    notifyListeners();
  }

  /// المعاينة الحية لقيمة المرتجع — تقدير لحظي (Σ round2(qty × صافي
  /// الوحدة الأصلي))؛ الرقم النهائي بخصمه التناسبي يحسبه المحرك.
  double get refundTotalPreview {
    var total = 0.0;
    for (final entry in _state.returnQtyByItem.entries) {
      for (final line in _state.lines) {
        if (line.invoiceItemId == entry.key) {
          total = roundMoney(total + entry.value * line.unitPriceEffective);
          break;
        }
      }
    }
    return total;
  }

  // ───────────────────────────────────────────────────────────────────
  // الترحيل
  // ───────────────────────────────────────────────────────────────────

  /// **ترحيل المرتجع** — نجاح: تُصفَّر الكميات ويُحفظ الإيصال؛ فشل: رسالة
  /// الرفض العربية والاختيارات لا تُفقد.
  Future<Result<ReturnPostedReceipt, String>> postReturn({
    required double refundCash,
    required ReturnRefundMethod method,
  }) async {
    if (_state.posting) {
      return const Err<ReturnPostedReceipt, String>(
        'ترحيل جارٍ بالفعل — لحظات ويكتمل.',
      );
    }
    final failure = _prePostFailure(refundCash, method);
    if (failure != null) {
      _state = _copyWith(postError: failure);
      notifyListeners();
      return Err<ReturnPostedReceipt, String>(failure);
    }

    _state = _copyWith(posting: true, postError: null);
    notifyListeners();

    final issuedAt = _clock();
    final result = kind.isSale
        ? await _returns.postSaleReturn(
            SaleReturnDraft(
              originalInvoiceId: originalInvoiceId,
              lines: _buildLineInputs(),
              refundCash: refundCash,
              refundMethod: method,
              issuedAt: issuedAt,
            ),
            userId: _userId ?? 1,
            now: _clock(),
          )
        : await _returns.postPurchaseReturn(
            PurchaseReturnDraft(
              originalInvoiceId: originalInvoiceId,
              lines: _buildLineInputs(),
              refundCash: refundCash,
              refundMethod: method,
              issuedAt: issuedAt,
            ),
            userId: _userId ?? 1,
            now: _clock(),
          );

    if (result.isOk) {
      _state = _copyWith(
        posting: false,
        quantities: const <int, double>{},
        lastReceipt: result.valueOrNull!,
        postError: null,
      );
      notifyListeners();
    } else {
      _state = _copyWith(posting: false, postError: result.errorOrNull!);
      notifyListeners();
    }
    return result;
  }

  /// بنود الترحيل (الكميات > 0 فقط).
  List<ReturnLineInput> _buildLineInputs() => [
    for (final entry in _state.returnQtyByItem.entries)
      if (entry.value > 0)
        ReturnLineInput(invoiceItemId: entry.key, qty: entry.value),
  ];

  /// فحوص ما قبل الترحيل — null عند السلامة.
  String? _prePostFailure(double refundCash, ReturnRefundMethod method) {
    if (!_state.hasAnyQty) {
      return 'حدد كمية إرجاع لبند واحد على الأقل قبل الترحيل.';
    }
    final total = refundTotalPreview;
    if (refundCash.isNaN || refundCash.isInfinite || refundCash < 0) {
      return 'الجزء النقدي غير صالح — أدخل رقماً سليماً.';
    }
    if (refundCash > total + moneyEpsilon) {
      return 'الجزء النقدي ($refundCash) يتجاوز قيمة المرتجع ($total) — '
          'لا رد زائداً عن قيمة ما أُرجع.';
    }
    // خصم الحساب يتطلب طرفاً مسجلاً (بيع نقدي مجهول → نقدي حصراً).
    final hasParty = _state.original?.canRefundCredit ?? false;
    final credit = total - refundCash;
    if (credit > moneyEpsilon && !hasParty) {
      return kind.isSale
          ? 'الفاتورة الأصلية بلا عميل مسجَّل (بيع نقدي مجهول) — لا حساب '
                'يُخصم منه؛ اختر رد القيمة نقداً من الصندوق.'
          : 'فاتورة الشراء الأصلية بلا مورد مسجَّل — لا دين يُخصم منه؛ '
                'اختر الاسترداد نقداً إلى الصندوق.';
    }
    // اتساق التعلان مع الأرقام (مرآة نمط المحرك).
    final derived = _deriveMethod(total, refundCash);
    if (derived == method) return null;
    switch (method) {
      case ReturnRefundMethod.cash:
        return 'الرد النقدي الكامل يتطلب تسديد قيمة المرتجع كاملة '
            '($total) — أو اختر المختلط/الحساب.';
      case ReturnRefundMethod.credit:
        return 'الرد على الحساب يتطلب عدم إدخال أي جزء نقدي — المدخل '
            '$refundCash.';
      case ReturnRefundMethod.mixed:
        return 'الرد المختلط يتطلب جزءاً نقدياً بين صفر وقيمة المرتجع '
            '($total) حصراً — المدخل $refundCash.';
    }
  }

  static ReturnRefundMethod _deriveMethod(double total, double refundCash) {
    if (refundCash <= moneyEpsilon) return ReturnRefundMethod.credit;
    if (refundCash >= total - moneyEpsilon) return ReturnRefundMethod.cash;
    return ReturnRefundMethod.mixed;
  }

  // ───────────────────────────────────────────────────────────────────
  // أدوات
  // ───────────────────────────────────────────────────────────────────

  void clearPostError() {
    if (_state.postError == null) return;
    _state = _copyWith(postError: null);
    notifyListeners();
  }

  void dismissReceipt() {
    if (_state.lastReceipt == null) return;
    _state = _copyWith(lastReceipt: null);
    notifyListeners();
  }

  void _postErrorNotice(String message) {
    _state = _copyWith(postError: message);
    notifyListeners();
  }

  ReturnScreenState _copyWith({
    Map<int, double>? quantities,
    bool? posting,
    String? postError,
    ReturnPostedReceipt? lastReceipt,
  }) => ReturnScreenState(
    loading: _state.loading,
    kind: _state.kind,
    original: _state.original,
    lines: _state.lines,
    returnQtyByItem: quantities ?? _state.returnQtyByItem,
    posting: posting ?? _state.posting,
    postError: postError ?? _state.postError,
    lastReceipt: lastReceipt ?? _state.lastReceipt,
    error: _state.error,
  );
}

/// تفاوت الكميات (NUMERIC(12,3) بالمخطط).
const double _qtyEpsilon = 0.000001;

/// يصيغ رقماً للعرض في الرسائل بلا أصفار زائدة.
String _num(double v) {
  if (v.isNaN || v.isInfinite) return v.toString();
  final rounded = (v * 1000).round() / 1000;
  if (rounded == rounded.round()) return rounded.toInt().toString();
  return rounded.toStringAsFixed(3);
}
