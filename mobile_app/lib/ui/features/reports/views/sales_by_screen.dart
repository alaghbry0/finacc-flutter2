/// شاشة «المبيعات حسب» (FR-09-06 — الشريحة 10) بهوية Simple Invoice
/// Manager (V7-C): ترويسة فرعية برجوع منطقي إلى مركز التقارير، رقائق
/// الأبعاد وشريط الفترات والصفوف كما هي، و**شريط التصدير الثلاثي
/// الثابت أسفل الشاشة** (صورة/PDF/تفوق) بمسقط جدولي من صفوف التجميع
/// الحية (تسمية البعد + المبلغ) وصف إجمالي بمجموع الفترة.
///
/// تجميع مبيعات الفترة (فواتير البيع المكتملة بالعملة الأساسية) حسب
/// العميل/الفئة/الصنف/اليوم عبر رقائق أبعاد + شريط الفترات. كل صف:
/// التسمية + المبلغ + عدد الفواتير + **رقاقة النسبة** عن الفترة
/// السابقة المساوية في الطول (أخضر ارتفاع / أحمر انخفاض / محجوبة
/// عند null — لا سابقة).
///
/// التسمية الفارغة تُترجم حسب البعد: «عميل نقدي» (بلا عميل) أو
/// «غير مصنّف» (قرار 10 برأس المستودع)؛ بعد «اليوم» يعرض التاريخ
/// بترتيب تصاعدي.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/movement_reports_repository.dart';
import '../../../../domain/services/numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/fin_date_text.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../../../core/widgets/sim_list_widgets.dart';
import '../../sell/views/widgets/sim_invoice_widgets.dart' show SimDarkTotalBar;
import '../view_models/movement_reports_view_model.dart';
import 'widgets/period_preset_bar.dart';
import 'widgets/report_print_projection.dart';
import 'widgets/sim_report_export_bar.dart';

/// شاشة المبيعات حسب — مسار مقترح `/reports/sales-by`.
class SalesByScreen extends StatelessWidget {
  const SalesByScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها
  /// من قاعدة AppController مباشرة (نمط شاشة الأرباح).
  final SalesByViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final SalesByViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = SalesByViewModel(
        movementRepo: MovementReportsRepository(app.database!.db),
        companyRepo: app.companies,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<SalesByViewModel>.value(
      value: vm,
      child: const _SalesByBody(),
    );
  }
}

