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
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/storage/doc_sequence.dart';
import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/exchange_rate_repository.dart';
import '../../../../data/repositories/purchase_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/item.dart';
import '../../../../domain/models/purchase.dart';
import '../../../../domain/services/purchase_pricing.dart';

/// علامة «أبقِ القيمة الحالية» للحقول القابلة للتصفير في `_stateWith`.
const Object _keep = Object();

/// مورد فاتورة الشراء — إلزامي (لا مورد مجهول في الشراء).
class CartSupplier {
  const CartSupplier({required this.id, required this.name, this.phone});

  final int id;
  final String name;
  final String? phone;
}

/// سطر شراء حي — صورة الصنف لحظة إضافته + حقوله القابلة للتحرير،
/// وحقول الدفعة الواردة (رقم الدفعة + الصلاحية) للأصناف المتتبعة.
class PurchaseCartUiLine {
  const PurchaseCartUiLine({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitCost,
    required this.discountType,
    required this.discountValue,
    required this.currentStock,
    required this.isService,
    required this.trackBatches,
    this.batchNo = '',
    this.expiryDate,
  });

  final int productId;
  final String name;

  /// الكمية (> 0 دائماً — القيم غير الصالحة ترفض قبل الدخول).
  final double qty;

  /// تكلفة الوحدة بعملة الفاتورة كما في فاتورة المورد (≥ 0).
  final double unitCost;

  final PurchaseDiscountType discountType;
  final double discountValue;

  /// الرصيد الحالي بالمخزن (معلوماتي — الوارد يُضاف فوقه، لا سقف للشراء).
  final double? currentStock;

  final bool isService;

  /// يتتبع الدفعات؟ → رقم الدفعة إلزامي قبل الترحيل.
  final bool trackBatches;

  /// رقم الدفعة الواردة (فارغ = لم يُدخل بعد).
  final String batchNo;

  /// صلاحية الدفعة الواردة (إلزامية مع رقم الدفعة).
  final DateTime? expiryDate;

  PurchaseCartUiLine copyWith({
    double? qty,
    double? unitCost,
    PurchaseDiscountType? discountType,
    double? discountValue,
    String? batchNo,
    DateTime? expiryDate,
  }) => PurchaseCartUiLine(
    productId: productId,
    name: name,
    qty: qty ?? this.qty,
    unitCost: unitCost ?? this.unitCost,
    discountType: discountType ?? this.discountType,
    discountValue: discountValue ?? this.discountValue,
    currentStock: currentStock,
    isService: isService,
    trackBatches: trackBatches,
    batchNo: batchNo ?? this.batchNo,
    expiryDate: expiryDate ?? this.expiryDate,
  );

  PurchaseLine toPurchaseLine() => PurchaseLine(
    productId: productId,
    qty: qty,
    unitCost: unitCost,
    lineDiscountType: discountType,
    lineDiscountValue: discountValue,
    batchNo: batchNo.trim().isEmpty ? null : batchNo.trim(),
    expiryDate: batchNo.trim().isEmpty ? null : expiryDate,
  );
}

/// حالة فاتورة الشراء الحية الكاملة.
class PurchaseCartState {
  const PurchaseCartState({
    required this.loading,
    this.error,
    required this.currencies,
    this.baseCurrency,
    this.currencyId,
    this.todayRate,
    required this.rateKnown,
    this.supplier,
    this.warehouseId,
    required this.lines,
    required this.invoiceDiscountType,
    required this.invoiceDiscountValue,
    required this.posting,
    this.postError,
    this.notice,
    this.nextInvoiceNo,
    this.fxGateRequired = false,
    this.lastReceipt,
  });

  final bool loading;
  final Object? error;

  /// العملات النشطة (الأساس أولاً).
  final List<Currency> currencies;
  final Currency? baseCurrency;

  /// عملة الفاتورة المحددة (الأساس افتراضياً).
  final int? currencyId;

  /// سعر اليوم للعملة المحددة (null للأساس أو عند الغياب).
  final double? todayRate;

  /// هل سعر اليوم معروف للعملة المحددة؟ (الأساس = true دائماً).
  final bool rateKnown;

