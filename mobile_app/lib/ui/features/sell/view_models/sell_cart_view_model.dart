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
///
/// (R19-D3a: الأنواع النقية والحالة ونسخها في `sell_cart_state.dart`
/// والحسابات والتحقق والخَرائط في `sell_cart_helpers.dart` — تُصدَّر
/// الأولى من هنا فبقيت استيرادات المستدعين كما هي.)
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/exchange_rate_repository.dart';
import '../../../../data/repositories/item_repository.dart';
import '../../../../data/repositories/quotation_repository.dart';
import '../../../../data/repositories/sale_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/item.dart';
import '../../../../domain/models/quotation.dart';
import '../../../../domain/models/sale.dart';
import 'sell_cart_helpers.dart';
import 'sell_cart_state.dart';

export 'sell_cart_state.dart';

/// نموذج سلة الكاشير — يعيش الجلسة كاملة عبر [SellCartSession].
class SellCartViewModel extends ChangeNotifier {
  SellCartViewModel({
    required ItemRepository itemRepo,
    required CompanyRepository companyRepo,
    required ExchangeRateRepository fxRepo,
    required SaleRepository saleRepo,
    required QuotationRepository quotationRepo,

    /// مقبض القاعدة — يُبقى حصراً لتوافق الاستدعاءات القائمة (الجلسات/
    /// الشاشات/الاختبارات)؛ لم يعد يُستعمل داخل النموذج منذ R18-D1:
    /// معاينة رقم الفاتورة صارت عبر `SaleRepository.previewNextInvoiceNo`.
    required Database database,
    SettingsRepository? settingsRepo,
    DateTime Function()? clock,
  }) : _items = itemRepo,
       _companies = companyRepo,
       _fx = fxRepo,
       _sales = saleRepo,
       _quotations = quotationRepo,
       _settings = settingsRepo,
       _clock = clock ?? DateTime.now;

  final ItemRepository _items;
  final CompanyRepository _companies;
  final ExchangeRateRepository _fx;
  final SaleRepository _sales;
  final QuotationRepository _quotations;

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
      final bootstrap = await loadSellCartBootstrap(
        companies: _companies,
        settings: _settings,
      );
      _userId = bootstrap.userId;