class _SalesByBody extends StatelessWidget {
  const _SalesByBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SalesByViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SimSubHeader(
              titleKey: const Key('sales_by_title'),
              title: l10n.salesByTitle,
              onBack: () => _backToReports(context),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: vm.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _DimensionBar(
                      selected: state.dimension,
                      onSelected: (dimension) =>
                          unawaited(vm.setDimension(dimension)),
                    ),
                    const SizedBox(height: 12),
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
      // الثلاثية الثابتة بمسقط من صفوف التجميع الحية (تعطيل حتى تكتمل).
      bottomNavigationBar: SimReportExportBar(
        title: l10n.salesByTitle,
        doc: state.rows == null
            ? null
            : buildSalesByPrintDoc(
                l10n: l10n,
                company: context.read<AppController>().company,
                state: state,
              ),
      ),
    );
  }

  /// رجوع منطقي: pop إن كان متاحاً وإلا عودة صريحة لمركز التقارير.
  void _backToReports(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.maybePop();
    } else {
      context.go('/reports');
    }
  }

  List<Widget> _buildContent(BuildContext context, SalesByViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final rows = state.rows;

    if (state.loading && rows == null) {
      return const [ListSkeleton(rows: 8)];
    }
    if (state.error != null && rows == null) {
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
    if (rows == null) {
      return const [ListSkeleton(rows: 4)];
    }
    if (rows.isEmpty) {
      return [
        EmptyState(
          icon: Icons.point_of_sale_rounded,
          title: l10n.salesByEmptyTitle,
          message: l10n.salesByEmptyBody,
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
      _TotalCard(key: const Key('salesBy_total_card'), state: state),
      const SizedBox(height: 12),
      for (var i = 0; i < rows.length; i++)
        Padding(
          key: Key('salesBy_row_$i'),
          padding: const EdgeInsets.only(bottom: 10),
          child: _SalesRowCard(
            row: rows[i],
            dimension: state.dimension,
            decimals: state.decimals,
          ),
        ),
      const SizedBox(height: 6),
      Text(
        l10n.salesByChangeNote,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 4),
      Text(
        state.currencyCode.isEmpty
            ? l10n.salesByPeriodLabel(
                FinDateText.date(context, state.from!),
                FinDateText.date(context, state.to!),
              )
            : '${l10n.salesByPeriodLabel(FinDateText.date(context, state.from!), FinDateText.date(context, state.to!))} · ${state.currencyCode}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ];
  }
}

/// شريط رقائق الأبعاد الأربعة (العميل/الفئة/الصنف/اليوم) — أفقية RTL
/// بأهداف لمس ≥ 48dp ومفاتيح ثابتة للاختبارات.
class _DimensionBar extends StatelessWidget {
  const _DimensionBar({required this.selected, required this.onSelected});

  final SalesByDimension selected;
  final ValueChanged<SalesByDimension> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          // RTL: «العميل» أقصى اليمين.
          children: [
            for (final dimension in SalesByDimension.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 6),
                child: Center(
                  child: ChoiceChip(
                    key: Key(_dimensionKey(dimension)),
                    label: Text(_dimensionLabel(l10n, dimension)),
                    selected: dimension == selected,
                    onSelected: (_) => onSelected(dimension),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// مفتاح رقاقة البعد الثابت — salesByTabCustomer/… (لاختبارات).
String _dimensionKey(SalesByDimension dimension) => switch (dimension) {
  SalesByDimension.customer => 'salesByTabCustomer',
  SalesByDimension.category => 'salesByTabCategory',
  SalesByDimension.item => 'salesByTabItem',
  SalesByDimension.day => 'salesByTabDay',
};

/// تسمية البعد.
String _dimensionLabel(AppLocalizations l10n, SalesByDimension dimension) =>
    switch (dimension) {
      SalesByDimension.customer => l10n.salesByCustomer,
      SalesByDimension.category => l10n.salesByCategory,
      SalesByDimension.item => l10n.salesByItem,
      SalesByDimension.day => l10n.salesByDay,
    };

/// رأس الشاشة (V7-C — هوية SIM): شريط **الإجمالي الداكن** بنمط
/// SimDarkTotalBar لإجمالي مبيعات الفترة بالعملة الأساسية — نفس بيانات
/// بطاقة الإجمالي القائمة (التسمية والمبلغ والعملة).
class _TotalCard extends StatelessWidget {
  const _TotalCard({super.key, required this.state});

  final SalesByState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SimDarkTotalBar(
          label: l10n.salesByTotal,
          amount: AmountText.formatFor(
            context,
            state.totalSalesBase,
            state.decimals,
          ),
        ),
        if (state.currencyCode.isNotEmpty) ...[
          const SizedBox(height: 6),
          Center(
            child: Text(
              state.currencyCode,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: colors.gold),
            ),
          ),
        ],
      ],
    );
  }
}

/// صف مبيعات واحد: التسمية + المبلغ + عدد الفواتير + رقاقة النسبة.
class _SalesRowCard extends StatelessWidget {
  const _SalesRowCard({
    required this.row,
    required this.dimension,
    required this.decimals,
  });

  final SalesByRow row;
  final SalesByDimension dimension;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _rowLabel(context, l10n),
                  maxLines: dimension == SalesByDimension.day ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              AmountText(amount: row.salesBase, decimals: decimals),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.salesByInvoicesCount(row.invoiceCount),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              // null = لا فترة سابقة → الرقاقة محجوبة (اصطلاح FR-09-06).
              if (row.changePct != null)
                _ChangeChip(
                  key: const Key('salesBy_change_chip'),
                  changePct: row.changePct!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// نص التسمية حسب البعد: الفارغة تُترجم (عميل نقدي/غير مصنّف)،
  /// والتاريخ يُنسَّق `يوم/شهر/سنة`.
  String _rowLabel(BuildContext context, AppLocalizations l10n) {
    if (row.label.isEmpty) {
      return dimension == SalesByDimension.customer
          ? l10n.salesByNoCustomer
          : l10n.salesByUncategorized;
    }
    if (dimension == SalesByDimension.day) {
      final day = DateTime.tryParse(row.label);
      if (day != null) {
        return FinDateText.date(context, day);
      }
    }
    return row.label;
  }
}

/// رقاقة النسبة: أخضر ارتفاع / أحمر انخفاض / محايدة عند الصفر —
/// العلامة غير اللونية سهم الاتجاه (§6.1).
class _ChangeChip extends StatelessWidget {
  const _ChangeChip({super.key, required this.changePct});

  final double changePct;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pctText = _pctText(context, changePct);

    final (bg, fg, icon, text) = changePct > 0
        ? (
            colors.positiveContainer,
            colors.onPositiveContainer,
            Icons.arrow_drop_up_rounded,
            l10n.changeUp(pctText),
          )
        : changePct < 0
        ? (
            colors.negativeContainer,
            colors.onNegativeContainer,
            Icons.arrow_drop_down_rounded,
            l10n.changeDown(pctText),
          )
        : (
            scheme.surfaceContainerHigh,
            scheme.onSurfaceVariant,
            Icons.remove_rounded,
            '0٪',
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 2),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// نسبة للعرض: منزلة واحدة تُحذف إن كانت صفراً + ٪ (نمط الداشبورد).
String _pctText(BuildContext context, double pct) {
  final text = pct.abs().toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  return NumeralsScope.of(context) ? Numerals.toArabicIndic(text) : text;
}
