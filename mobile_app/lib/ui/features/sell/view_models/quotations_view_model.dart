/// نموذج قائمة عروض الأسعار — تصفية بالحالة + تعليم مرسل + إلغاء،
/// ونموذج التفاصيل مع التحويل إلى فاتورة (يدفع عبر convertToInvoice
/// الذرّي — البضاعة تُخصم مرة واحدة وقت التحويل حصراً).
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/quotation_repository.dart';
import '../../../../data/repositories/sale_repository.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/company.dart';
import '../../../../domain/models/quotation.dart';
import '../../../../domain/models/sale.dart';

class QuotationsListState {
  const QuotationsListState({
    required this.loading,
    required this.quotations,
    this.statusFilter,
    this.error,
    this.busyQuotationId,
  });

  final bool loading;
  final List<QuotationSummary> quotations;

  /// تصفية الحالة (null = الكل).
  final QuotationStatus? statusFilter;
  final Object? error;

  /// عرض قيد المعالجة الآن (قفل أزراره).
  final int? busyQuotationId;

  static const QuotationsListState initial = QuotationsListState(
    loading: true,
    quotations: <QuotationSummary>[],
  );
}

class QuotationsViewModel extends ChangeNotifier {
  QuotationsViewModel({required QuotationRepository quotationRepo})
    : _quotations = quotationRepo;

  final QuotationRepository _quotations;

  QuotationsListState _state = QuotationsListState.initial;
  QuotationsListState get state => _state;

  Future<void> load() async {
    _state = QuotationsListState(
      loading: true,
      quotations: const <QuotationSummary>[],
      statusFilter: _state.statusFilter,
    );
    notifyListeners();
    try {
      final quotations = await _quotations.listQuotations(
        status: _state.statusFilter,
        limit: 100,
      );
      _state = QuotationsListState(
        loading: false,
        quotations: quotations,
        statusFilter: _state.statusFilter,
      );
    } catch (error) {
      _state = QuotationsListState(
        loading: false,
        quotations: const <QuotationSummary>[],
        statusFilter: _state.statusFilter,
        error: error,
      );
    }
    notifyListeners();
  }

  Future<void> setStatusFilter(QuotationStatus? status) async {
    if (status == _state.statusFilter) return;
    _state = QuotationsListState(
      loading: _state.loading,
      quotations: _state.quotations,
      statusFilter: status,
    );
    notifyListeners();
    await load();
  }

  /// تعليم «مُرسَل» — الرسالة العربية تُعاد للعرض عند الرفض.
  Future<Result<Quotation, String>> markSent(int id, {required int userId}) =>
      _runAction(id, () => _quotations.markSent(id, userId: userId));

  /// إلغاء العرض (draft/sent فقط).
  Future<Result<Quotation, String>> cancel(int id, {required int userId}) =>
      _runAction(id, () => _quotations.cancelQuotation(id, userId: userId));

  Future<Result<Quotation, String>> _runAction(
    int id,
    Future<Result<Quotation, String>> Function() action,
  ) async {
    _state = _copyWith(busyQuotationId: id);
    notifyListeners();
    final result = await action();
    _state = _copyWith(busyQuotationId: null);
    notifyListeners();
    if (result.isOk) {
      await load();
    }
    return result;
  }

  QuotationsListState _copyWith({int? busyQuotationId}) => QuotationsListState(
    loading: _state.loading,
    quotations: _state.quotations,
    statusFilter: _state.statusFilter,
    error: _state.error,
    busyQuotationId: busyQuotationId ?? _state.busyQuotationId,
  );
}

/// حالة شاشة تفاصيل عرض السعر.
class QuotationDetailState {
  const QuotationDetailState({
    required this.loading,
    this.detail,
    this.error,
    this.converting = false,
    this.convertedInvoiceNo,
  });

  final bool loading;
  final QuotationDetail? detail;
  final Object? error;

  /// تحويل إلى فاتورة جارٍ الآن.
  final bool converting;

  /// رقم الفاتورة الحقيقي `INV-YYYY-NNNNN` للعرض المحوَّل (P2-5) —
  /// null قبل التحويل أو عند تعذّر جلبه (الشريحة تعود للمعرّف الداخلي).
  final String? convertedInvoiceNo;

