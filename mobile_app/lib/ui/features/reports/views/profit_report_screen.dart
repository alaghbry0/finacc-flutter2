/// شاشة «الأرباح والخسائر» (FR-09-02 — الشريحة 10) بهوية Simple Invoice
/// Manager (V7-C): ترويسة فرعية برجوع منطقي إلى مركز التقارير، شريط
/// الفترات المسبقة/المخصصة القائم، بطاقات البنود والربح والمسحوبات
/// والإغلاق كما هي، و**شريط التصدير الثلاثي الثابت أسفل الشاشة**
/// (صورة/PDF/تفوق): زر PDF يستهلك **بانيها الغني القائم** كما هو
/// (قرار نقد V7: لا يُستبدل بالعام)، وزرا الصورة والتفوق بمسقط جدولي
/// عام من بيانات نموذجها (`buildProfitTableDoc`).
///
/// اصطلاح العرض: إشارة كل سطر = **إسهامه في الربح** (+ يزيد/− يقلّ) —
/// الدهشة المحاسبية الوحيدة: تكلفة المرتجع تظهر موجبة لأنها تُخصم من
/// COGS داخل الصيغة الملزمة.
///
/// بطاقات التقرير وسطوره ومساعداته بملفاتها المركزّزة بجوارها
/// (R20-D3d) — هذا الملف: إنشاء النموذج والحرّاس ومعاينة PDF الغنية.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/profit_report_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/sim_list_widgets.dart';
import '../../printing/services/profit_report_pdf_builder.dart';
import '../../printing/views/pdf_preview_dialog.dart';
import '../view_models/profit_report_view_model.dart';
import 'widgets/period_preset_bar.dart';
import 'widgets/profit_report_drawings_card.dart';
import 'widgets/profit_report_format.dart';
import 'widgets/profit_report_lines_card.dart';
import 'widgets/profit_report_meta_footer.dart';
import 'widgets/profit_report_owner_card.dart';
import 'widgets/profit_report_total_card.dart';
import 'widgets/report_print_projection.dart';
import 'widgets/sim_report_export_bar.dart';

/// شاشة تقرير الأرباح والخسائر — مسار مقترح `/reports/profit`.
class ProfitReportScreen extends StatelessWidget {
  const ProfitReportScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها
  /// من قاعدة AppController مباشرة (نمط شاشة الأعمار).
  final ProfitReportViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final ProfitReportViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = ProfitReportViewModel(
        profitRepo: ProfitReportRepository(app.database!.db),
        companyRepo: app.companies,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<ProfitReportViewModel>.value(
      value: vm,
      child: const _ProfitBody(),
    );
  }
}

class _ProfitBody extends StatelessWidget {
  const _ProfitBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfitReportViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SimSubHeader(
              titleKey: const Key('profit_report_title'),
              title: l10n.profitTitle,
              onBack: () => _backToReports(context),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: vm.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    PeriodPresetBar(
                      selected: state.period,
                      currentFrom: state.from,
                      currentTo: state.to,
                      onPeriodSelected: (period) =>
                          unawaited(vm.setPeriod(period)),
                      onCustomRange: (from, to) =>
                          unawaited(vm.setCustomRange(from, to)),
                    ),
                    const SizedBox(height: 14),
                    ..._buildContent(context, vm),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // الثلاثية الثابتة: PDF = الباني الغني القائم، صورة/تفوق بمسقط
      // جدولي عام من حالة النموذج الحية (تعطيل حتى يكتمل التقرير).
      bottomNavigationBar: SimReportExportBar(
        title: l10n.profitPdfTitle,
        doc: state.report == null
            ? null
            : buildProfitTableDoc(
                l10n: l10n,
                company: context.read<AppController>().company,
                report: state.report!,
                decimals: state.decimals,
              ),
        onOpenPdf: state.report == null
            ? null
            : () => _openProfitPdf(context, vm),
      ),
    );
  }

  /// رجوع منطقي: pop إن كان متاحاً وإلا عودة صريحة لمركز التقارير
  /// (نمط رأس الشاشة القائم R16-b قبل هوية SIM).
  void _backToReports(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.maybePop();
    } else {
      context.go('/reports');
    }
  }

  List<Widget> _buildContent(BuildContext context, ProfitReportViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final report = state.report;

    if (state.loading && report == null) {
      return const [ListSkeleton(rows: 8)];
    }
    if (state.error != null && report == null) {
      return [
        ErrorState(
          title: l10n.genericErrorTitle,
          message: l10n.dbOpenErrorMessage,
          technicalDetails: state.error.toString(),
          retryLabel: l10n.commonRetry,
          onRetry: vm.load,
          compact: true,
        ),
      ];
    }
    if (report == null) {
      return const [ListSkeleton(rows: 4)];
    }
    if (!report.hasAnyActivity) {
      return [
        EmptyState(
          icon: Icons.celebration_rounded,
          title: l10n.profitEmptyTitle,
          message: l10n.profitEmptyBody,
          compact: true,
        ),
      ];
    }
    return [
      // فشل تحديث مع بقاء نسخة قديمة — تنبيه رقيق لا يحجب المحتوى.
      if (state.error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: FinColors.of(context).warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.profitStaleWarning,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ProfitReportLinesCard(state: state, report: report),
      const SizedBox(height: 12),
      ProfitReportTotalCard(state: state, report: report),
      const SizedBox(height: 12),
      ProfitReportDrawingsCard(state: state, report: report),
      const SizedBox(height: 12),
      ProfitReportOwnerCard(state: state, report: report),
      const SizedBox(height: 14),
      ProfitReportMetaFooter(state: state, report: report),
      const SizedBox(height: 8),
    ];
  }
}

/// يفتح معاينة PDF — كل القيم تُلتقط قبل أي await (لا سياق عبر فجوة
/// غير متزامنة — نمط تقرير الوردية). **الباني الغني القائم كما هو**
/// (V7-C: زر PDF بالشريط الثلاثي يستهلكه حرفيًا).
void _openProfitPdf(BuildContext context, ProfitReportViewModel vm) {
  final l10n = AppLocalizations.of(context)!;
  final app = context.read<AppController>();
  final state = vm.state;
  final report = state.report;
  if (report == null) return;
  final company = app.company;
  final currencyCode = state.currencyCode;
  final decimals = state.decimals;
  final generatedAt = state.loadedAt ?? DateTime.now();
  unawaited(
    showPdfPreviewDialog(
      context,
      title: l10n.profitPdfTitle,
      build: () async {
        final doc = buildProfitPrintDoc(
          l10n: l10n,
          report: report,
          company: company,
          currencyCode: currencyCode,
          decimals: decimals,
          generatedAt: generatedAt,
        );
        return const ProfitReportPdfBuilder().build(doc);
      },
      whatsappPhone: company?.whatsapp ?? company?.phone,
      shareMessage: l10n.profitPrintShareMessage(
        profitReportPlainDate(report.from),
        profitReportPlainDate(report.to),
        AmountText.format(report.profit, decimals),
        currencyCode,
      ),
    ),
  );
}