  final CartSupplier? supplier;
  final int? warehouseId;

  final List<PurchaseCartUiLine> lines;

  final PurchaseDiscountType invoiceDiscountType;
  final double invoiceDiscountValue;

  /// ترحيل جارٍ الآن (قفل الأزرار).
  final bool posting;

  /// رسالة رفض آخر ترحيل (تُعرض بوضوح — الفاتورة لا تُفقد).
  final String? postError;

  /// إشعار عابر — يُمسح بعد العرض.
  final String? notice;

  /// رقم PUR القادم (معاينة — الترقيم الحقيقي ذرّي داخل المعاملة).
  final String? nextInvoiceNo;

  /// طلب فتح نافذة إدخال سعر اليوم (FR-08-09).
  final bool fxGateRequired;

  /// إيصال آخر فاتورة شراء مُرحَّلة (نجاح — «شراء جديد» يفرّغ الفاتورة).
  final PurchasePostedReceipt? lastReceipt;

  Currency? get selectedCurrency {
    for (final currency in currencies) {
      if (currency.id == currencyId) return currency;
    }
    return null;
  }

  static const PurchaseCartState initial = PurchaseCartState(
    loading: true,
    currencies: <Currency>[],
    rateKnown: true,
    lines: <PurchaseCartUiLine>[],
    invoiceDiscountType: PurchaseDiscountType.amount,
    invoiceDiscountValue: 0,
    posting: false,
  );
}

/// نموذج فاتورة الشراء الحية — يعيش الجلسة عبر [PurchaseCartSession].
class PurchaseCartViewModel extends ChangeNotifier {
  PurchaseCartViewModel({
    required CompanyRepository companyRepo,
    required ExchangeRateRepository fxRepo,
    required PurchaseRepository purchaseRepo,
    required Database database,
    DateTime Function()? clock,
  }) : _companies = companyRepo,
       _fx = fxRepo,
       _purchases = purchaseRepo,
       _db = database,
       _clock = clock ?? DateTime.now;

  final CompanyRepository _companies;
  final ExchangeRateRepository _fx;
  final PurchaseRepository _purchases;
  final Database _db;
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
        todayRate: null,
        rateKnown: true,
        supplier: null,
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

  List<PurchaseLine> get purchaseLines => [
    for (final line in _state.lines) line.toPurchaseLine(),
  ];

  /// الفاتورة المُسعَّرة الآن — null عند الفراغ أو عدم قابلية التسعير.
  PricedPurchaseCart? get pricedCart {
    if (_state.lines.isEmpty) return null;
    try {
      return PurchasePricing.priceCart(
        purchaseLines,
        invoiceDiscountType: _state.invoiceDiscountType,
        invoiceDiscountValue: _state.invoiceDiscountValue,
      );
    } on StateError {
      return null;
    }
  }

  /// خطأ التحقق الحالي (كميات/تكاليف/خصومات/صافٍ > 0/دفعات واردة) —
  /// null عند السلامة.
  String? get cartError {
    if (_state.lines.isEmpty) return null;
    final failure = PurchasePricing.validateCart(
      purchaseLines,
      invoiceDiscountType: _state.invoiceDiscountType,
      invoiceDiscountValue: _state.invoiceDiscountValue,
    );
    if (failure != null) return failure;
    // قرار المحرك 4: الواجهة تُلزم رقم الدفعة للأصناف المتتبعة (رصيد
    // المتتبع بلا دفعة لا يظهر متاحاً للبيع).
    for (final line in _state.lines) {
      if (!line.isService && line.trackBatches && line.batchNo.trim().isEmpty) {
        return 'الصنف «${line.name}» يتتبع الدفعات — أدخل رقم الدفعة '
            'وتاريخ صلاحيتها في سطره قبل الترحيل.';
      }
    }
    return null;
  }

  /// الصافي الحالي (للعرض في زر الترحيل) — 0 عند الفراغ.
  double get grandTotal => pricedCart?.totals.grandTotal ?? 0;

  // ───────────────────────────────────────────────────────────────────
  // المورد والعملة
  // ───────────────────────────────────────────────────────────────────

