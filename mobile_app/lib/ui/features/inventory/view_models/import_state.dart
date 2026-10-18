/// حالة استيراد الأصناف النقية (المراحل + الأخطاء + حقول الحالة) —
/// مستخرجة من import_view_model (R20-D3c: نقل حرفي بلا أي تغيير سلوكي؛
/// تُصدَّر من ملف المتحكم فبقيت استيرادات المستدعين كما هي).
library;

import '../../../../data/services/item_import_service.dart';
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

/// نسخ الحالة مع تجاوز الحقول المطلوبة فقط — الجسم منقول حرفياً من
/// `_copy` بمتحكم الاستيراد (علامات التصفير كما كانت).
ImportState importStateWith(
  ImportState state, {
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
  stage: stage ?? state.stage,
  fileMode: fileMode ?? state.fileMode,
  pasteText: pasteText ?? state.pasteText,
  currencies: currencies ?? state.currencies,
  warehouseId: warehouseId ?? state.warehouseId,
  userId: userId ?? state.userId,
  fileName: fileName ?? state.fileName,
  headers: headers ?? state.headers,
  mapping: mapping ?? state.mapping,
  analyzing: analyzing ?? state.analyzing,
  preview: clearPreview ? null : (preview ?? state.preview),
  acknowledged: acknowledged ?? state.acknowledged,
  committing: committing ?? state.committing,
  result: clearResult ? null : (result ?? state.result),
  error: clearError ? null : (error ?? state.error),
  repoError: clearRepoError ? null : (repoError ?? state.repoError),
);
