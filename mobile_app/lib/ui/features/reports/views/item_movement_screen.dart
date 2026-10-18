/// شاشة «حركة صنف» (FR-09-03 — الشريحة 10): بطاقة صنف كاملة في فترة —
/// كل حركاته (شراء/بيع/مرتجعات/تسويات) مع **الباقي التراكمي** بعد كل
/// حركة، معروضة تنازلياً (الأحدث أولاً) بينما يُحسب الرصيد تصاعدياً في
/// المستودع. رأس الشاشة: رصيد ما قبل الفترة + إجماليا الوارد/الصادر +
/// التكلفة الحالية للوحدة. اختيار الصنف عبر نافذة بحث (اسم/باركود)
/// ببطاقات تُظهر المخزون — بنمط نافذة اختيار صنف البيع.
///
/// رقاقة النوع ملوّنة بالفئة: وارد أخضر / صادر أحمر / مرتجع تيل
/// (الأساس البراندي) / تسوية ذهبي (زوج التحذير الدافئ — لا يوجد زوج
/// نصي ذهبي في DS).
///
/// (R19-D3a: الويدجت المركزّة في `widgets/` — بطاقة الاختيار البطلة
/// ورأس التقرير وصف الحركة ونافذة الاختيار ومساعدات التنسيق.)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/movement_reports_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_date_text.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/movement_reports_view_model.dart';
import 'widgets/item_movement_hero_card.dart';
import 'widgets/item_movement_picker_sheet.dart';
import 'widgets/item_movement_summary_card.dart';
import 'widgets/item_movement_tile.dart';
import 'widgets/period_preset_bar.dart';

/// شاشة تقرير حركة صنف — مسار مقترح `/reports/item-movement`.
class ItemMovementScreen extends StatelessWidget {
  const ItemMovementScreen({super.key, this.viewModel, this.productId});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها
  /// من قاعدة AppController مباشرة (نمط شاشة الأرباح).
  final ItemMovementViewModel? viewModel;

  /// الصنف الابتدائي عند الدخول من مسار يحمل معرّفاً (تفاصيل صنف مثلاً).
  final int? productId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final ItemMovementViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = ItemMovementViewModel(
        movementRepo: MovementReportsRepository(app.database!.db),
        companyRepo: app.companies,
        productId: productId,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<ItemMovementViewModel>.value(
      value: vm,
      child: const _ItemMovementBody(),
    );
  }
}

class _ItemMovementBody extends StatelessWidget {
  const _ItemMovementBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ItemMovementViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.itemMovementTitle),
            if (state.report != null)
              Text(
                state.report!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

  /// محتوى الشاشة بحرّاس خروج مبكرين: لا صنف ← تحميل ← خطأ ← لا تقرير ←
  /// المحتوى (نفس دلالة السلاسل الأصلية حرفياً).
  List<Widget> _buildContent(BuildContext context, ItemMovementViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final report = state.report;

    // لا صنف بعد — بطاقة الاختيار البطلة (ليست حالة خطأ ولا فراغ).
    if (state.needsProduct) {
      return [
        ItemMovementPickerHeroCard(
          key: const Key('itemMovement_pick_card'),
          onPick: () => openItemMovementProductPicker(context, vm),
        ),
      ];
    }

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
      ItemMovementSummaryCard(
        key: const Key('itemMovement_summary_card'),
        state: state,
        report: report,
        onPick: () => openItemMovementProductPicker(context, vm),
      ),
      const SizedBox(height: 12),
      if (report.rows.isEmpty) ...[
        EmptyState(
          icon: Icons.waves_rounded,
          title: l10n.itemMovementEmptyTitle,
          message: l10n.itemMovementEmptyBody,
          compact: true,
        ),
      ] else
        // العرض تنازلي (الأحدث أولاً) — المستودع يرتب تصاعدياً للتراكم.
        for (var i = 0; i < report.rows.length; i++)
          Padding(
            key: Key('itemMovement_row_$i'),
            padding: const EdgeInsets.only(bottom: 10),
            child: ItemMovementTile(
              row: report.rows[report.rows.length - 1 - i],
              decimals: state.decimals,
            ),
          ),
      const SizedBox(height: 6),
      Text(
        state.currencyCode.isEmpty
            ? l10n.itemMovementPeriodLabel(
                FinDateText.date(context, report.from),
                FinDateText.date(context, report.to),
              )
            : '${l10n.itemMovementPeriodLabel(FinDateText.date(context, report.from), FinDateText.date(context, report.to))} · ${state.currencyCode}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ];
  }
}