  static const QuotationDetailState initial = QuotationDetailState(
    loading: true,
    converting: false,
  );
}

class QuotationDetailViewModel extends ChangeNotifier {
  QuotationDetailViewModel({
    required QuotationRepository quotationRepo,
    required CompanyRepository companyRepo,
    required this.quotationId,
    SaleRepository? saleRepo,
    int initialUserId = 1,
  }) : _quotations = quotationRepo,
       _companies = companyRepo,
       _sales = saleRepo,
       _userId = initialUserId;

  final QuotationRepository _quotations;
  final CompanyRepository _companies;

  /// لجلب رقم الفاتورة المحوَّل إليها (P2-5) — null = الشريحة بالمعرّف
  /// الداخلي كما كان (سلوك متسق عند غياب المستودع).
  final SaleRepository? _sales;
  final int quotationId;

  int _userId;

  /// معرّف المنفّذ (يُضبط من الشاشة فور توافر معرّف المشرف).
  int get userId => _userId;
  void setUserId(int id) => _userId = id;

  QuotationDetailState _state = QuotationDetailState.initial;
  QuotationDetailState get state => _state;

  Quotation? get quotation => _state.detail?.quotation;

  /// عملة العرض (لسعر التحويل وأماكن العرض) — تعمم بعد التحميل.
  Currency? get currency {
    final id = quotation?.currencyId;
    if (id == null || _currencies == null) return null;
    for (final currency in _currencies!) {
      if (currency.id == id) return currency;
    }
    return null;
  }

  List<Currency>? _currencies;

  Future<void> load() async {
    _state = QuotationDetailState.initial;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _quotations.quotationDetail(quotationId),
        _companies.listActiveCurrencies(),
      ]);
      _currencies = results[1] as List<Currency>?;
      final detail = results[0] as QuotationDetail?;
      _state = QuotationDetailState(
        loading: false,
        detail: detail,
        convertedInvoiceNo: await _convertedInvoiceNo(detail),
      );
    } catch (error) {
      _state = QuotationDetailState(loading: false, error: error);
    }
    notifyListeners();
  }

  /// يجلب رقم INV الحقيقي للفاتورة المرتبطة بالعرض المحوَّل (P2-5) —
  /// null عند عدم التحويل أو تعذّر الجلب (لا يفشل التحميل أبداً).
  Future<String?> _convertedInvoiceNo(QuotationDetail? detail) async {
    final invoiceId = detail?.quotation.convertedInvoiceId;
    final sales = _sales;
    if (invoiceId == null || sales == null) return null;
    try {
      return (await sales.invoiceDetail(invoiceId))?.invoice.invoiceNo;
    } catch (_) {
      return null;
    }
  }

  /// **تحويل العرض إلى فاتورة** (PaymentSheet يمرر المبلغ والطريقة) —
  /// الذرّية داخل convertToInvoice: العرض يتحول والفاتورة تُرحَّل أو
  /// يرجع الاثنان معاً.
  Future<Result<SalePostedReceipt, String>> convertToInvoice({
    required double paidCash,
    SalePaymentMethod? paymentMethod,
  }) async {
    if (_state.converting) {
      return const Err<SalePostedReceipt, String>(
        'تحويل جارٍ بالفعل — لحظات ويكتمل.',
      );
    }
    _state = _copyWith(converting: true);
    notifyListeners();
    final result = await _quotations.convertToInvoice(
      quotationId,
      paidCash: paidCash,
      paymentMethod: paymentMethod,
      userId: userId,
    );
    _state = _copyWith(converting: false);
    notifyListeners();
    if (result.isOk) {
      await load(); // الحالة الآن converted + الفاتورة المرتبطة.
    }
    return result;
  }

  Future<Result<Quotation, String>> markSent() =>
      _quotations.markSent(quotationId, userId: userId);

  Future<Result<Quotation, String>> cancel() =>
      _quotations.cancelQuotation(quotationId, userId: userId);

  QuotationDetailState _copyWith({bool? converting}) => QuotationDetailState(
    loading: _state.loading,
    detail: _state.detail,
    error: _state.error,
    converting: converting ?? _state.converting,
    convertedInvoiceNo: _state.convertedInvoiceNo,
  );
}
