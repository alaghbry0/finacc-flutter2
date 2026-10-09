/// نموذج عرض سلة الكاشير — قلب التطبيق (§6.5 / FR-02).
///
/// سلة حية في الذاكرة (ChangeNotifier) تُسعَّر لحظياً عبر `SalePricing`
/// (المجموع/خصومات الأسطر/خصم الرأس/الصافي بلا أي وصول قاعدة أثناء
/// التسوق)، وترحَّل بضغطة عبر `SaleRepository.postSale` الذرّي، أو تُحوَّل
/// عرضَ سعر عبر `QuotationRepository`.
///
/// خطوط حمراء مطبَّقة هنا:
/// - **سياسة FX المفقود** (FR-08-09): اختيار عملة غير الأساس بلا سعر
///   اليوم → علم `fxGateRequired` يفتح BottomSheet إدخال السعر فوراً،
///   ويُمنع الدفع قبل إدخاله.
/// - **عميل نقدي مجهول** (`customerId = null`): نقدي كامل حصراً — الآجل
///   والمختلط يرفضان حتى يُختار عميل.
/// - **الكميات غير الصالحة ترفض فوراً** (لا قيمة ≤ 0 تدخل السلة أبداً).
/// - فشل `postSale` **لا يفقد السلة** — رسالة الرفض العربية تُعرض كما هي.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/storage/doc_sequence.dart';
import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/exchange_rate_repository.dart';
import '../../../../data/repositories/item_repository.dart';
import '../../../../data/repositories/quotation_repository.dart';
import '../../../../data/repositories/sale_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/item.dart';
import '../../../../domain/models/quotation.dart';
import '../../../../domain/models/sale.dart';
import '../../../../domain/services/sale_pricing.dart';

/// تفاوت الكميات عند مقارنة المتاح (NUMERIC(12,3)).
const double _qtyEpsilon = 0.000001;

/// علامة «أبقِ القيمة الحالية» للحقول القابلة للتصفير في `_stateWith`.
const Object _keep = Object();

/// عميل السلة — محدد بالاسم، أو نقدي مجهول (id = null).
class CartCustomer {
  const CartCustomer({
    required this.name,
    this.id,
    this.phone,
    this.creditLimit,
  });

  final int? id;
  final String name;
  final String? phone;

  /// حد الائتمان (null = بلا حد — FR-03-01).
  final double? creditLimit;

  /// عميل نقدي مجهول؟
  bool get isCash => id == null;
}

/// سطر سلة الواجهة — صورة الصنف لحظة إضافته + حقوله القابلة للتحرير.
class CartUiLine {
  const CartUiLine({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.discountType,
    required this.discountValue,
    required this.availableQty,
    required this.isService,
    this.barcode,
    this.costPrice = 0,
    this.freeQty = 0,
  });

  final int productId;
  final String name;
  final String? barcode;

  /// الكمية (> 0 دائماً — القيم غير الصالحة ترفض قبل الدخول).
  final double qty;

  /// الكمية المجانية/بونص (≥ 0 — موجة UX-4؛ دائم التوفر منذ R16-a):
  /// تُدخل من محرر السطر الموحّد (BottomSheet بنقرة على صف السطر).
  /// لا تدخل أي تسعير — المنصرف الكلي (qty + freeQty) يُحسب مخزونياً
  /// وقت الترحيل.
  final double freeQty;

  /// سعر الوحدة بعملة الفاتورة (≥ 0).
  final double unitPrice;

  final SaleDiscountType discountType;
  final double discountValue;

  /// المتاح بالمخزن المحدد لحظة الإضافة (null للخدمي — لا مخزون له).
  final double? availableQty;

  final bool isService;

  /// تكلفة الوحدة بالعملة الأساسية لحظة الإضافة (UX-2a — كشف البيع تحت
  /// التكلفة `invoicing.discount_below_margin`).
  final double costPrice;

  /// تجاوز الكمية للمتاح؟ (FR-02-02 — تحذير بصري بلون تحذيري).
  /// UX-4: المقارنة بالمنصرف الكلي (مدفوع + مجاني) — البونص يخرج من
  /// المخزون مثل المدفوع.
  bool get exceedsAvailable =>
      availableQty != null &&
      qty + freeQty > availableQty! + _qtyEpsilon;

