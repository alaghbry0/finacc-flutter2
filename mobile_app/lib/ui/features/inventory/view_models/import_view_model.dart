/// نموذج عرض استيراد الأصناف — FR-01-13 / AC-14: مسار مرحلي
/// (مصدر → ربط أعمدة مُخمَّن → معاينة بلا كتابة → إقرار عند وجود فشل
/// → إدخال الصفوف الصالحة فقط) عبر ItemImportService.
library;

import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/services/item_import_service.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/company.dart';

/// مراحل شاشة الاستيراد.
enum ImportStage { input, mapping, preview, done }

/// أخطاء قابلة للترجمة (تُعرض كلافت تحت الأزرار).
enum ImportError { noSource, nameNotMapped, fileRead }

/// حالة شاشة الاستيراد.
class ImportState {
  const ImportState({
    required this.stage,
    required this.fileMode,
    required this.pasteText,
    required this.currencies,
    this.warehouseId,
    this.userId,
    this.fileName,
    required this.headers,
    required this.mapping,
    this.analyzing = false,
    this.preview,
    this.acknowledged = false,
    this.committing = false,
    this.result,
    this.error,
    this.repoError,
  });

  final ImportStage stage;

  /// وضع الملف (true) أم اللصق (false).
  final bool fileMode;

  final String pasteText;

  /// العملات النشطة — لبناء صفوف أسعار الربط.
  final List<Currency> currencies;

  final int? warehouseId;
  final int? userId;

  /// اسم الملف المختار (وضع الملف).
  final String? fileName;

  /// رأس الجدول بعد قراءة المصدر.
  final List<String> headers;

  /// الربط الدلالي → حرف العمود ('' = تجاهل).
  final Map<String, String> mapping;

  final bool analyzing;
  final ItemImportPreview? preview;

  /// إقرار AC-14 عند وجود صفوف فاشلة.
  final bool acknowledged;

  final bool committing;
  final ItemImportCommitResult? result;

  final ImportError? error;
  final String? repoError;

  /// هل المصدر جاهز (نص ملصق أو ملف مقروء)؟
  bool get hasSource =>
      pasteText.trim().isNotEmpty || (fileName != null && headers.isNotEmpty);

  /// زر التنفيذ مفعَّل؟ (AC-14: معطَّل حتى الإقرار عند وجود فشل).
  bool get canCommit =>
      preview != null &&
      !committing &&
      preview!.validRows.isNotEmpty &&
      (preview!.isClean || acknowledged);

  static const ImportState initial = ImportState(
    stage: ImportStage.input,
    fileMode: false,
    pasteText: '',
    currencies: <Currency>[],
    headers: <String>[],
    mapping: <String, String>{},
  );
}

class ImportViewModel extends ChangeNotifier {
  ImportViewModel({
    required ItemImportService importService,
    required CompanyRepository companyRepo,
  }) : _import = importService,
       _companies = companyRepo;

  final ItemImportService _import;
  final CompanyRepository _companies;

  ImportState _state = ImportState.initial;
  ImportState get state => _state;

  /// المصدر الخام (نص CSV أو بايتات xlsx) — خارج الحالة (غير عرضي).
  Object? _source;

  /// الصفوف المقروءة (للرأس وعدد الأسطر).
  List<List<String>>? _rows;

