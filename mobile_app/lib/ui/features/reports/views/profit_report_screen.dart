/// شاشة «الأرباح والخسائر» (FR-09-02 — الشريحة 10): تقرير الفترة عبر
/// خريطة الترحيل (ملحق و) — شريط فترات مسبقة/مخصصة، بطاقة البنود
/// بأقسام (الإيراد/التكلفة/التسويات/المصاريف) بإشارات ملوّنة، بطاقة
/// الربح الذهبية البارزة، مسحوبات المالك المستقلة، وسطر الإغلاق
/// «صافي ما بقي للمالك»، مع تقرير PDF عبر نافذة المعاينة.
///
/// اصطلاح العرض: إشارة كل سطر = **إسهامه في الربح** (+ يزيد/− يقلّ) —
/// الدهشة المحاسبية الوحيدة: تكلفة المرتجع تظهر موجبة لأنها تُخصم من
/// COGS داخل الصيغة الملزمة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/profit_report_repository.dart';
import '../../../../domain/services/numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../../printing/services/profit_report_pdf_builder.dart';
import '../../printing/views/pdf_preview_dialog.dart';
import '../view_models/profit_report_view_model.dart';
import 'widgets/period_preset_bar.dart';

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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.profitTitle),
            if (state.report != null)
              Text(
                state.currencyCode.isEmpty
                    ? l10n.profitBaseCurrencyNote
                    : '${l10n.profitBaseCurrencyNote} (${state.currencyCode})',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          // معاينة PDF — متاحة فور اكتمال التقرير.
          if (state.report != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: l10n.profitPdfButton,
              onPressed: () => _openProfitPdf(context, vm),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: vm.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              PeriodPresetBar(
                selected: state.period,
                currentFrom: state.from,
                currentTo: state.to,
                onPeriodSelected: (period) => unawaited(vm.setPeriod(period)),
                onCustomRange: (from, to) =>
                    unawaited(vm.setCustomRange(from, to)),
              ),
              const SizedBox(height: 14),
              ..._buildContent(context, vm),
            ],
          ),
        ),
      ),
    );
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
      _LinesCard(state: state, report: report),
      const SizedBox(height: 12),
      _ProfitCard(state: state, report: report),
      const SizedBox(height: 12),
      _DrawingsCard(state: state, report: report),
      const SizedBox(height: 12),
      _NetForOwnerCard(state: state, report: report),
      const SizedBox(height: 14),
      _MetaFooter(state: state, report: report),
      const SizedBox(height: 8),
      // زر PDF سفلي — إجراء أساسي للتقرير (مع إجراء الترويسة).
      SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: () => _openProfitPdf(context, vm),
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
          label: Text(l10n.profitPdfButton),
        ),
      ),
    ];
  }
}

/// بطاقة البنود: أقسام الإيراد/التكلفة/التسويات/المصاريف — كل سطر
/// بمقداره (بالعملة الأساسية) وإشارته الملوّنة بدلالة إسهامه في الربح.
class _LinesCard extends StatelessWidget {
  const _LinesCard({required this.state, required this.report});

  final ProfitReportState state;
  final ProfitReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final decimals = state.decimals;
    return FinCard(
      key: const Key('profit_lines_card'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(label: l10n.profitSectionRevenue),
          _ProfitRow(
            label: l10n.profitSales,
            amount: report.sales,
            sign: FinSign.incoming,
            decimals: decimals,
            trailing: _countChip(context, l10n, report.salesInvoiceCount),
          ),
          _ProfitRow(
            label: l10n.profitSalesReturns,
            amount: report.salesReturns,
            sign: report.salesReturns > 0 ? FinSign.outgoing : FinSign.neutral,
            decimals: decimals,
            trailing: _countChip(context, l10n, report.returnInvoiceCount),
          ),
          _ProfitRow(
            label: l10n.profitNetSales,
            amount: report.netSales,
            sign: _signOf(report.netSales),
            decimals: decimals,
            strong: true,
          ),
          const SizedBox(height: 12),
          _SectionLabel(label: l10n.profitSectionCost),
          _ProfitRow(
            label: l10n.profitCogs,
            amount: report.cogs,
            sign: report.cogs > 0 ? FinSign.outgoing : FinSign.neutral,
            decimals: decimals,
          ),
          _ProfitRow(
            label: l10n.profitReturnCost,
            amount: report.returnCost,
            sign: _signOf(report.returnCost),
            decimals: decimals,
          ),
          _ProfitRow(
            label: l10n.profitNetCogs,
            amount: report.netCogs,
            sign: report.netCogs > 0 ? FinSign.outgoing : FinSign.neutral,
            decimals: decimals,
            strong: true,
          ),
          const SizedBox(height: 12),
          _SectionLabel(label: l10n.profitSectionAdjustments),
          _ProfitRow(
            label: l10n.profitStockSurplus,
            amount: report.stockSurplus,
            sign: _signOf(report.stockSurplus),
            decimals: decimals,
          ),
          _ProfitRow(
            label: l10n.profitStockShortage,
            amount: report.stockShortage,
            sign: report.stockShortage > 0 ? FinSign.outgoing : FinSign.neutral,
            decimals: decimals,
          ),
          _ProfitRow(
            label: l10n.profitFx,
            amount: report.fxGainLoss,
            sign: _signOf(report.fxGainLoss),
            decimals: decimals,
          ),
          const SizedBox(height: 12),
          _SectionLabel(label: l10n.profitSectionExpenses),
          _ProfitRow(
            label: l10n.profitExpenses,
            amount: report.expenses,
            sign: report.expenses > 0 ? FinSign.outgoing : FinSign.neutral,
            decimals: decimals,
          ),
          const SizedBox(height: 4),
          Text(
            state.currencyCode.isEmpty
                ? l10n.profitBaseCurrencyNote
                : '${l10n.profitBaseCurrencyNote} · ${state.currencyCode}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// شريحة عدد الفواتير الصغيرة (تفصيل رخيص من المستودع).
  Widget _countChip(BuildContext context, AppLocalizations l10n, int count) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Text(
        l10n.profitInvoicesCount(count),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// بطاقة الربح البارزة — شريط ذهبي وقيمة عرض كبيرة بإشارة ملوّنة.
class _ProfitCard extends StatelessWidget {
  const _ProfitCard({required this.state, required this.report});

  final ProfitReportState state;
  final ProfitReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FinCard(
      key: const Key('profit_total_card'),
      accent: FinColors.of(context).gold,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.profitTotal,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          AmountText(
            amount: report.profit.abs(),
            sign: _signOf(report.profit),
            size: AmountSize.display,
            decimals: state.decimals,
          ),
        ],
      ),
    );
  }
}

/// مسحوبات المالك — بند مستيل خارج المصاريف (تقديم خافت).
class _DrawingsCard extends StatelessWidget {
  const _DrawingsCard({required this.state, required this.report});

  final ProfitReportState state;
  final ProfitReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return FinCard(
      key: const Key('profit_drawings_card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.profitOwnerSection,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          AmountText(
            amount: report.ownerDrawings,
            sign: report.ownerDrawings > 0 ? FinSign.outgoing : FinSign.neutral,
            decimals: state.decimals,
          ),
        ],
      ),
    );
  }
}

