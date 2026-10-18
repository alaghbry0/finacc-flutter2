/// نموذج عرض فاتورة الشراء الحية (نمط سلة الكاشير المرجعي) — §4 المشتريات
/// (FR-02-08 / قاعدة 5.4-3 WAC / 5.4-4 الذرّية).
///
/// فاتورة حية في الذاكرة (ChangeNotifier) تُسعَّر لحظياً عبر
/// `PurchasePricing` (المجموع/خصومات الأسطر/خصم الرأس الموزَّع pro-rata
/// **قبل** WAC/الصافي بلا أي وصول قاعدة أثناء التعبئة)، وترحَّل بضغطة عبر
/// `PurchaseRepository.postPurchase` الذرّي (رقم PUR + بنود بتكلفة الوحدة
/// الفعلية + تحديث WAC + الدفعات الواردة + المخزون وحركاته + سند الصرف
/// للجزء النقدي + التخصيص + التدقيق — كلها أو لا شيء).
///
/// خطوط حمراء مطبَّقة هنا (مرآة البيع باتجاه الشراء):
/// - **سياسة FX المفقود** (FR-08-09): عملة غير الأساس بلا سعر اليوم → علم
///   `fxGateRequired` يفتح نافذة إدخال السعر فوراً، ويُمنع الترحيل قبل إدخاله.
/// - **المورد إلزامي** للشراء (لا مورد نقدي مجهول) — الترحيل يرفض بدونه.
/// - **المتتبع للدفعات يُلزم برقم الدفعة** (قرار المحرك 4: رصيد المتتبع بلا
///   دفعة لا يظهر متاحاً للبيع) — مع تاريخ الصلاحية (عمود expiry NOT NULL).
/// - فشل `postPurchase` **لا يفقد الفاتورة** — رسالة الرفض العربية تُعرض
///   كما هي (السلة محفوظة).
///
/// الأنواع النقية والنسخ في `purchase_cart_state.dart` والحسابات النقية في
/// `purchase_cart_helpers.dart` (R19-D3c — وصفة sell_cart_view_model من
/// R19-D3a)؛ هذا الملف يصدّر الحالة فبقيت استيرادات المستدعين كما هي.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/exchange_rate_repository.dart';
import '../../../../data/repositories/purchase_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/item.dart';
import '../../../../domain/models/purchase.dart';
import 'purchase_cart_helpers.dart';
import 'purchase_cart_state.dart';

export 'purchase_cart_state.dart';

/// نموذج فاتورة الشراء الحية — يعيش الجلسة عبر [PurchaseCartSession].
class PurchaseCartViewModel extends ChangeNotifier {
  PurchaseCartViewModel({
    required CompanyRepository companyRepo,
    required ExchangeRateRepository fxRepo,
    required PurchaseRepository purchaseRepo,

    /// مقبض القاعدة — يُبقى حصراً لتوافق الاستدعاءات القائمة (الجلسة/
    /// الشاشة/الاختبارات)؛ لم يعد يُستعمل داخل النموذج منذ R18-D1:
    /// معاينة رقم الفاتورة صارت عبر `PurchaseRepository.previewNextPurchaseNo`.
    required Database database,
    DateTime Function()? clock,
  }) : _companies = companyRepo,
       _fx = fxRepo,
       _purchases = purchaseRepo,
       _clock = clock ?? DateTime.now;

  final CompanyRepository _companies;
  final ExchangeRateRepository _fx;
  final PurchaseRepository _purchases;
  final DateTime Function() _clock;

  PurchaseCartState _state = PurchaseCartState.initial;
  PurchaseCartState get state => _state;

  int? _userId;
  bool _initialized = false;