  /// اختيار مورد (إلزامي — لا شراء بلا مورد).
  void setSupplier({required int id, required String name, String? phone}) {
    _state = _stateWith(
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
    _state = _stateWith(
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
    _state = _stateWith(fxGateRequired: false);
    notifyListeners();
  }

  Future<void> _refreshRateKnowledge() async {
    final currencyId = _state.currencyId;
    if (currencyId == null) return;
    final currency = _currencyById(currencyId);
    if (currency == null || currency.isBase) {
      _state = _stateWith(
        todayRate: null,
        rateKnown: true,
        fxGateRequired: false,
      );
      notifyListeners();
      return;
    }
    final rate = await _fx.rateFor(currencyId, _clock());
    final known = rate != null && rate > 0;
    _state = _stateWith(
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
    _state = _stateWith(
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
    _state = _stateWith(lines: lines, postError: null);
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
    _state = _stateWith(lines: lines);
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
    _state = _stateWith(invoiceDiscountType: type, invoiceDiscountValue: value);
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────
  // الترحيل والدفع
  // ───────────────────────────────────────────────────────────────────

  /// بناء مسودة الترحيل من الحالة الحالية.
  PurchaseDraft? buildDraft({
    required double paidCash,
    required PurchasePaymentMethod method,
  }) {
    final currencyId = _state.currencyId;
    final warehouseId = _state.warehouseId;
    final supplier = _state.supplier;
    if (currencyId == null || warehouseId == null || supplier == null) {
      return null;
    }
    return PurchaseDraft(
      supplierId: supplier.id,
      currencyId: currencyId,
      lines: purchaseLines,
      invoiceDiscountType: _state.invoiceDiscountType,
      invoiceDiscountValue: _state.invoiceDiscountValue,
      paidCash: paidCash,
      paymentMethod: method,
      warehouseId: warehouseId,
      issuedAt: _clock(),
    );
  }

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
      _state = _stateWith(postError: failure);
      notifyListeners();
      return Err<PurchasePostedReceipt, String>(failure);
    }
    final draft = buildDraft(paidCash: paidCash, method: method);
    if (draft == null) {
      const message = 'اختر المورد أولاً — لا شراء بلا مورد.';
      _state = _stateWith(postError: message);
      notifyListeners();
      return const Err<PurchasePostedReceipt, String>(message);
    }

    _state = _stateWith(posting: true, postError: null);
    notifyListeners();
    final result = await _purchases.postPurchase(
      draft,
      userId: _userId ?? 1,
      now: _clock(),
    );
    if (result.isOk) {
      final receipt = result.valueOrNull!;
      _state = _stateWith(
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
      _state = _stateWith(posting: false, postError: result.errorOrNull!);
      notifyListeners();
    }
    return result;
  }

  /// فحوص ما قبل الترحيل — null عند السلامة.
  String? _prePostFailure(double paidCash, PurchasePaymentMethod method) {
    if (_state.lines.isEmpty) {
      return 'أضف بنداً واحداً على الأقل إلى فاتورة الشراء قبل الترحيل.';
    }
    final cartFailure = cartError;
    if (cartFailure != null) return cartFailure;
    final supplier = _state.supplier;
    if (supplier == null) {
      return 'اختر المورد أولاً — لا شراء بلا مورد.';
    }
    final currency = _state.selectedCurrency;
    if (currency == null) return 'اختر عملة الفاتورة أولاً.';
    if (!currency.isBase && !_state.rateKnown) {
      // FR-08-09: منع الحفظ + طلب فتح بوابة إدخال سعر اليوم.
      _state = _stateWith(fxGateRequired: true);
      notifyListeners();
      return 'لا يوجد سعر صرف لعملة ${currency.code} بتاريخ اليوم — '
          'أدخل سعر اليوم أولاً ثم أكمل الترحيل.';
    }
    final total = grandTotal;
    return PurchasePricing.validatePayment(total, paidCash, method);
  }

  // ───────────────────────────────────────────────────────────────────
  // أدوات الجلسة
  // ───────────────────────────────────────────────────────────────────

  /// «شراء جديد» — تفريغ الفاتورة (يبقى المورد/العملة/المخزن للراحة).
  void startNewInvoice() {
    _state = _stateWith(
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
    _state = _stateWith(postError: null);
    notifyListeners();
  }

  void clearNotice() {
    if (_state.notice == null) return;
    _state = _stateWith(notice: null);
    notifyListeners();
  }

  void _notice(String message) {
    _state = _stateWith(notice: message);
    notifyListeners();
  }

  bool get _selectedIsBase => _state.selectedCurrency?.isBase ?? true;

  void _updateLine(
    int index, {
    double? qty,
    double? unitCost,
    PurchaseDiscountType? discountType,
    double? discountValue,
    DateTime? expiryDate,
  }) {
    if (index < 0 || index >= _state.lines.length) return;
    final lines = [..._state.lines];
    lines[index] = lines[index].copyWith(
      qty: qty,
      unitCost: unitCost,
      discountType: discountType,
      discountValue: discountValue,
      expiryDate: expiryDate,
    );
    _state = _stateWith(lines: lines, postError: null, notice: null);
    notifyListeners();
  }

  int _lineIndexOf(int productId) {
    for (var i = 0; i < _state.lines.length; i++) {
      if (_state.lines[i].productId == productId) return i;
    }
    return -1;
  }

  /// معاينة رقم PUR القادم (آخر رقم مُصدر + 1) — عرض فقط، الترقيم الحقيقي
  /// يستهلك ذرّياً داخل معاملة الترحيل.
  Future<String?> _nextPurchasePreview() async {
    try {
      final year = _clock().year;
      final last = await DocSequenceService(_db)
          .lastIssuedNumber(DocSequenceType.purchase, year);
      return formatDocNumber(DocSequenceType.purchase, year, last + 1);
    } catch (_) {
      return null;
    }
  }

  /// نسخة حالة محدَّثة — للحقول القابلة للتصفير (supplier/postError/notice/
  /// todayRate/lastReceipt): حذف الوسيطة أو تمرير null يصفّرها، وتمرير
  /// `_keep` يبقيها. بقية الحقول: حذف الوسيطة يبقيها.
  PurchaseCartState _stateWith({
    bool? loading,
    List<Currency>? currencies,
    Object? baseCurrency = _keep,
    int? currencyId,
    Object? todayRate = _keep,
    bool? rateKnown,
    Object? supplier = _keep,
    int? warehouseId,
    List<PurchaseCartUiLine>? lines,
    PurchaseDiscountType? invoiceDiscountType,
    double? invoiceDiscountValue,
    bool? posting,
    Object? postError = _keep,
    Object? notice = _keep,
    String? nextInvoiceNo,
    bool? fxGateRequired,
    Object? lastReceipt = _keep,
  }) => PurchaseCartState(
    loading: loading ?? _state.loading,
    error: _state.error,
    currencies: currencies ?? _state.currencies,
    baseCurrency: identical(baseCurrency, _keep)
        ? _state.baseCurrency
        : baseCurrency as Currency?,
    currencyId: currencyId ?? _state.currencyId,
    todayRate: identical(todayRate, _keep)
        ? _state.todayRate
        : todayRate as double?,
    rateKnown: rateKnown ?? _state.rateKnown,
    supplier: identical(supplier, _keep)
        ? _state.supplier
        : supplier as CartSupplier?,
    warehouseId: warehouseId ?? _state.warehouseId,
    lines: lines ?? _state.lines,
    invoiceDiscountType: invoiceDiscountType ?? _state.invoiceDiscountType,
    invoiceDiscountValue: invoiceDiscountValue ?? _state.invoiceDiscountValue,
    posting: posting ?? _state.posting,
    postError: identical(postError, _keep)
        ? _state.postError
        : postError as String?,
    notice: identical(notice, _keep) ? _state.notice : notice as String?,
    nextInvoiceNo: nextInvoiceNo ?? _state.nextInvoiceNo,
    fxGateRequired: fxGateRequired ?? _state.fxGateRequired,
    lastReceipt: identical(lastReceipt, _keep)
        ? _state.lastReceipt
        : lastReceipt as PurchasePostedReceipt?,
  );
}
