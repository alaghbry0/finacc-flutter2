/// شاشة «أصناف تنفذ قريباً» (دليل 02/04): عتبة الحد الأدنى (افتراضياً 5)
/// + بحث بالاسم + قائمة أصناف بكمية مقابل الحد مع شريط تقدم ملون
/// ورسالة الفراغ «لا توجد أصناف ضمن هذه المعايير».
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/low_stock_view_model.dart';

class LowStockScreen extends StatelessWidget {
  const LowStockScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final LowStockViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final LowStockViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = LowStockViewModel(itemRepo: app.items!);
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<LowStockViewModel>.value(
      value: vm,
      child: const _LowStockBody(),
    );
  }
}

class _LowStockBody extends StatefulWidget {
  const _LowStockBody();

  @override
  State<_LowStockBody> createState() => _LowStockBodyState();
}

class _LowStockBodyState extends State<_LowStockBody> {
  final TextEditingController _thresholdController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _thresholdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LowStockViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.lowStockTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    key: const Key('low_stock_threshold_field'),
                    controller: _thresholdController,
                    onChanged: vm.onThresholdChanged,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.lowStockThresholdLabel,
                      prefixIcon: const Icon(Icons.warning_amber_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('low_stock_search_field'),
                    controller: _searchController,
                    onChanged: vm.setQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.lowStockSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: [
                Text(
                  l10n.lowStockResultCount(state.visible.length),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildContent(context, vm, state)),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    LowStockViewModel vm,
    LowStockState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (state.loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [ListSkeleton(rows: 5)],
      );
    }
    if (state.error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ErrorState(
            title: l10n.genericErrorTitle,
            message: l10n.dbOpenErrorMessage,
            technicalDetails: state.error.toString(),
            retryLabel: l10n.commonRetry,
            onRetry: vm.load,
            compact: true,
          ),
        ],
      );
    }
    if (state.visible.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          EmptyState(
            icon: Icons.task_alt_rounded,
            title: l10n.lowStockEmptyTitle,
            message: l10n.lowStockEmptyBody,
            compact: true,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        for (final info in state.visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LowStockCard(info: info),
          ),
      ],
    );
  }
}

/// بطاقة صنف نافد — الكمية مقابل الحد بشريط تقدم ملون.
class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.info});

  final ItemStockInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final item = info.item;
    final minStock = item.minStock <= 0 ? 1 : item.minStock;
    final ratio = (info.totalQty / minStock).clamp(0.0, 1.0);
    final progressColor = info.totalQty <= 0
        ? colors.negative
        : (info.totalQty <= item.minStock ? colors.warning : colors.positive);

    return FinCard(
      onTap: () => context.go('/inventory/item/${item.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  info.totalQty <= 0
                      ? Icons.production_quantity_limits_rounded
                      : Icons.trending_down_rounded,
                  size: 20,
                  color: progressColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.itemDetailMinStockLabel}: ',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AmountText.formatFor(context, info.totalQty, 0),
                    style: FinText.amountRow(colors.negative),
                  ),
                  Text(
                    l10n.itemsListStockLabel,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio),
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 7,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: progressColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AmountText(amount: item.minStock, decimals: 0),
            ],
          ),
        ],
      ),
    );
  }
}