  // ───────────────────────────────────────────────────────────────────
  // التحميل (مرة واحدة بالجلسة — الفاتورة تنجو من التنقل)
  // ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_initialized) {
      // إعادة الدخول للشاشة: تحديث سعر اليوم فقط (الفاتورة كما هي).
      await _refreshRateKnowledge();
      return;
    }
    _state = PurchaseCartState.initial;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _companies.listActiveCurrencies(),
        _companies.findBaseCurrency(),
        _companies.findDefaultWarehouseId(),
        _companies.findAdminUserId(),
      ]);
      final currencies = results[0]! as List<Currency>;
      final base = results[1] as Currency?;
      final warehouseId = results[2] as int?;
      _userId = results[3] as int?;

      _initialized = true;
      _state = PurchaseCartState(
        loading: false,
        currencies: currencies,
        baseCurrency: base,
        currencyId: base?.id,
        rateKnown: true,
        warehouseId: warehouseId,
        lines: const <PurchaseCartUiLine>[],
        invoiceDiscountType: PurchaseDiscountType.amount,
        invoiceDiscountValue: 0,
        posting: false,
        nextInvoiceNo: await _nextPurchasePreview(),
      );
    } catch (error) {
      _state = PurchaseCartState(
        loading: false,
        error: error,
        currencies: const <Currency>[],
        rateKnown: true,
        lines: const <PurchaseCartUiLine>[],
        invoiceDiscountType: PurchaseDiscountType.amount,
        invoiceDiscountValue: 0,
        posting: false,
      );
    }
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────
  // التسعير الحي (نقي — بلا قاعدة)
  // ───────────────────────────────────────────────────────────────────

  List<PurchaseLine> get purchaseLines => purchaseCartLines(_state);

  /// الفاتورة المُسعَّرة الآن — null عند الفراغ أو عدم قابلية التسعير.
  PricedPurchaseCart? get pricedCart => purchaseCartPricedCart(_state);

  /// خطأ التحقق الحالي (كميات/تكاليف/خصومات/صافٍ > 0/دفعات واردة) —
  /// null عند السلامة.
  String? get cartError => purchaseCartError(_state);

  /// الصافي الحالي (للعرض في زر الترحيل) — 0 عند الفراغ.
  double get grandTotal => pricedCart?.totals.grandTotal ?? 0;

  // ───────────────────────────────────────────────────────────────────
  // المورد والعملة
  // ───────────────────────────────────────────────────────────────────

  /// اختيار مورد (إلزامي — لا شراء بلا مورد).
  void setSupplier({required int id, required String name, String? phone}) {
    _state = purchaseCartStateWith(
      _state,
      supplier: CartSupplier(id: id, name: name, phone: phone),
      postError: null,
    );
    notifyListeners();
  }

  /// اختيار عملة الفاتورة — عند عملة غير الأساس بلا سعر اليوم تُفتح
  /// بوابة الإدخال فوراً (FR-08-09).
  Future<void> setCurrency(int currencyId) async {
    if (currencyId == _state.currencyId) return;
    final currency = _currencyById(currencyId);
    final isBase = currency?.isBase ?? false;
    var rateKnown = true;
    double? rate;
    if (!isBase) {
      rate = await _fx.rateFor(currencyId, _clock());
      rateKnown = rate != null && rate > 0;
    }
    _state = purchaseCartStateWith(
      _state,
      currencyId: currencyId,
      todayRate: rate,
      rateKnown: rateKnown,
      fxGateRequired: !isBase && !rateKnown,
      postError: null,
      notice: null,
    );
    notifyListeners();
  }

  /// حفظ سعر اليوم من بوابة FX (يكتب عبر fx.setRate ثم يتابع).
  Future<Result<void, String>> saveTodayRate(double rate) async {
    final currencyId = _state.currencyId;
    if (currencyId == null) {
      return const Err<void, String>('اختر عملة أولاً.');
    }
    final result = await _fx.setRate(
      currencyId: currencyId,
      date: _clock(),
      rate: rate,
      userId: _userId ?? 1,
      now: _clock(),
    );
    if (result.isOk) {
      await _refreshRateKnowledge();
    }
    return result;
  }

  /// استهلاك طلب فتح بوابة FX (بعد فتح النافذة).
  void clearFxGate() {
    if (!_state.fxGateRequired) return;
    _state = purchaseCartStateWith(_state, fxGateRequired: false);
    notifyListeners();
  }

  Future<void> _refreshRateKnowledge() async {
    final currencyId = _state.currencyId;
    if (currencyId == null) return;
    final currency = _currencyById(currencyId);
    if (currency == null || currency.isBase) {
      _state = purchaseCartStateWith(
        _state,
        todayRate: null,
        rateKnown: true,
        fxGateRequired: false,
      );
      notifyListeners();
      return;
    }
    final rate = await _fx.rateFor(currencyId, _clock());
    final known = rate != null && rate > 0;
    _state = purchaseCartStateWith(
      _state,
      todayRate: rate,
      rateKnown: known,
      fxGateRequired: known ? false : _state.fxGateRequired,
    );
    notifyListeners();
  }

  Currency? _currencyById(int id) {
    for (final currency in _state.currencies) {
      if (currency.id == id) return currency;
    }
    return null;
  }

  // ───────────────────────────────────────────────────────────────────
  // بنود الفاتورة
  // ───────────────────────────────────────────────────────────────────

  /// إضافة صنف وارد (الكمية 1) — التكلفة الافتراضية = آخر تكلفة WAC
  /// للصنف محوَّلة لعملة الفاتورة بسعر اليوم.
  void addItemFromInfo(ItemStockInfo info) {
    final warehouseId = _state.warehouseId;
    final currentStock = info.item.isService
        ? null
        : (info.warehouseQty[warehouseId] ?? info.totalQty);
    // WAC بالعملة الأساسية → عملة الفاتورة (القسمة على سعر اليوم —
    // السعر = قيمة وحدة العملة بالأساس، والتحويل العكسي قسمة).
    final rate = _state.todayRate;
    final defaultCost = !_selectedIsBase && rate != null && rate > 0
        ? info.item.costPrice / rate
        : info.item.costPrice;
    final existing = _lineIndexOf(info.item.id);
    if (existing >= 0) {
      _updateLine(existing, qty: _state.lines[existing].qty + 1);
      return;
    }
    _state = purchaseCartStateWith(
      _state,
      lines: [
        ..._state.lines,
        PurchaseCartUiLine(
          productId: info.item.id,
          name: info.item.name,
          qty: 1,
          unitCost: defaultCost,
          discountType: PurchaseDiscountType.amount,
          discountValue: 0,
          currentStock: currentStock,
          isService: info.item.isService,
          trackBatches: info.item.trackBatches,
        ),
      ],
      postError: null,
    );
    notifyListeners();
  }

  /// تعديل الكمية — القيم غير الصالحة (≤ 0 أو غير رقمية) ترفض فوراً.
  void setQty(int index, double qty) {
    if (qty.isNaN || qty.isInfinite || qty <= 0) {
      _notice('الكمية يجب أن تكون رقماً أكبر من صفر.');
      return;
    }
    _updateLine(index, qty: qty);
  }

  /// تعديل الكمية المجانية/بونص من المورد (R16-a — دائم التوفر): ≥ 0
  /// وبرقم سليم وبلا دقة أعلى من ثلاث منازل (NUMERIC(12,3)). الصفر يمسح
  /// البونص. لا أثر إطلاقاً على الصافي المستحق للمورد.
  void setFreeQty(int index, double freeQty) {
    if (freeQty.isNaN || freeQty.isInfinite || freeQty < 0) {
      _notice('كمية البونص لا يمكن أن تكون سالبة — أدخل رقماً سليماً.');
      return;
    }
    if (((freeQty * 1000).roundToDouble() - freeQty * 1000).abs() > 0.001) {
      _notice('كمية البونص لا تقبل دقة أعلى من ثلاث منازل عشرية.');
      return;
    }
    _updateLine(index, freeQty: freeQty);
  }

  /// تعديل تكلفة الوحدة بعملة الفاتورة (≥ 0).
  void setUnitCost(int index, double cost) {
    if (cost.isNaN || cost.isInfinite || cost < 0) {
      _notice('تكلفة الوحدة لا يمكن أن تكون سالباً.');
      return;
    }
    _updateLine(index, unitCost: cost);
  }

  /// تعديل خصم السطر (٪ ضمن 0–100 / مبلغ ≥ 0).
  void setLineDiscount(int index, PurchaseDiscountType type, double value) {
    if (value.isNaN || value.isInfinite || value < 0) {
      _notice('قيمة الخصم لا يمكن أن تكون سالبة.');
      return;
    }
    if (type == PurchaseDiscountType.percent && value > 100) {
      _notice('نسبة الخصم لا يمكن أن تتجاوز 100%.');
      return;
    }
    _updateLine(index, discountType: type, discountValue: value);
  }

  /// رقم الدفعة الواردة للسطر (للمتتبعين).
  void setBatchNo(int index, String batchNo) {
    if (index < 0 || index >= _state.lines.length) return;
    final lines = [..._state.lines];
    lines[index] = lines[index].copyWith(
      batchNo: batchNo.trim(),
      // حذف الرقم يصفّر الصلاحية المرافقة (لا دفعة بلا رقم).
      expiryDate: batchNo.trim().isEmpty ? null : lines[index].expiryDate,
    );
    _state = purchaseCartStateWith(_state, lines: lines, postError: null);
    notifyListeners();
  }

  /// صلاحية الدفعة الواردة للسطر (إلزامية مع رقم الدفعة).
  void setExpiry(int index, DateTime expiry) {
    if (index < 0 || index >= _state.lines.length) return;
    _updateLine(index, expiryDate: expiry);
  }

  /// حذف سطر بالفهرس.
  void removeLine(int index) {
    if (index < 0 || index >= _state.lines.length) return;
    final lines = [..._state.lines]..removeAt(index);
    _state = purchaseCartStateWith(_state, lines: lines);
    notifyListeners();
  }

  /// خصم رأس الفاتورة (نسبة/مبلغ) — يوزَّع pro-rata قبل WAC (5.4-3).
  void setInvoiceDiscount(PurchaseDiscountType type, double value) {
    if (value.isNaN || value.isInfinite || value < 0) {
      _notice('قيمة الخصم لا يمكن أن تكون سالبة.');
      return;
    }
    if (type == PurchaseDiscountType.percent && value > 100) {
      _notice('نسبة خصم الفاتورة لا يمكن أن تتجاوز 100%.');
      return;
    }
    _state = purchaseCartStateWith(
      _state,
      invoiceDiscountType: type,
      invoiceDiscountValue: value,
    );
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────
  // الترحيل والدفع
  // ───────────────────────────────────────────────────────────────────

  /// بناء مسودة الترحيل من الحالة الحالية.
  PurchaseDraft? buildDraft({
    required double paidCash,
    required PurchasePaymentMethod method,
  }) => buildPurchaseDraftFromCart(
    _state,
    paidCash: paidCash,
    method: method,
    now: _clock(),
  );

  /// **ترحيل فاتورة الشراء** — نجاح: تُفرَّغ الفاتورة ويُحفظ الإيصال؛ فشل:
  /// تُعرض رسالة الرفض العربية **والفاتورة لا تُفقد**.
  Future<Result<PurchasePostedReceipt, String>> postPurchase({
    required double paidCash,
    required PurchasePaymentMethod method,
  }) async {
    if (_state.posting) {
      return const Err<PurchasePostedReceipt, String>(
        'ترحيل جارٍ بالفعل — لحظات ويكتمل.',
      );
    }
    final failure = _prePostFailure(paidCash, method);
    if (failure != null) {
      _state = purchaseCartStateWith(_state, postError: failure);
      notifyListeners();
      return Err<PurchasePostedReceipt, String>(failure);
    }
    final draft = buildDraft(paidCash: paidCash, method: method);
    if (draft == null) {
      const message = 'اختر المورد أولاً — لا شراء بلا مورد.';
      _state = purchaseCartStateWith(_state, postError: message);
      notifyListeners();
      return const Err<PurchasePostedReceipt, String>(message);
    }

    _state = purchaseCartStateWith(_state, posting: true, postError: null);
    notifyListeners();
    final result = await _purchases.postPurchase(
      draft,
      userId: _userId ?? 1,
      now: _clock(),
    );
    if (result.isOk) {
      final receipt = result.valueOrNull!;
      _state = purchaseCartStateWith(
        _state,
        posting: false,
        lines: const <PurchaseCartUiLine>[],
        invoiceDiscountType: PurchaseDiscountType.amount,
        invoiceDiscountValue: 0,
        lastReceipt: receipt,
        postError: null,
        notice: null,
        nextInvoiceNo: await _nextPurchasePreview(),
      );
      notifyListeners();
    } else {
      _state = purchaseCartStateWith(
        _state,
        posting: false,
        postError: result.errorOrNull!,
      );
      notifyListeners();
    }
    return result;
  }

  /// فحوص ما قبل الترحيل (بترتيب رسائل واضح للمستخدم) — null عند السلامة.
  /// (FR-08-09: عند غياب سعر اليوم تُرفع بوابة FX وتُخطر الواجهة قبل
  /// إعادة رسالة الرفض — نفس ترتيب الإخطار الأصلي حرفياً.)
  String? _prePostFailure(double paidCash, PurchasePaymentMethod method) {
    final check = purchaseCartPrePostCheck(_state, paidCash, method);
    if (check.fxGateRequired) {
      _state = purchaseCartStateWith(_state, fxGateRequired: true);
      notifyListeners();
    }
    return check.failure;
  }

  // ───────────────────────────────────────────────────────────────────
  // أدوات الجلسة
  // ───────────────────────────────────────────────────────────────────

  /// «شراء جديد» — تفريغ الفاتورة (يبقى المورد/العملة/المخزن للراحة).
  void startNewInvoice() {
    _state = purchaseCartStateWith(
      _state,
      lines: const <PurchaseCartUiLine>[],
      invoiceDiscountType: PurchaseDiscountType.amount,
      invoiceDiscountValue: 0,
      postError: null,
      notice: null,
      lastReceipt: null,
    );
    notifyListeners();
  }

  /// إغلاق إيصال النجاح المعروض (يبدأ شراءً جديداً).
  void dismissReceipt() => startNewInvoice();

  void clearPostError() {
    if (_state.postError == null) return;
    _state = purchaseCartStateWith(_state, postError: null);
    notifyListeners();
  }

  void clearNotice() {
    if (_state.notice == null) return;
    _state = purchaseCartStateWith(_state, notice: null);
    notifyListeners();
  }

  void _notice(String message) {
    _state = purchaseCartStateWith(_state, notice: message);
    notifyListeners();
  }

  bool get _selectedIsBase => _state.selectedCurrency?.isBase ?? true;

  void _updateLine(
    int index, {
    double? qty,
    double? freeQty,
    double? unitCost,
    PurchaseDiscountType? discountType,
    double? discountValue,
    DateTime? expiryDate,
  }) {
    if (index < 0 || index >= _state.lines.length) return;
    final lines = [..._state.lines];
    lines[index] = lines[index].copyWith(
      qty: qty,
      freeQty: freeQty,
      unitCost: unitCost,
      discountType: discountType,
      discountValue: discountValue,
      expiryDate: expiryDate,
    );
    _state = purchaseCartStateWith(
      _state,
      lines: lines,
      postError: null,
      notice: null,
    );
    notifyListeners();
  }

  int _lineIndexOf(int productId) {
    for (var i = 0; i < _state.lines.length; i++) {
      if (_state.lines[i].productId == productId) return i;
    }
    return -1;
  }

  /// معاينة رقم PUR القادم (آخر رقم مُصدر + 1) — عرض فقط، الترقيم الحقيقي
  /// يستهلك ذرّياً داخل معاملة الترحيل. (R18-D1: عبر مستودع المشتريات —
  /// طبقة العرض لا تلمس `core/storage/doc_sequence`.)
  Future<String?> _nextPurchasePreview() async {
    try {
      return await _purchases.previewNextPurchaseNo(_clock().year);
    } catch (_) {
      return null;
    }
  }
}