      _initialized = true;
      _state = sellCartLoadedState(bootstrap, await _nextInvoicePreview());
    } catch (error) {
      _state = sellCartErrorState(error);
    }
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────
  // التسعير الحي (نقي — بلا قاعدة)
  // ───────────────────────────────────────────────────────────────────

  List<CartLine> get cartLines => sellCartLines(_state);

  /// السلة المُسعَّرة الآن — null عند الفراغ أو عدم قابلية التسعير.
  PricedCart? get pricedCart => sellCartPricedCart(_state);

  /// خطأ التحقق الحالي (كميات/أسعار/خصومات/صافٍ > 0) — null عند السلامة.
  String? get cartError => sellCartError(_state);

  /// الصافي الحالي (للعرض في زر الدفع) — 0 عند الفراغ.
  double get grandTotal => pricedCart?.totals.grandTotal ?? 0;

  /// أسطر السلة المباعة تحت التكلفة (UX-2a — لافتة تحذير بالكاشير عند
  /// تفعيل `invoicing.discount_below_margin`).
  List<String> get belowCostLineNames => sellCartBelowCostLineNames(_state);

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
    _state = sellCartStateWith(
      _state,
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
    _state = sellCartStateWith(_state, customer: null, postError: null);
    notifyListeners();
  }

  /// اختيار عملة الفاتورة — عند عملة غير الأساس بلا سعر اليوم تُفتح
  /// بوابة الإدخال فوراً (FR-08-09).
  Future<void> setCurrency(int currencyId) async {
    if (currencyId == _state.currencyId) return;
    final currency = sellCartCurrencyById(_state, currencyId);
    final isBase = currency?.isBase ?? false;
    var rateKnown = true;
    double? rate;
    if (!isBase) {
      rate = await _fx.rateFor(currencyId, _clock());
      rateKnown = rate != null && rate > 0;
    }
    _state = sellCartStateWith(
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
    _state = sellCartStateWith(_state, fxGateRequired: false);
    notifyListeners();
  }

  Future<void> _refreshRateKnowledge() async {
    final currencyId = _state.currencyId;
    if (currencyId == null) return;
    final currency = sellCartCurrencyById(_state, currencyId);
    if (currency == null || currency.isBase) {
      _state = sellCartStateWith(
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
    _state = sellCartStateWith(
      _state,
      todayRate: rate,
      rateKnown: known,
      fxGateRequired: known ? false : _state.fxGateRequired,
    );
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────
  // بنود السلة
  // ───────────────────────────────────────────────────────────────────

  /// إضافة صنف (الكمية 1 أو دمج مع سطر موجود لنفس الصنف).
  void addItemFromInfo(ItemStockInfo info) {
    final existing = sellCartLineIndexOf(_state, info.item.id);
    if (existing >= 0) {
      _updateLine(existing, qty: _state.lines[existing].qty + 1);
      return;
    }
    _state = sellCartStateWith(
      _state,
      lines: [..._state.lines, cartLineFromStockInfo(info, _state.warehouseId)],
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
    _state = sellCartStateWith(_state, lines: lines);
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
    _state = sellCartStateWith(
      _state,
      invoiceDiscountType: type,
      invoiceDiscountValue: value,
    );
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────
  // الترحيل والدفع
  // ───────────────────────────────────────────────────────────────────

  /// بناء مسودة الترحيل من الحالة الحالية (للاستخدام الداخلي والاختبارات).
  SaleDraft? buildDraft({
    required double paidCash,
    required SalePaymentMethod method,
  }) => buildSaleDraftFromCart(
    _state,
    paidCash: paidCash,
    method: method,
    now: _clock(),
  );

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
      _state = sellCartStateWith(_state, postError: failure);
      notifyListeners();
      return Err<SalePostedReceipt, String>(failure);
    }
    final draft = buildDraft(paidCash: paidCash, method: method);
    if (draft == null) {
      const message = 'الإعدادات غير مكتملة (العملة/المخزن) — أعد فتح الشاشة.';
      _state = sellCartStateWith(_state, postError: message);
      notifyListeners();
      return const Err<SalePostedReceipt, String>(message);
    }

    _state = sellCartStateWith(_state, posting: true, postError: null);
    notifyListeners();
    final result = await _sales.postSale(
      draft,
      userId: _userId ?? 1,
      now: _clock(),
    );
    if (result.isOk) {
      final receipt = result.valueOrNull!;
      _state = sellCartStateWith(
        _state,
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
      _state = sellCartStateWith(
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
  String? _prePostFailure(double paidCash, SalePaymentMethod method) {
    final check = sellCartPrePostCheck(_state, paidCash, method);
    if (check.fxGateRequired) {
      _state = sellCartStateWith(_state, fxGateRequired: true);
      notifyListeners();
    }
    return check.failure;
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
      buildQuotationDraftFromCart(
        _state,
        validUntil: validUntil,
        clock: _clock,
        defaultValidity: quotationDefaultValidity,
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
    _state = sellCartStateWith(
      _state,
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
    _state = sellCartStateWith(_state, postError: null);
    notifyListeners();
  }

  void clearNotice() {
    if (_state.notice == null) return;
    _state = sellCartStateWith(_state, notice: null);
    notifyListeners();
  }

  void _notice(String message) {
    _state = sellCartStateWith(_state, notice: message);
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
    _state = sellCartStateWith(
      _state,
      lines: lines,
      postError: null,
      notice: null,
    );
    notifyListeners();
  }

  /// معاينة رقم INV القادم (آخر رقم مُصدر + 1) — عرض فقط، الترقيم الحقيقي
  /// يستهلك ذرّياً داخل معاملة الترحيل. (R18-D1: عبر مستودع المبيعات —
  /// طبقة العرض لا تلمس `core/storage/doc_sequence`.)
  Future<String?> _nextInvoicePreview() async {
    try {
      return await _sales.previewNextInvoiceNo(_clock().year);
    } catch (_) {
      return null;
    }
  }
}
