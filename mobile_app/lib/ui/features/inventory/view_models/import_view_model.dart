/// نموذج عرض استيراد الأصناف — FR-01-13 / AC-14: مسار مرحلي
/// (مصدر → ربط أعمدة مُخمَّن → معاينة بلا كتابة → إقرار عند وجود فشل
/// → إدخال الصفوف الصالحة فقط) عبر ItemImportService.
///
/// (R20-D3c: الأنواع النقية في `import_state.dart` والحسابات النقية في
/// `import_helpers.dart` — تُصدَّر الأولى من هنا فبقيت استيرادات
/// المستدعين كما هي؛ هذا الملف: سطح التنسيق — الإخطار والمستودعات.)
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../../data/repositories/company_repository.dart';
import '../../../../data/services/item_import_service.dart';
import '../../../../domain/core/result.dart';
import '../../../../domain/models/company.dart';
import 'import_helpers.dart';
import 'import_state.dart';

export 'import_state.dart';

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
      _state = importStateWith(
        _state,
        currencies: results[0] as List<Currency>,
        warehouseId: results[1] as int?,
        userId: results[2] as int?,
      );
    } catch (error) {
      _state = importStateWith(_state, repoError: error.toString());
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────
  // مرحلة الإدخال
  // ─────────────────────────────────────────────────────────────────────

  /// تبديل الوضع (ملف / لصق).
  void setFileMode(bool fileMode) {
    if (fileMode == _state.fileMode) return;
    _state = importStateWith(_state, fileMode: fileMode);
    notifyListeners();
  }

  /// نص CSV الملصق (حقل اللصق).
  void setPasteText(String text) {
    if (text == _state.pasteText) return;
    _state = importStateWith(_state, pasteText: text);
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
      _state = importStateWith(_state, error: ImportError.fileRead);
      notifyListeners();
      return;
    }
    try {
      if (file.name.toLowerCase().endsWith('.csv')) {
        _source = utf8.decode(bytes, allowMalformed: true);
        _rows = importParseCsvRows(_source as String);
      } else {
        _source = bytes;
        _rows = importReadXlsxRows(bytes);
      }
    } catch (_) {
      _state = importStateWith(_state, error: ImportError.fileRead);
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
      _state = importStateWith(_state, error: ImportError.noSource);
      notifyListeners();
      return;
    }
    _source = text;
    _fileName = null;
    _rows = importParseCsvRows(text);
    _openMapping();
  }

  // ─────────────────────────────────────────────────────────────────────
  // مرحلة الربط
  // ─────────────────────────────────────────────────────────────────────

  /// تثبيت ربط حقل دلالي بحرف عمود ('' = تجاهل).
  void setMappingField(String semantic, String letter) {
    _state = importStateWith(
      _state,
      mapping: {..._state.mapping, semantic: letter},
    );
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────
  // مرحلة المعاينة
  // ─────────────────────────────────────────────────────────────────────

  /// «تحليل الملف» — تحقق كامل بلا أي كتابة في القاعدة.
  Future<void> analyze() async {
    if (_source == null) {
      _state = importStateWith(_state, error: ImportError.noSource);
      notifyListeners();
      return;
    }
    final nameColumn = _state.mapping['name'] ?? '';
    if (nameColumn.isEmpty) {
      _state = importStateWith(_state, error: ImportError.nameNotMapped);
      notifyListeners();
      return;
    }
    final warehouseId = _state.warehouseId;
    if (warehouseId == null) {
      _state = importStateWith(
        _state,
        repoError: 'لا يوجد مخزن افتراضي في القاعدة',
      );
      notifyListeners();
      return;
    }
    _state = importStateWith(_state, analyzing: true, acknowledged: false);
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
      _state = importStateWith(
        _state,
        stage: ImportStage.preview,
        analyzing: false,
        preview: preview,
      );
    } catch (error) {
      _state = importStateWith(
        _state,
        analyzing: false,
        repoError: error.toString(),
      );
    }
    notifyListeners();
  }

  /// إقرار AC-14 (خانة الاختيار).
  void setAcknowledged(bool value) {
    if (value == _state.acknowledged) return;
    _state = importStateWith(_state, acknowledged: value);
    notifyListeners();
  }

  /// «إدخال الصفوف الصليمة» — التنفيذ الفعلي (الصحيح فقط).
  Future<bool> commit() async {
    final preview = _state.preview;
    if (preview == null || _state.committing) return false;
    final warehouseId = _state.warehouseId;
    final userId = _state.userId;
    if (warehouseId == null || userId == null) {
      _state = importStateWith(
        _state,
        repoError: 'تعذر تحديد المخزن أو المستخدم — أعد المحاولة',
      );
      notifyListeners();
      return false;
    }
    _state = importStateWith(_state, committing: true);
    notifyListeners();
    final result = await _import.commitValid(
      preview,
      warehouseId: warehouseId,
      userId: userId,
      confirmed: preview.isClean || _state.acknowledged,
    );
    switch (result) {
      case final Ok<ItemImportCommitResult, String> ok:
        _state = importStateWith(
          _state,
          stage: ImportStage.done,
          committing: false,
          result: ok.value,
        );
        notifyListeners();
        return true;
      case final Err<ItemImportCommitResult, String> err:
        _state = importStateWith(
          _state,
          committing: false,
          repoError: err.error,
        );
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
      _state = importStateWith(_state, error: ImportError.noSource);
      notifyListeners();
      return;
    }
    _state = importStateWith(
      _state,
      stage: ImportStage.mapping,
      fileName: _fileName,
      headers: rows.first,
      mapping: importGuessMapping(rows.first, _state.currencies),
      clearError: true,
      clearRepoError: true,
      clearPreview: true,
      clearResult: true,
    );
    notifyListeners();
  }
}