  CartUiLine copyWith({
    double? qty,
    double? freeQty,
    double? unitPrice,
    SaleDiscountType? discountType,
    double? discountValue,
  }) => CartUiLine(
    productId: productId,
    name: name,
    barcode: barcode,
    qty: qty ?? this.qty,
    freeQty: freeQty ?? this.freeQty,
    unitPrice: unitPrice ?? this.unitPrice,
    discountType: discountType ?? this.discountType,
    discountValue: discountValue ?? this.discountValue,
    availableQty: availableQty,
    isService: isService,
    costPrice: costPrice,
  );

  CartLine toCartLine() => CartLine(
    productId: productId,
    qty: qty,
    unitPrice: unitPrice,
    lineDiscountType: discountType,
    lineDiscountValue: discountValue,
    freeQty: freeQty,
  );
}

/// حالة سلة الكاشير الكاملة.
class SellCartState {
  const SellCartState({
    required this.loading,
    this.error,
    required this.currencies,
    this.baseCurrency,
    this.currencyId,
    this.todayRate,
    required this.rateKnown,
    this.customer,
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
    this.overAvailPolicy = 'warn',
    this.showDiscounts = true,
    this.warnBelowMargin = false,
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

  final CartCustomer? customer;
  final int? warehouseId;

  final List<CartUiLine> lines;

  final SaleDiscountType invoiceDiscountType;
  final double invoiceDiscountValue;

  /// ترحيل جارٍ الآن (قفل الأزرار).
  final bool posting;

  /// رسالة رفض آخر ترحيل (تُعرض بوضوح — السلة لا تُفقد).
  final String? postError;

  /// إشعار عابر (باركود غير موجود مثلاً) — يُمسح بعد العرض.
  final String? notice;

  /// رقم INV القادم (معاينة — الترقيم الحقيقي ذرّي داخل المعاملة).
  final String? nextInvoiceNo;

  /// طلب فتح نافذة إدخال سعر اليوم (FR-08-09) — يُستهلك بـ clearFxGate.
  final bool fxGateRequired;

  /// إيصال آخر فاتورة مرحّلة (نجاح — «فاتورة جديدة» تفرّغ السلة).
  final SalePostedReceipt? lastReceipt;

  /// سياسة البيع فوق المتاح (UX-2a — `sale.over_avail_policy`):
  /// `warn` = تحذير بصري فقط (سلوك v0.x)، `block` = منع الترحيل.
  final String overAvailPolicy;

  /// إظهار عناصر الخصم بالكاشير (UX-2a — `sale.show_discounts`).
  final bool showDiscounts;

  /// تحذير البيع تحت التكلفة مفعّل؟ (UX-2a —
  /// `invoicing.discount_below_margin`).
  final bool warnBelowMargin;

  Currency? get selectedCurrency {
    for (final currency in currencies) {
      if (currency.id == currencyId) return currency;
    }
    return null;
  }

  bool get isCustomerSelected => customer != null && customer!.id != null;

  static const SellCartState initial = SellCartState(
    loading: true,
    currencies: <Currency>[],
    rateKnown: true,
    lines: <CartUiLine>[],
    invoiceDiscountType: SaleDiscountType.amount,
    invoiceDiscountValue: 0,
    posting: false,
    overAvailPolicy: 'warn',
    showDiscounts: true,
    warnBelowMargin: false,
  );
}

/// نموذج سلة الكاشير — يعيش الجلسة كاملة عبر [SellCartSession].
class SellCartViewModel extends ChangeNotifier {
  SellCartViewModel({
    required ItemRepository itemRepo,
    required CompanyRepository companyRepo,
    required ExchangeRateRepository fxRepo,
    required SaleRepository saleRepo,
    required QuotationRepository quotationRepo,
    required Database database,
    SettingsRepository? settingsRepo,
    DateTime Function()? clock,
  }) : _items = itemRepo,
       _companies = companyRepo,
       _fx = fxRepo,
       _sales = saleRepo,
       _quotations = quotationRepo,
       _db = database,
       _settings = settingsRepo,
       _clock = clock ?? DateTime.now;

  final ItemRepository _items;
  final CompanyRepository _companies;
  final ExchangeRateRepository _fx;
  final SaleRepository _sales;
  final QuotationRepository _quotations;
  final Database _db;

  /// مستودع الإعدادات (UX-2a) — اختياري: غيابه يبقي سلوك v0.x
  /// (warn / خصومات ظاهرة / بلا تحذير هامش) فلا تنكسر شاشات بلا وصول.
  final SettingsRepository? _settings;

  final DateTime Function() _clock;

  SellCartState _state = SellCartState.initial;
  SellCartState get state => _state;

  int? _userId;
  bool _initialized = false;

  // ───────────────────────────────────────────────────────────────────
  // التحميل (مرة واحدة بالجلسة — السلة تنجو من التنقل بين الشاشات)
  // ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_initialized) {
      // إعادة الدخول للشاشة: تحديث سعر اليوم فقط (السلة كما هي).
      await _refreshRateKnowledge();
      return;
    }
    _state = SellCartState.initial;
    notifyListeners();
    try {
      // سياسات التخصيص (UX-2a) — قراءة واحدة متزامنة مع باقي التحميل؛
      // غياب المستودع يبقي سلوك v0.x (warn/خصومات ظاهرة/بلا تحذير هامش).
      // (R16-a: بوابة البونص أُزيلت — الحقل دائم التوفر بمحرر السطر
      // والشارة ديناميكية عند freeQty>0 حصراً، بلا أي إعداد.)
      var overAvailPolicy = 'warn';
      var showDiscounts = true;
      var warnBelowMargin = false;
      if (_settings != null) {
        final policyResults = await Future.wait<Object?>([
          _settings.overAvailPolicy(),
          _settings.showDiscounts(),
          _settings.discountBelowMargin(),
        ]);
        overAvailPolicy = policyResults[0]! as String;
        showDiscounts = policyResults[1]! as bool;
        warnBelowMargin = policyResults[2]! as bool;
      }
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
      _state = SellCartState(
        loading: false,
        currencies: currencies,
        baseCurrency: base,
        currencyId: base?.id,
        todayRate: null,
        rateKnown: true,
        customer: null,
        warehouseId: warehouseId,
        lines: const <CartUiLine>[],
        invoiceDiscountType: SaleDiscountType.amount,
        invoiceDiscountValue: 0,
        posting: false,
        nextInvoiceNo: await _nextInvoicePreview(),
        overAvailPolicy: overAvailPolicy,
        showDiscounts: showDiscounts,
        warnBelowMargin: warnBelowMargin,
      );
    } catch (error) {
      _state = SellCartState(
        loading: false,
        error: error,
        currencies: const <Currency>[],
        rateKnown: true,
        lines: const <CartUiLine>[],
        invoiceDiscountType: SaleDiscountType.amount,
        invoiceDiscountValue: 0,
        posting: false,
      );
    }
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────
  // التسعير الحي (نقي — بلا قاعدة)
  // ───────────────────────────────────────────────────────────────────

  List<CartLine> get cartLines => [
    for (final line in _state.lines) line.toCartLine(),
  ];

  /// السلة المُسعَّرة الآن — null عند الفراغ أو عدم قابلية التسعير.
  PricedCart? get pricedCart {
    if (_state.lines.isEmpty) return null;
    try {
      return SalePricing.priceCart(
        cartLines,
        invoiceDiscountType: _state.invoiceDiscountType,
        invoiceDiscountValue: _state.invoiceDiscountValue,
      );
    } on StateError {
      return null;
    }
  }

  /// خطأ التحقق الحالي (كميات/أسعار/خصومات/صافٍ > 0) — null عند السلامة.
  String? get cartError => _state.lines.isEmpty
      ? null
      : SalePricing.validateCart(
          cartLines,
          invoiceDiscountType: _state.invoiceDiscountType,
          invoiceDiscountValue: _state.invoiceDiscountValue,
        );

  /// الصافي الحالي (للعرض في زر الدفع) — 0 عند الفراغ.
  double get grandTotal => pricedCart?.totals.grandTotal ?? 0;

  /// أسطر السلة المباعة تحت التكلفة (UX-2a — لافتة تحذير بالكاشير عند
  /// تفعيل `invoicing.discount_below_margin`): يقارن صافي السطر بعد كل
  /// الخصومات بتكلفة الكمية — حكراً على عملة الأساس (التكلفة المحفوظة
  /// بالأساس؛ فاتورة بعملة أخرى تُترك بلا تحذير كاذب).
  List<String> get belowCostLineNames {
    final state = _state;
    if (!state.warnBelowMargin || state.lines.isEmpty) {
      return const <String>[];
    }
    final pricedLines = pricedCart?.lines;
    if (pricedLines == null || pricedLines.length != state.lines.length) {
      return const <String>[];
    }
    final baseId = state.baseCurrency?.id;
    if (baseId == null || state.currencyId != baseId) {
      return const <String>[];
    }
    final names = <String>[];
    for (var i = 0; i < state.lines.length; i++) {
      final line = state.lines[i];
      if (line.isService || line.costPrice <= 0) continue;
      final costTotal = line.costPrice * line.qty;
      if (pricedLines[i].netFinal < costTotal - _qtyEpsilon) {
        names.add(line.name);
      }
    }
    return names;
  }

  // ───────────────────────────────────────────────────────────────────
  // العميل والعملة
  // ───────────────────────────────────────────────────────────────────

  /// اختيار عميل محدد.
  void setCustomer({
    required int id,
    required String name,
    String? phone,
    double? creditLimit,
  }) {
    _state = _stateWith(
      customer: CartCustomer(
        id: id,
        name: name,
        phone: phone,
        creditLimit: creditLimit,
      ),
      postError: null,
    );
    notifyListeners();
  }

  /// رجوع لعميل نقدي مجهول (نقدي كامل حصراً).
  void setCashCustomer() {
    _state = _stateWith(customer: null, postError: null);
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
  // بنود السلة
  // ───────────────────────────────────────────────────────────────────

  /// إضافة صنف (الكمية 1 أو دمج مع سطر موجود لنفس الصنف).
  void addItemFromInfo(ItemStockInfo info) {
    final warehouseId = _state.warehouseId;
    final available = info.item.isService
        ? null
        : (info.warehouseQty[warehouseId] ?? info.totalQty);
    final price = info.retailPrice ?? 0.0;
    final existing = _lineIndexOf(info.item.id);
    if (existing >= 0) {
      _updateLine(existing, qty: _state.lines[existing].qty + 1);
      return;
    }
    _state = _stateWith(
      lines: [
        ..._state.lines,
        CartUiLine(
          productId: info.item.id,
          name: info.item.name,
          barcode: info.item.barcode,
          qty: 1,
          unitPrice: price,
          discountType: SaleDiscountType.amount,
          discountValue: 0,
          availableQty: available,
          isService: info.item.isService,
          // UX-2a: تكلفة اللقطة لكشف البيع تحت التكلفة (عملة الأساس حصراً).
          costPrice: info.item.costPrice,
        ),
      ],
      postError: null,
    );
    notifyListeners();
  }

  /// مسح باركود بإدخال يدوي — أول تطابق يضاف مباشرة بكمية 1.
  Future<bool> addByBarcode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;
    final info = await _items.findByBarcode(
      trimmed,
      currencyId: _state.currencyId,
    );
    if (info == null) {
      _notice('لا صنف بباركود «$trimmed» — تأكد من الرقم أو أضفه من القائمة.');
      return false;
    }
    addItemFromInfo(info);
    return true;
  }

  /// تعديل الكمية — القيم غير الصالحة (≤ 0 أو غير رقمية) ترفض فوراً.
  void setQty(int index, double qty) {
    if (qty.isNaN || qty.isInfinite || qty <= 0) {
      _notice('الكمية يجب أن تكون رقماً أكبر من صفر.');
      return;
    }
    _updateLine(index, qty: qty);
  }

  /// تعديل الكمية المجانية (بونص — UX-4، دائم التوفر منذ R16-a): ≥ 0
  /// وبرقم سليم وبلا دقة أعلى من ثلاث منازل (NUMERIC(12,3)). الصفر يمسح
  /// البونص. الإدخال من محرر السطر الموحّد (نقرة على صف السطر) — لا
  /// بوابة إعدادات بعد الآن.
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

  /// تعديل سعر الوحدة (≥ 0).
  void setUnitPrice(int index, double price) {
    if (price.isNaN || price.isInfinite || price < 0) {
      _notice('السعر لا يمكن أن يكون سالباً.');
      return;
    }
    _updateLine(index, unitPrice: price);
  }

  /// تعديل خصم السطر (٪ ضمن 0–100 / مبلغ ≥ 0).
  void setLineDiscount(int index, SaleDiscountType type, double value) {
    if (value.isNaN || value.isInfinite || value < 0) {
      _notice('قيمة الخصم لا يمكن أن تكون سالبة.');
      return;
    }
    if (type == SaleDiscountType.percent && value > 100) {
      _notice('نسبة الخصم لا يمكن أن تتجاوز 100%.');
      return;
    }
    _updateLine(index, discountType: type, discountValue: value);
  }

  /// حذف سطر بالفهرس.
  void removeLine(int index) {
    if (index < 0 || index >= _state.lines.length) return;
    final lines = [..._state.lines]..removeAt(index);
    _state = _stateWith(lines: lines);
    notifyListeners();
  }

  /// خصم رأس الفاتورة (نسبة/مبلغ).
  void setInvoiceDiscount(SaleDiscountType type, double value) {
    if (value.isNaN || value.isInfinite || value < 0) {
      _notice('قيمة الخصم لا يمكن أن تكون سالبة.');
      return;
    }
    if (type == SaleDiscountType.percent && value > 100) {
      _notice('نسبة خصم الفاتورة لا يمكن أن تتجاوز 100%.');
      return;
    }
    _state = _stateWith(invoiceDiscountType: type, invoiceDiscountValue: value);
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────
  // الترحيل والدفع
  // ───────────────────────────────────────────────────────────────────

  /// بناء مسودة الترحيل من الحالة الحالية (للاستخدام الداخلي والاختبارات).
  SaleDraft? buildDraft({
    required double paidCash,
    required SalePaymentMethod method,
  }) {
    final currencyId = _state.currencyId;
    final warehouseId = _state.warehouseId;
    if (currencyId == null || warehouseId == null) return null;
    return SaleDraft(
      customerId: _state.customer?.id,
      currencyId: currencyId,
      lines: cartLines,
      invoiceDiscountType: _state.invoiceDiscountType,
      invoiceDiscountValue: _state.invoiceDiscountValue,
      paidCash: paidCash,
      paymentMethod: method,
      warehouseId: warehouseId,
      issuedAt: _clock(),
    );
  }

  /// **ترحيل الفاتورة** — نجاح: تُفرَّغ السلة ويُحفظ الإيصال؛ فشل: تُعرض
  /// رسالة الرفض العربية **والسلة لا تُفقد**.
  Future<Result<SalePostedReceipt, String>> postSale({
    required double paidCash,
    required SalePaymentMethod method,
  }) async {
    if (_state.posting) {
      return const Err<SalePostedReceipt, String>(
        'ترحيل جارٍ بالفعل — لحظات ويكتمل.',
      );
    }
    final failure = _prePostFailure(paidCash, method);
    if (failure != null) {
      _state = _stateWith(postError: failure);
      notifyListeners();
      return Err<SalePostedReceipt, String>(failure);
    }
    final draft = buildDraft(paidCash: paidCash, method: method);
    if (draft == null) {
      const message = 'الإعدادات غير مكتملة (العملة/المخزن) — أعد فتح الشاشة.';
      _state = _stateWith(postError: message);
      notifyListeners();
      return const Err<SalePostedReceipt, String>(message);
    }

    _state = _stateWith(posting: true, postError: null);
    notifyListeners();
    final result = await _sales.postSale(
      draft,
      userId: _userId ?? 1,
      now: _clock(),
    );
    if (result.isOk) {
      final receipt = result.valueOrNull!;
      _state = _stateWith(
        posting: false,
        lines: const <CartUiLine>[],
        invoiceDiscountType: SaleDiscountType.amount,
        invoiceDiscountValue: 0,
        lastReceipt: receipt,
        postError: null,
        notice: null,
        nextInvoiceNo: await _nextInvoicePreview(),
      );
      notifyListeners();
    } else {
      _state = _stateWith(posting: false, postError: result.errorOrNull!);
      notifyListeners();
    }
    return result;
  }

  /// فحوص ما قبل الترحيل (بترتيب رسائل واضح للمستخدم) — null عند السلامة.
  String? _prePostFailure(double paidCash, SalePaymentMethod method) {
    if (_state.lines.isEmpty) {
      return 'أضف بنداً واحداً على الأقل إلى الفاتورة قبل الدفع.';
    }
    final cartFailure = cartError;
    if (cartFailure != null) return cartFailure;
    final currency = _state.selectedCurrency;
    if (currency == null) return 'اختر عملة الفاتورة أولاً.';
    if (!currency.isBase && !_state.rateKnown) {
      // FR-08-09: منع الحفظ + طلب فتح بوابة إدخال سعر اليوم.
      _state = _stateWith(fxGateRequired: true);
      notifyListeners();
      return 'لا يوجد سعر صرف لعملة ${currency.code} بتاريخ اليوم — '
          'أدخل سعر اليوم أولاً ثم أكمل الدفع.';
    }
    final total = grandTotal;
    final payFailure = SalePricing.validatePayment(total, paidCash, method);
    if (payFailure != null) return payFailure;
    // UX-2a — `sale.over_avail_policy` = block: أي سطر يتجاوز المتاح يمنع
    // الترحيل من هنا (warn = سلوك v0.x: تحذير بصري فقط والمستودع حارس
    // أخير برسالته الخاصة).
    if (_state.overAvailPolicy == 'block') {
      for (final line in _state.lines) {
        if (line.exceedsAvailable) {
          return 'لا يمكن الترحيل: كمية «${line.name}» تتجاوز المتاح '
              '(${_qtyText(line.availableQty!)}) — سياسة «منع البيع فوق '
              'المتاح» مفعّلة من تفضيلات البيع. خفّض الكمية أو عوّض '
              'المخزون أولاً.';
        }
      }
    }
    // عميل نقدي مجهول: نقدي كامل حصراً (الآجل يحتاج حساباً معروفاً).
    final settlement = SalePricing.settlePayment(total, paidCash);
    if (settlement.remainingCredit > moneyEpsilon &&
        !_state.isCustomerSelected) {
      return 'البيع الآجل يتطلب اختيار عميل أولاً — العميل النقدي المجهول '
          'يسدد نقداً كاملاً فقط.';
    }
    return null;
  }

  // ───────────────────────────────────────────────────────────────────
  // عرض السعر (FR-02-11)
  // ───────────────────────────────────────────────────────────────────

  /// مدة الصلاحية الافتراضية لعرض السعر المحفوظ من السلة (P2-5) —
  /// +30 يوماً إن لم يمرّر المستدعي صلاحية صريحة.
  static const Duration quotationDefaultValidity = Duration(days: 30);

  /// حفظ السلة الحالية كعرض سعر QTE — بلا أي حركة مخزون/صندوق.
  /// السلة تبقى كما هي (يمكن المتابعة في البيع أو التفريغ من الشاشة).
  ///
  /// [validUntil] (P2-5): صلاحية صريحة — والافتراضي +30 يوماً من لحظة
  /// الحفظ (مسار الحفظ لا يمرّ بنموذج إدخال في هذه الجولة).
  Future<Result<Quotation, String>> saveAsQuotation({
    DateTime? validUntil,
  }) async {
    if (_state.lines.isEmpty) {
      return const Err<Quotation, String>(
        'أضف بنداً واحداً على الأقل قبل حفظ عرض السعر.',
      );
    }
    final cartFailure = cartError;
    if (cartFailure != null) {
      return Err<Quotation, String>(cartFailure);
    }
    final currencyId = _state.currencyId;
    final warehouseId = _state.warehouseId;
    if (currencyId == null || warehouseId == null) {
      return const Err<Quotation, String>(
        'الإعدادات غير مكتملة (العملة/المخزن) — أعد فتح الشاشة.',
      );
    }
    return _quotations.createQuotation(
      QuotationDraft(
        customerId: _state.customer?.id,
        currencyId: currencyId,
        warehouseId: warehouseId,
        lines: [
          for (final line in _state.lines)
            QuotationLine(
              productId: line.productId,
              qty: line.qty,
              unitPrice: line.unitPrice,
              lineDiscountType: line.discountType,
              lineDiscountValue: line.discountValue,
            ),
        ],
        invoiceDiscountType: _state.invoiceDiscountType,
        invoiceDiscountValue: _state.invoiceDiscountValue,
        // P2-5: الصلاحية الافتراضية +30 يوماً عند غياب صلاحية صريحة.
        validUntil: validUntil ?? _clock().add(quotationDefaultValidity),
        issuedAt: _clock(),
      ),
      userId: _userId ?? 1,
      now: _clock(),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // أدوات الجلسة
  // ───────────────────────────────────────────────────────────────────

  /// «فاتورة جديدة» — تفريغ السلة (يبقي العميل/العملة/المخزن لراحة الكاشير).
  void startNewInvoice() {
    _state = _stateWith(
      lines: const <CartUiLine>[],
      invoiceDiscountType: SaleDiscountType.amount,
      invoiceDiscountValue: 0,
      postError: null,
      notice: null,
      lastReceipt: null,
    );
    notifyListeners();
  }

  /// إغلاق إيصال النجاح المعروض (يبدأ فاتورة جديدة).
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

  void _updateLine(
    int index, {
    double? qty,
    double? freeQty,
    double? unitPrice,
    SaleDiscountType? discountType,
    double? discountValue,
  }) {
    if (index < 0 || index >= _state.lines.length) return;
    final lines = [..._state.lines];
    lines[index] = lines[index].copyWith(
      qty: qty,
      freeQty: freeQty,
      unitPrice: unitPrice,
      discountType: discountType,
      discountValue: discountValue,
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

  /// نص كمية للرسائل (نفس نمط sellQtyText بلا استيراد طبقة العرض).
  static String _qtyText(double qty) => qty == qty.truncateToDouble()
      ? qty.truncate().toString()
      : qty.toStringAsFixed(3);

  /// معاينة رقم INV القادم (آخر رقم مُصدر + 1) — عرض فقط، الترقيم الحقيقي
  /// يستهلك ذرّياً داخل معاملة الترحيل.
  Future<String?> _nextInvoicePreview() async {
    try {
      final year = _clock().year;
      final last = await DocSequenceService(_db)
          .lastIssuedNumber(DocSequenceType.invoice, year);
      return formatDocNumber(DocSequenceType.invoice, year, last + 1);
    } catch (_) {
      return null;
    }
  }

  /// نسخة حالة محدَّثة — للحقول القابلة للتصفير (customer/postError/notice/
  /// todayRate/lastReceipt): حذف الوسيطة أو تمرير null يصفّرها، وتمرير
  /// `_keep` يبقيها. بقية الحقول: حذف الوسيطة يبقيها.
  SellCartState _stateWith({
    bool? loading,
    List<Currency>? currencies,
    Object? baseCurrency = _keep,
    int? currencyId,
    Object? todayRate = _keep,
    bool? rateKnown,
    Object? customer = _keep,
    int? warehouseId,
    List<CartUiLine>? lines,
    SaleDiscountType? invoiceDiscountType,
    double? invoiceDiscountValue,
    bool? posting,
    Object? postError = _keep,
    Object? notice = _keep,
    String? nextInvoiceNo,
    bool? fxGateRequired,
    Object? lastReceipt = _keep,
    String? overAvailPolicy,
    bool? showDiscounts,
    bool? warnBelowMargin,
  }) => SellCartState(
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
    customer: identical(customer, _keep)
        ? _state.customer
        : customer as CartCustomer?,
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
        : lastReceipt as SalePostedReceipt?,
    overAvailPolicy: overAvailPolicy ?? _state.overAvailPolicy,
    showDiscounts: showDiscounts ?? _state.showDiscounts,
    warnBelowMargin: warnBelowMargin ?? _state.warnBelowMargin,
  );
}
