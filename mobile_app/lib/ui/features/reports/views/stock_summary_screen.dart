/// شاشة «ملخص حركة المخزون» (FR-09-04 — الشريحة 10): لكل صنف **تحرّك**
/// في الفترة — أعمدة الوارد/الصادر/المرتجع/التسوية + الرصيد الختامي
/// وقيمته بالتكلفة، مرتّبة بالقيمة تنازلياً. الرأس: عدد الأصناف
/// المتحركة + إجمالي قيمة المخزون بالتكلفة.
///
/// V1 مخزن واحد (بلا مرشح مخزن — قرار البريف)؛ الرصيد الختامي مصدر
/// الحقيقة من كل الحركات حتى نهاية الفترة (رأس المستودع).
library;

import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../view_models/movement_reports_view_model.dart';
import 'widgets/period_preset_bar.dart';

/// شاشة ملخص حركة المخزون — مسار مقترح `/reports/stock-summary`.
class StockSummaryScreen extends StatelessWidget {
  const StockSummaryScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها
  /// من قاعدة AppController مباشرة (نمط شاشة الأرباح).
  final StockSummaryViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final StockSummaryViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = StockSummaryViewModel(
        movementRepo: MovementReportsRepository(app.database!.db),
        companyRepo: app.companies,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<StockSummaryViewModel>.value(
      value: vm,
      child: const _StockSummaryBody(),
    );
  }
}

class _StockSummaryBody extends StatelessWidget {
  const _StockSummaryBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StockSummaryViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.stockSummaryTitle),
            if (state.rows != null && state.rows!.isNotEmpty)
              Text(
                l10n.stockSummaryTotalItems(state.rows!.length),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
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

  List<Widget> _buildContent(BuildContext context, StockSummaryViewModel vm) {
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
          icon: Icons.waves_rounded,
          title: l10n.stockSummaryEmptyTitle,
          message: l10n.stockSummaryEmptyBody,
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
      _TotalsCard(key: const Key('stockSummary_totals_card'), state: state),
      const SizedBox(height: 12),
      for (var i = 0; i < rows.length; i++)
        Padding(
          key: Key('stockSummary_row_$i'),
          padding: const EdgeInsets.only(bottom: 10),
          child: _StockSummaryRowCard(
            row: rows[i],
            decimals: state.decimals,
            currencyCode: state.currencyCode,
          ),
        ),
      const SizedBox(height: 6),
      Text(
        state.currencyCode.isEmpty
            ? l10n.stockSummaryPeriodLabel(
                _fmtDate(context, state.from!),
                _fmtDate(context, state.to!),
              )
            : '${l10n.stockSummaryPeriodLabel(_fmtDate(context, state.from!), _fmtDate(context, state.to!))} · ${state.currencyCode}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ];
  }
}

/// رأس الشاشة: عدد الأصناف المتحركة + إجمالي قيمة المخزون بالتكلفة.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({super.key, required this.state});

  final StockSummaryState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return FinCard(
      accent: colors.gold,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.stockSummaryTotalItems(state.rows?.length ?? 0),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.stockSummaryTotalValue,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              AmountText(
                amount: state.totalValueAtCost,
                size: AmountSize.large,
                decimals: state.decimals,
              ),
              if (state.currencyCode.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  state.currencyCode,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: colors.gold),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// صف صنف واحد: الاسم + الرصيد النهائي وقيمته + أعمدة التدفق الأربعة.
class _StockSummaryRowCard extends StatelessWidget {
  const _StockSummaryRowCard({
    required this.row,
    required this.decimals,
    required this.currencyCode,
  });

  final StockSummaryRow row;
  final int decimals;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);

    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              // شارة القيمة بالتكلفة — الترتيب بها تنازلياً.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        AmountText.format(row.valueAtCost, decimals),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.gold,
                            ),
                      ),
                    ),
                    if (currencyCode.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      Text(
                        currencyCode,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: colors.gold),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.stockSummaryEndBalance}: ',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  _qtyText(row.endBalance).replaceFirst('+', ''),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // أعمدة التدفق الأربعة — شارات ملونة بالاتجاه (وارد أخضر /
          // صادر أحمر / مرتجع تيل / تسوية دافئة).
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FlowChip(
                key: const Key('stockSummary_chip_in'),
                label: l10n.stockSummaryQtyIn,
                value: row.qtyIn,
                color: colors.positive,
                bg: colors.positiveContainer,
                fg: colors.onPositiveContainer,
              ),
              _FlowChip(
                key: const Key('stockSummary_chip_out'),
                label: l10n.stockSummaryQtyOut,
                value: -row.qtyOut,
                color: colors.negative,
                bg: colors.negativeContainer,
                fg: colors.onNegativeContainer,
              ),
              _FlowChip(
                key: const Key('stockSummary_chip_returns'),
                label: l10n.stockSummaryQtyReturns,
                value: row.qtyReturns,
                color: scheme.primary,
                bg: scheme.primaryContainer,
                fg: scheme.onPrimaryContainer,
              ),
              _FlowChip(
                key: const Key('stockSummary_chip_adjust'),
                label: l10n.stockSummaryQtyAdjust,
                value: row.qtyAdjustNet,
                color: colors.warning,
                bg: colors.warningContainer,
                fg: colors.onWarningContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// شارة تدفق واحدة (كمية موقّعة) — صفر = محايدة خافتة.
class _FlowChip extends StatelessWidget {
  const _FlowChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.fg,
  });

  final String label;
  final double value;
  final Color color;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isZero = value == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isZero ? scheme.surfaceContainerHigh : bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: isZero ? scheme.onSurfaceVariant : fg),
          ),
          const SizedBox(width: 4),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              _qtyText(value),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isZero ? scheme.onSurfaceVariant : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// كمية موقّعة للعرض: إشارة + أرقام غربية بفواصل (صفر منازل للصحيح
/// و٣ للكسري) — داخل LTR دائماً.
String _qtyText(double qty) {
  final decimals = qty == qty.truncateToDouble() ? 0 : 3;
  final formatted = AmountText.format(qty.abs(), decimals);
  final marker = qty < 0 ? '−' : '+';
  return '$marker$formatted';
}

/// تاريخ للعرض `يوم/شهر/سنة` بنظام أرقام السياق (نمط شاشة الأرباح).
String _fmtDate(BuildContext context, DateTime date) {
  final plain = '${date.day}/${date.month}/${date.year}';
  return NumeralsScope.of(context) ? Numerals.toArabicIndic(plain) : plain;
}