  /// تحميل الثوابت: العملات النشطة + المخزن الافتراضي + المدير.
  Future<void> load() async {
    try {
      final results = await Future.wait<Object?>([
        _companies.listActiveCurrencies(),
        _companies.findDefaultWarehouseId(),
        _companies.findAdminUserId(),
      ]);
      _state = _copy(
        currencies: results[0] as List<Currency>,
        warehouseId: results[1] as int?,
        userId: results[2] as int?,
      );
    } catch (error) {
      _state = _copy(repoError: error.toString());
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────
  // مرحلة الإدخال
  // ─────────────────────────────────────────────────────────────────────

  /// تبديل الوضع (ملف / لصق).
  void setFileMode(bool fileMode) {
    if (fileMode == _state.fileMode) return;
    _state = _copy(fileMode: fileMode, error: null);
    notifyListeners();
  }

  /// نص CSV الملصق (حقل اللصق).
  void setPasteText(String text) {
    if (text == _state.pasteText) return;
    _state = _copy(pasteText: text, error: null);
    notifyListeners();
  }

  /// اختيار ملف CSV/Excel وقراءة رأسه — ثم الانتقال للربط مباشرة.
  Future<void> pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
    );
    if (files.isEmpty) return; // ألغى المستخدم.
    final file = files.single;
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      _state = _copy(error: ImportError.fileRead);
      notifyListeners();
      return;
    }
    try {
      if (file.name.toLowerCase().endsWith('.csv')) {
        _source = utf8.decode(bytes, allowMalformed: true);
        _rows = _parseCsvRows(_source as String);
      } else {
        _source = bytes;
        _rows = _readXlsxRows(bytes);
      }
    } catch (_) {
      _state = _copy(error: ImportError.fileRead);
      notifyListeners();
      return;
    }
    _fileName = file.name;
    _openMapping();
  }

  /// من نص اللصق إلى شاشة الربط (تحليل الرأس + تخمين الربط).
  void prepareMapping() {
    final text = _state.pasteText.trim();
    if (text.isEmpty) {
      _state = _copy(error: ImportError.noSource);
      notifyListeners();
      return;
    }
    _source = text;
    _fileName = null;
    _rows = _parseCsvRows(text);
    _openMapping();
  }

  // ─────────────────────────────────────────────────────────────────────
  // مرحلة الربط
  // ─────────────────────────────────────────────────────────────────────

  /// تثبيت ربط حقل دلالي بحرف عمود ('' = تجاهل).
  void setMappingField(String semantic, String letter) {
    _state = _copy(mapping: {..._state.mapping, semantic: letter}, error: null);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────
  // مرحلة المعاينة
  // ─────────────────────────────────────────────────────────────────────

  /// «تحليل الملف» — تحقق كامل بلا أي كتابة في القاعدة.
  Future<void> analyze() async {
    if (_source == null) {
      _state = _copy(error: ImportError.noSource);
      notifyListeners();
      return;
    }
    final nameColumn = _state.mapping['name'] ?? '';
    if (nameColumn.isEmpty) {
      _state = _copy(error: ImportError.nameNotMapped);
      notifyListeners();
      return;
    }
    final warehouseId = _state.warehouseId;
    if (warehouseId == null) {
      _state = _copy(repoError: 'لا يوجد مخزن افتراضي في القاعدة');
      notifyListeners();
      return;
    }
    _state = _copy(
      analyzing: true,
      error: null,
      repoError: null,
      acknowledged: false,
    );
    notifyListeners();
    try {
      final mapping = {
        for (final entry in _state.mapping.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
      };
      final preview = await _import.parseAndValidate(
        _source!,
        warehouseId: warehouseId,
        columnMapping: mapping,
        activeCurrencies: _state.currencies,
      );
      _state = _copy(
        stage: ImportStage.preview,
        analyzing: false,
        preview: preview,
      );
    } catch (error) {
      _state = _copy(analyzing: false, repoError: error.toString());
    }
    notifyListeners();
  }

  /// إقرار AC-14 (خانة الاختيار).
  void setAcknowledged(bool value) {
    if (value == _state.acknowledged) return;
    _state = _copy(acknowledged: value);
    notifyListeners();
  }

  /// «إدخال الصفوف الصليمة» — التنفيذ الفعلي (الصحيح فقط).
  Future<bool> commit() async {
    final preview = _state.preview;
    if (preview == null || _state.committing) return false;
    final warehouseId = _state.warehouseId;
    final userId = _state.userId;
    if (warehouseId == null || userId == null) {
      _state = _copy(repoError: 'تعذر تحديد المخزن أو المستخدم — أعد المحاولة');
      notifyListeners();
      return false;
    }
    _state = _copy(committing: true, repoError: null);
    notifyListeners();
    final result = await _import.commitValid(
      preview,
      warehouseId: warehouseId,
      userId: userId,
      confirmed: preview.isClean || _state.acknowledged,
    );
    switch (result) {
      case final Ok<ItemImportCommitResult, String> ok:
        _state = _copy(
          stage: ImportStage.done,
          committing: false,
          result: ok.value,
        );
        notifyListeners();
        return true;
      case final Err<ItemImportCommitResult, String> err:
        _state = _copy(committing: false, repoError: err.error);
        notifyListeners();
        return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // التنقل بين المراحل
  // ─────────────────────────────────────────────────────────────────────

  /// العودة من المعاينة إلى الربط (تغيير الأعمدة).
  void backToMapping() {
    _state = ImportState(
      stage: ImportStage.mapping,
      fileMode: _state.fileMode,
      pasteText: _state.pasteText,
      currencies: _state.currencies,
      warehouseId: _state.warehouseId,
      userId: _state.userId,
      fileName: _state.fileName,
      headers: _state.headers,
      mapping: _state.mapping,
    );
    notifyListeners();
  }

  /// بدء استيراد جديد من الصفر.
  void reset() {
    _source = null;
    _rows = null;
    _fileName = null;
    _state = ImportState(
      stage: ImportStage.input,
      fileMode: _state.fileMode,
      pasteText: '',
      currencies: _state.currencies,
      warehouseId: _state.warehouseId,
      userId: _state.userId,
      headers: const <String>[],
      mapping: const <String, String>{},
    );
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────
  // قراءة المصدر وتخمين الربط
  // ─────────────────────────────────────────────────────────────────────

  String? _fileName;

  /// ينتقل لمرحلة الربط برأس مقروء وربط مُخمَّن.
  void _openMapping() {
    final rows = _rows ?? const <List<String>>[];
    if (rows.isEmpty || rows.first.every((cell) => cell.trim().isEmpty)) {
      _state = _copy(error: ImportError.noSource);
      notifyListeners();
      return;
    }
    _state = _copy(
      stage: ImportStage.mapping,
      fileName: _fileName,
      headers: rows.first,
      mapping: _guessMapping(rows.first, _state.currencies),
      clearError: true,
      clearRepoError: true,
      clearPreview: true,
      clearResult: true,
    );
    notifyListeners();
  }

  /// يخمّن الربط من رأس الجدول (عربي/إنجليزي — تام ثم جزئي للأسعار).
  static Map<String, String> _guessMapping(
    List<String> headers,
    List<Currency> currencies,
  ) {
    final normalized = [
      for (final header in headers) header.trim().toLowerCase(),
    ];
    final taken = <int>{};
    final mapping = <String, String>{};

    String? claimExact(Set<String> candidates) {
      for (var i = 0; i < normalized.length; i++) {
        if (taken.contains(i)) continue;
        if (candidates.contains(normalized[i])) {
          taken.add(i);
          return _columnLetter(i);
        }
      }
      return null;
    }

    final name = claimExact(const {
      'name',
      'الاسم',
      'اسم',
      'اسم الصنف',
      'اسم المنتج',
      'الصنف',
      'المنتج',
      'item',
      'product',
      'item name',
      'product name',
    });
    if (name != null) mapping['name'] = name;
    final barcode = claimExact(const {
      'barcode',
      'bar code',
      'bar-code',
      'الباركود',
      'باركود',
      'الرمز',
      'الشفرة',
      'code',
      'ean',
      'sku',
    });
    if (barcode != null) mapping['barcode'] = barcode;
    final cost = claimExact(const {
      'cost',
      'costprice',
      'cost price',
      'cost_price',
      'التكلفة',
      'تكلفة',
      'سعر التكلفة',
      'سعر الشراء',
    });
    if (cost != null) mapping['cost'] = cost;
    final qty = claimExact(const {
      'qty',
      'quantity',
      'openingqty',
      'opening qty',
      'opening_qty',
      'الكمية',
      'كمية',
      'الكمية الافتتاحية',
      'المتوفر',
      'الرصيد',
      'المخزون',
    });
    if (qty != null) mapping['qty'] = qty;
    final minStock = claimExact(const {
      'minstock',
      'min stock',
      'min_stock',
      'min',
      'الحد',
      'الحد الأدنى',
      'حد الطلب',
      'حد إعادة الطلب',
      'حد الطلب الأدنى',
    });
    if (minStock != null) mapping['min_stock'] = minStock;
    final category = claimExact(const {
      'category',
      'cat',
      'الفئة',
      'فئة',
      'التصنيف',
      'تصنيف',
    });
    if (category != null) mapping['category'] = category;
    final unit = claimExact(const {
      'unit',
      'units',
      'الوحدة',
      'وحدة',
      'وحدة القياس',
      'وحدة الصنف',
    });
    if (unit != null) mapping['unit'] = unit;
    final notes = claimExact(const {
      'notes',
      'note',
      'ملاحظات',
      'الملاحظات',
      'وصف',
      'الوصف',
      'description',
    });
    if (notes != null) mapping['notes'] = notes;

    // الأسعار: عام (سعر/price) للأساسية أولاً، ثم الخاص بكل عملة
    // (price_yer / سعر yer / اسم العملة أو ميزتها الجزئي).
    final base = currencies.isEmpty ? null : currencies.first;
    if (base != null) {
      final generic = claimExact(const {
        'price',
        'سعر',
        'سعر البيع',
        'السعر',
        'سعر بيع',
        'سعر البيع ',
        'sale price',
        'saleprice',
        'retail',
        'retail price',
      });
      if (generic != null) mapping['price_${base.code}'] = generic;
    }
    for (final currency in currencies) {
      final code = currency.code.toLowerCase();
      final token = currency.name.trim().split(' ').last; // يمني/سعودي/…
      var letter = claimExact({
        'price_$code',
        'سعر $code',
        'سعر_$code',
        'سعر ${currency.name}',
        currency.name,
        code,
      });
      if (letter == null) {
        // تمريرة جزئية: عمود يحمل اسم العملة أو رمزها ولم يُحجز بعد.
        for (var i = 0; i < normalized.length; i++) {
          if (taken.contains(i)) continue;
          final header = normalized[i];
          final isPriceish = header.contains('price') || header.contains('سعر');
          final matchesCurrency =
              header.contains(code) ||
              header.contains(currency.name) ||
              (token.length > 2 && header.contains(token));
          if (isPriceish && matchesCurrency) {
            taken.add(i);
            letter = _columnLetter(i);
            break;
          }
        }
      }
      if (letter != null) mapping['price_${currency.code}'] = letter;
    }
    return mapping;
  }

  /// حرف العمود (A = 0، AA = 26…) — صيغة خدمة الاستيراد.
  static String _columnLetter(int index) {
    var letter = '';
    var i = index;
    while (i >= 0) {
      letter = String.fromCharCode(0x41 + (i % 26)) + letter;
      i = (i ~/ 26) - 1;
    }
    return letter;
  }

  /// محلّل CSV بعربون قوي (BOM / CRLF / اقتباسات / فواصل داخلية) —
  /// نفس خوارزمية خدمة الاستيراد (خاصة هناك — نسخة عرضية هنا للرأس).
  static List<List<String>> _parseCsvRows(String text) {
    final clean = text.startsWith('\uFEFF') ? text.substring(1) : text;
    final rows = <List<String>>[];
    var field = StringBuffer();
    var row = <String>[];
    var inQuotes = false;

    void endField() {
      row.add(field.toString());
      field = StringBuffer();
    }

    void endRow() {
      endField();
      rows.add(row);
      row = <String>[];
    }

    for (var i = 0; i < clean.length; i++) {
      final ch = clean[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < clean.length && clean[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        endField();
      } else if (ch == '\r') {
        continue;
      } else if (ch == '\n') {
        endRow();
      } else {
        field.write(ch);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  /// يقرأ صفوف الورقة الأولى من xlsx (للرأس وعدد الأسطر).
  static List<List<String>> _readXlsxRows(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final name =
        excel.getDefaultSheet() ??
        (excel.tables.keys.isEmpty ? null : excel.tables.keys.first);
    if (name == null) return const [];
    final sheet = excel.tables[name];
    if (sheet == null) return const [];
    return [
      for (final row in sheet.rows) [for (final cell in row) _cellText(cell)],
    ];
  }

  /// نص خلية Excel (نص/رقم — الفارغ '').
  static String _cellText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    return switch (value) {
      final TextCellValue text => text.toString(),
      final IntCellValue number => number.value.toString(),
      final DoubleCellValue number => number.value.toString(),
      final other => other.toString(),
    };
  }

  ImportState _copy({
    ImportStage? stage,
    bool? fileMode,
    String? pasteText,
    List<Currency>? currencies,
    int? warehouseId,
    int? userId,
    String? fileName,
    List<String>? headers,
    Map<String, String>? mapping,
    bool? analyzing,
    ItemImportPreview? preview,
    bool clearPreview = false,
    bool? acknowledged,
    bool? committing,
    ItemImportCommitResult? result,
    bool clearResult = false,
    ImportError? error,
    bool clearError = false,
    String? repoError,
    bool clearRepoError = false,
  }) => ImportState(
    stage: stage ?? _state.stage,
    fileMode: fileMode ?? _state.fileMode,
    pasteText: pasteText ?? _state.pasteText,
    currencies: currencies ?? _state.currencies,
    warehouseId: warehouseId ?? _state.warehouseId,
    userId: userId ?? _state.userId,
    fileName: fileName ?? _state.fileName,
    headers: headers ?? _state.headers,
    mapping: mapping ?? _state.mapping,
    analyzing: analyzing ?? _state.analyzing,
    preview: clearPreview ? null : (preview ?? _state.preview),
    acknowledged: acknowledged ?? _state.acknowledged,
    committing: committing ?? _state.committing,
    result: clearResult ? null : (result ?? _state.result),
    error: clearError ? null : (error ?? _state.error),
    repoError: clearRepoError ? null : (repoError ?? _state.repoError),
  );
}