/// سطر الإغلاق: «صافي ما بقي للمالك» — بطاقة مؤكدة متباينة بالاتجاه.
class _NetForOwnerCard extends StatelessWidget {
  const _NetForOwnerCard({required this.state, required this.report});

  final ProfitReportState state;
  final ProfitReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final isNegative = report.netForOwner < 0;
    return FinCard(
      key: const Key('profit_owner_card'),
      accent: Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.all(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isNegative
              ? colors.negativeContainer
              : colors.positiveContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.profitNetForOwner,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isNegative
                      ? colors.onNegativeContainer
                      : colors.onPositiveContainer,
                ),
              ),
            ),
            AmountText(
              amount: report.netForOwner.abs(),
              sign: _signOf(report.netForOwner),
              size: AmountSize.large,
              decimals: state.decimals,
            ),
          ],
        ),
      ),
    );
  }
}

/// ميتا التقرير: الفترة + لحظة الإنشاء.
class _MetaFooter extends StatelessWidget {
  const _MetaFooter({required this.state, required this.report});

  final ProfitReportState state;
  final ProfitReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final loadedAt = state.loadedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.profitPeriodLabel(
            _fmtDate(context, report.from),
            _fmtDate(context, report.to),
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (loadedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              l10n.profitGeneratedAt(_fmtDateTime(context, loadedAt)),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// عنوان قسم داخل بطاقة البنود.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: scheme.primary),
      ),
    );
  }
}

/// سطر بند واحد: التسمية + المبلغ بإشارته الملوّنة (+/−).
class _ProfitRow extends StatelessWidget {
  const _ProfitRow({
    required this.label,
    required this.amount,
    required this.sign,
    required this.decimals,
    this.strong = false,
    this.trailing,
  });

  final String label;
  final double amount;
  final FinSign sign;
  final int decimals;

  /// سطر مجمع قوي (صافي المبيعات/التكلفة) — عريض بفاصل علوي.
  final bool strong;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: strong ? 8 : 2, bottom: 2),
      child: Column(
        children: [
          if (strong)
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: strong
                        ? Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w800)
                        : Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                ?trailing,
                AmountText(
                  amount: amount.abs(),
                  sign: sign,
                  size: strong ? AmountSize.large : AmountSize.row,
                  decimals: decimals,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// إشارة العرض من قيمة موقّعة (صفر = محايد).
FinSign _signOf(double value) {
  if (value > 0.005) return FinSign.incoming;
  if (value < -0.005) return FinSign.outgoing;
  return FinSign.neutral;
}

/// يفتح معاينة PDF — كل القيم تُلتقط قبل أي await (لا سياق عبر فجوة
/// غير متزامنة — نمط تقرير الوردية).
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
        _fmtPlainDate(report.from),
        _fmtPlainDate(report.to),
        AmountText.format(report.profit, decimals),
        currencyCode,
      ),
    ),
  );
}

/// تاريخ للعرض `يوم/شهر/سنة` بنظام أرقام السياق (نمط شاشة الأعمار).
String _fmtDate(BuildContext context, DateTime date) {
  final plain = _fmtPlainDate(date);
  return NumeralsScope.of(context) ? Numerals.toArabicIndic(plain) : plain;
}

/// تاريخ ووقت للعرض `يوم/شهر/سنة ساعة:دقيقة` بنظام أرقام السياق.
String _fmtDateTime(BuildContext context, DateTime date) {
  final plain =
      '${_fmtPlainDate(date)} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return NumeralsScope.of(context) ? Numerals.toArabicIndic(plain) : plain;
}

String _fmtPlainDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
