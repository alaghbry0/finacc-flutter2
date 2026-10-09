/// نموذج عرض شاشة «الطباعة والفواتير» (موجة UX-3) — تحميل صفوف
/// `print_template` لفواتير البيع في جولة واحدة، واختيار القالب النشط
/// وتحرير إعداداته (ألوان/مفاتيح إظهار/شارة) بكتابة فورية لكل تبديل
/// (إعداد لحظي بلا زر حفظ — نمط تفضيلات البيع).
///
/// تحمّل دفاعي: بلا صفوف (قاعدة ما قبل v4 يدوياً) تُعرض إعدادات البسيط
/// الافتراضية، وفشل الكتابة يبقي القيمة الحية ويُعرض خطأً.
library;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/print_template_repository.dart';
import '../../../../ui/features/printing/templates/invoice_template_settings.dart';

/// حالة الشاشة.
class PrintTemplatesState {
  const PrintTemplatesState({
    required this.loading,
    this.error,
    this.rows = const <PrintTemplateRow>[],
    this.activeCode = kPrintTemplateDefaultCode,
    this.settings = const InvoiceTemplateSettings(),
    this.writeError,
  });

  final bool loading;
  final Object? error;

  /// صفوف قوالب فواتير البيع (بترتيب البذر).
  final List<PrintTemplateRow> rows;

  /// كود القالب النشط.
  final String activeCode;

  /// إعدادات القالب النشط الجارية على الشاشة.
  final InvoiceTemplateSettings settings;

  /// فشل كتابة آخر تبديل (يُعرض — القيمة الحية تبقى كما كانت).
  final String? writeError;

  PrintTemplatesState copyWith({
    bool? loading,
    Object? error,
    List<PrintTemplateRow>? rows,
    String? activeCode,
    InvoiceTemplateSettings? settings,
    Object? writeError = _keep,
  }) => PrintTemplatesState(
    loading: loading ?? this.loading,
    error: error,
    rows: rows ?? this.rows,
    activeCode: activeCode ?? this.activeCode,
    settings: settings ?? this.settings,
    writeError: identical(writeError, _keep)
        ? this.writeError
        : writeError as String?,
  );

  static const Object _keep = Object();
}

/// نموذج عرض قوالب الطباعة.
class PrintTemplatesViewModel extends ChangeNotifier {
  PrintTemplatesViewModel({required PrintTemplateRepository printRepo})
    : _print = printRepo;

  final PrintTemplateRepository _print;

  /// نوع المستند — فواتير البيع في V1.
  static const String docType = 'sale';

  PrintTemplatesState _state = const PrintTemplatesState(loading: true);
  PrintTemplatesState get state => _state;

  /// تحميل الصفوف والإعدادات النشطة في جولة واحدة.
  Future<void> load() async {
    _state = _state.copyWith(loading: true, error: null);
    notifyListeners();
    try {
      final rows = await _print.allFor(docType);
      if (rows.isEmpty) {
        // قاعدة بلا بذر (حالة نادرة): البسيط الافتراضي حياً على الشاشة.
        _state = PrintTemplatesState(
          loading: false,
          activeCode: kPrintTemplateDefaultCode,
          settings: const InvoiceTemplateSettings(),
        );
      } else {
        final active = rows.where((r) => r.isDefault).firstOrNull;
        _state = PrintTemplatesState(
          loading: false,
          rows: rows,
          activeCode: active?.code ?? kPrintTemplateDefaultCode,
          settings: active?.config ?? const InvoiceTemplateSettings(),
        );
      }
    } catch (error) {
      _state = _state.copyWith(loading: false, error: error);
    }
    notifyListeners();
  }

  /// اختيار قالب: يعملّه (is_default) ويحمل إعداداته المبذورة/المحفوظة
  /// على الشاشة للتحرير — كتابة فورية.
  Future<void> selectTemplate(String code) async {
    final row = _state.rows.where((r) => r.code == code).firstOrNull;
    if (row == null) return;
    await _write(
      () => _print.save(code, row.config),
      activeCode: code,
      settings: row.config,
    );
  }

  /// تحديث إعدادات القالب النشط (لون/مفتاح/شارة) — كتابة فورية.
  Future<void> updateSettings(InvoiceTemplateSettings settings) => _write(
    () => _print.save(_state.activeCode, settings),
    settings: settings,
  );

  /// استعادة إعدادات البذر للقوالب الثلاثة + البسيط نشطاً.
  Future<void> resetToDefault() async {
    try {
      await _print.resetToDefault(docType: docType);
    } catch (error) {
      _state = _state.copyWith(writeError: 'WRITE_FAILED');
      if (kDebugMode) {
        debugPrint('PrintTemplatesViewModel.resetToDefault: $error');
      }
      notifyListeners();
      return;
    }
    await load();
  }

  /// يطبّق تبديلاً: تحديث حي فوري ثم كتابة — فشلها يُعرض دون كسر القيمة.
  Future<void> _write(
    Future<void> Function() write, {
    String? activeCode,
    InvoiceTemplateSettings? settings,
  }) async {
    _state = _state.copyWith(
      activeCode: activeCode,
      settings: settings,
      writeError: null,
    );
    notifyListeners();
    try {
      await write();
    } catch (error) {
      _state = _state.copyWith(writeError: 'WRITE_FAILED');
      if (kDebugMode) {
        debugPrint('PrintTemplatesViewModel._write: $error');
      }
      notifyListeners();
    }
  }
}
