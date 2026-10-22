/// شريط تصدير التقارير الثلاثي بهوية SIM (V7-C — شاشات التقارير):
/// [SimBottomActionBar] الثابت أسفل شاشة التقرير بأزراره الثلاثة
/// المقفلة (صورة / PDF / تفوق — مفاتيح `reportSimAction*`) كلها موصولة
/// بعدة تصدير V7-B:
///
/// - **صورة** → [exportReportImage] (ترسيم PDF العام بدقة 150 وتركيب
///   عمودي وتنزيل PNG): سقف الصفحات → SnackBar `reportSimExportImageCap`
///   والنجاح → `reportSimExportImageDone`.
/// - **PDF** → [showPdfPreviewDialog] بعنوان التقرير وبناء المستند عبر
///   [ReportPdfBuilder] العام من المسقط الجاهز — **إلا إذا مرر المستدعي
///   [onOpenPdf] مخصصًا** (شاشة الأرباح: زرها يستهلك بانيها الغني
///   القائم كما هو — قرار نقد V7: لا يُستبدل بالعام).
/// - **تفوق** → [exportReportExcel] (xlsx حقيقي برؤوس أعمدة المسقط
///   وصفوفه) وSnackBar نجاحه من الخدمة نفسها (`reportSimExportExcelDone`).
///
/// الأزرار الثلاثة معطلة حين لا مسقط ([doc] = null: تحميل/خطأ/فراغ) —
/// لا تصدير لتقرير غير موجود.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/sim_list_widgets.dart';
import '../../../printing/docs/report_print_doc.dart';
import '../../../printing/services/report_pdf_builder.dart';
import '../../../printing/views/pdf_preview_dialog.dart';
import '../../services/report_excel_export.dart';
import '../../services/report_image_export.dart';

/// الشريط الثلاثي الثابت أسفل شاشة تقرير واحدة.
///
/// [title] اسم التقرير: عنوان حوار المعاينة وأساس أسماء ملفات الصورة
/// والتفوق واسم ورقة Excel. [doc] المسقط الجدولي الجاهز من حالة النموذج
/// **الحية لحظة البناء** (null = لا بيانات → أزرار معطلة). [onOpenPdf]
/// مسار معاينة مخصص (اختياري — الأرباح).
class SimReportExportBar extends StatelessWidget {
  const SimReportExportBar({
    super.key,
    required this.title,
    required this.doc,
    this.onOpenPdf,
  });

  /// اسم التقرير (عنوان المعاينة + أساس الملفات + اسم ورقة Excel).
  final String title;

  /// المسقط الجدولي الجاهز — null يعطّل الأزرار الثلاثة.
  final ReportPrintDoc? doc;

  /// بديل مخصص لفتح معاينة PDF (الأرباح: بانيها الغني القائم).
  final VoidCallback? onOpenPdf;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = doc != null;
    return SimBottomActionBar(
      items: [
        SimBottomActionItem(
          icon: Icons.image_outlined,
          label: l10n.reportSimActionImage,
          enabled: enabled,
          onTap: enabled ? () => unawaited(_exportImage(context)) : null,
        ),
        SimBottomActionItem(
          icon: Icons.picture_as_pdf_outlined,
          label: l10n.reportSimActionPdf,
          enabled: enabled,
          onTap: enabled ? () => _openPdf(context) : null,
        ),
        SimBottomActionItem(
          icon: Icons.grid_on_outlined,
          label: l10n.reportSimActionExcel,
          enabled: enabled,
          onTap: enabled ? () => unawaited(_exportExcel(context)) : null,
        ),
      ],
    );
  }

  /// صورة PNG واحدة — كل قيم السياق تُلتقط قبل أول await (لا سياق عبر
  /// فجوة غير متزامنة — نمط نافذة المعاينة).
  Future<void> _exportImage(BuildContext context) async {
    final doc = this.doc;
    if (doc == null) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await exportReportImage(
        buildPdf: () => const ReportPdfBuilder().build(doc),
        fileName: title,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result == ImageExportResult.tooLong
                  ? l10n.reportSimExportImageCap
                  : l10n.reportSimExportImageDone,
            ),
          ),
        );
    } catch (_) {
      // تنزيل المنصة غير متاح (غير الويب حالياً) — رسالة عامة صادقة.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.genericErrorTitle)));
    }
  }

  /// معاينة PDF — العامة من المسقط، أو المسار المخصص إن وُجد (الأرباح).
  void _openPdf(BuildContext context) {
    final doc = this.doc;
    if (doc == null) return;
    final custom = onOpenPdf;
    if (custom != null) {
      custom();
      return;
    }
    unawaited(
      showPdfPreviewDialog(
        context,
        title: title,
        build: () => const ReportPdfBuilder().build(doc),
      ),
    );
  }

  /// ملف Excel حقيقي — رؤوس أعمدة المسقط وصفوفه **مع صف الإجمالي إن
  /// وجد** (مراجعة V7 🟡-2: كان يسقط بينما PDF/الصورة يرسمانه — للمحاسب
  /// الإجمالي أهم صف)، وSnackBar النجاح من الخدمة نفسها؛ الاستثناءات
  /// (تنزيل غير الويب) برسالة عامة.
  Future<void> _exportExcel(BuildContext context) async {
    final doc = this.doc;
    if (doc == null) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await exportReportExcel(
        context: context,
        fileName: title,
        sheetTitle: title,
        headers: [for (final column in doc.columns) column.label],
        rows: [...doc.rows, if (doc.totalRow != null) doc.totalRow!],
      );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.genericErrorTitle)));
    }
  }
}
