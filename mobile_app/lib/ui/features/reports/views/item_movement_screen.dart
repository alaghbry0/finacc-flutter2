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
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/item_repository.dart';
import '../../../../data/repositories/movement_reports_repository.dart';
import '../../../../domain/models/item.dart';
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

  List<Widget> _buildContent(BuildContext context, ItemMovementViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final report = state.report;

    // لا صنف بعد — بطاقة الاختيار البطلة (ليست حالة خطأ ولا فراغ).
    if (state.needsProduct) {
      return [
        _ProductPickerHeroCard(
          key: const Key('itemMovement_pick_card'),
          onPick: () => _openProductPicker(context, vm),
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
      _SummaryCard(
        key: const Key('itemMovement_summary_card'),
        state: state,
        report: report,
        onPick: () => _openProductPicker(context, vm),
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
            child: _MovementTile(
              row: report.rows[report.rows.length - 1 - i],
              decimals: state.decimals,
            ),
          ),
      const SizedBox(height: 6),
      Text(
        state.currencyCode.isEmpty
            ? l10n.itemMovementPeriodLabel(
                _fmtDate(context, report.from),
                _fmtDate(context, report.to),
              )
            : '${l10n.itemMovementPeriodLabel(_fmtDate(context, report.from), _fmtDate(context, report.to))} · ${state.currencyCode}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ];
  }
}

/// بطاقة الاختيار البطلة حين لم يُحدَّد صنف بعد.
class _ProductPickerHeroCard extends StatelessWidget {
  const _ProductPickerHeroCard({super.key, required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FinCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.manage_search_rounded,
                  size: 26,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.itemMovementPickTitle,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.itemMovementPickBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              key: const Key('itemMovement_pick_button'),
              onPressed: onPick,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: Text(l10n.itemMovementPickButton),
            ),
          ),
        ],
      ),
    );
  }
}

/// رأس التقرير: الصنف + رصيد ما قبل الفترة + إجماليا الوارد/الصادر +
/// التكلفة الحالية للوحدة + عدد الحركات.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    super.key,
    required this.state,
    required this.report,
    required this.onPick,
  });

  final ItemMovementState state;
  final ItemMovementReport report;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final decimals = state.decimals;

    return FinCard(
      accent: colors.gold,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  size: 20,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  key: const Key('itemMovement_product_name'),
                  report.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: l10n.itemMovementChangeProduct,
                icon: const Icon(Icons.swap_horiz_rounded),
                onPressed: onPick,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: l10n.itemMovementOpeningBalance,
                  value: _qtyPlain(report.openingBalance),
                ),
              ),
              Expanded(
                child: _StatCell(
                  label: l10n.itemMovementTotalIn,
                  value: _qtyText(report.totalIn),
                  color: colors.positive,
                ),
              ),
              Expanded(
                child: _StatCell(
                  label: l10n.itemMovementTotalOut,
                  value: _qtyOut(report.totalOut),
                  color: colors.negative,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.payments_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.itemMovementWacNow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              AmountText(amount: report.unitCostNow, decimals: decimals),
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
          const SizedBox(height: 6),
          Text(
            l10n.itemMovementMovementCount(report.rows.length),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// خلية إحصاء صغيرة (تسمية فوق قيمة).
class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color ?? scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// صف حركة واحد: رقاقة النوع + التاريخ + الكمية الموقّعة + شارة الباقي
/// التراكمي + تكلفة الوحدة والملاحظات.
class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.row, required this.decimals});

  final ItemMovementRow row;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final category = _categoryOf(row.movementType);

    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _MovementTypeChip(type: row.movementType, category: category),
              const Spacer(),
              // شارة الباقي التراكمي — العلامة المميزة للبطاقة (FR-09-03).
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.itemMovementBalanceAfter,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        _qtyText(row.balanceAfter).replaceFirst('+', ''),
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
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
                  _fmtDateTime(context, row.movedAt),
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  _qtyText(row.qty),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: switch (category) {
                      _MoveCategory.inbound => colors.positive,
                      _MoveCategory.outbound => colors.negative,
                      _MoveCategory.returns => scheme.primary,
                      _MoveCategory.adjust => colors.warning,
                    },
                  ),
                ),
              ),
            ],
          ),
          if (row.notes != null && row.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              row.notes!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.itemMovementUnitCost,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 4),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  AmountText.format(row.unitCost, decimals),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// فئة اتجاه الحركة — تقرّب لون الرقاقة (لا تستبدل تسمية النوع).
enum _MoveCategory { inbound, outbound, returns, adjust }

_MoveCategory _categoryOf(String type) => switch (type) {
  'purchase' || 'opening' || 'transfer_in' => _MoveCategory.inbound,
  'sale' || 'purchase_return' || 'transfer_out' => _MoveCategory.outbound,
  'sale_return' => _MoveCategory.returns,
  _ => _MoveCategory.adjust,
};

/// رقاقة نوع الحركة — تسمية النوع ملوّنة بفئة الاتجاه (وارد أخضر /
/// صادر أحمر / مرتجع تيل / تسوية ذهبي-دافئ).
class _MovementTypeChip extends StatelessWidget {
  const _MovementTypeChip({required this.type, required this.category});

  final String type;
  final _MoveCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final (bg, fg) = switch (category) {
      _MoveCategory.inbound => (
        colors.positiveContainer,
        colors.onPositiveContainer,
      ),
      _MoveCategory.outbound => (
        colors.negativeContainer,
        colors.onNegativeContainer,
      ),
      // التيل البراندي للمرتجعات (بذرة Deep Teal — §6.1).
      _MoveCategory.returns => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      // الزوج الدافئ الذهبي للتسويات (لا زوج نصي ذهبي في DS).
      _MoveCategory.adjust => (
        colors.warningContainer,
        colors.onWarningContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _typeLabel(l10n, type),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// تسمية نوع الحركة — مفاتيح movementType* الجديدة، واليدوي/المجهول
/// على مفتاحين قديمين موجودين أصلاً (itemMovementManualAdjust/Unknown).
String _typeLabel(AppLocalizations l10n, String type) => switch (type) {
  'purchase' => l10n.movementTypePurchase,
  'sale' => l10n.movementTypeSale,
  'sale_return' => l10n.movementTypeSaleReturn,
  'purchase_return' => l10n.movementTypePurchaseReturn,
  'stocktake_adjust' => l10n.movementTypeAdjust,
  'opening' => l10n.movementTypeOpening,
  'transfer_in' => l10n.movementTypeTransferIn,
  'transfer_out' => l10n.movementTypeTransferOut,
  'manual_adjust' => l10n.itemMovementManualAdjust,
  _ => l10n.itemMovementUnknown,
};

/// يفتح نافذة اختيار الصنف (بحث + مخزون) — بنمط نافذة البيع.
Future<void> _openProductPicker(
  BuildContext context,
  ItemMovementViewModel vm,
) async {
  final app = context.read<AppController>();
  final itemRepo = app.items ?? ItemRepository(app.database!.db);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _ProductPickerSheet(itemRepo: itemRepo, onPick: vm.setProduct),
  );
}

/// نافذة اختيار الصنف لحركة صنف — نقرة واحدة تختار وتغلق.
class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.itemRepo, required this.onPick});

  final ItemRepository itemRepo;
  final ValueChanged<int> onPick;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  /// نتائج البحث الجارية (null = جارٍ الجلب).
  List<ItemStockInfo>? _results;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() {
      _error = null;
      _results = null;
    });
    try {
      final results = await widget.itemRepo.searchItems(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(_search(query));
    });
  }

  void _pick(ItemStockInfo info) {
    Navigator.of(context).pop();
    widget.onPick(info.item.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: height * 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.itemMovementPickerTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonDone,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('itemMovement_picker_search_field'),
                controller: _searchController,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.itemMovementPickerSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            unawaited(_search(''));
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildResults(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_error != null) {
      return Center(
        child: ErrorState(
          title: l10n.genericErrorTitle,
          message: l10n.dbOpenErrorMessage,
          technicalDetails: _error.toString(),
          retryLabel: l10n.commonRetry,
          onRetry: () => unawaited(_search(_searchController.text)),
          compact: true,
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (results.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.itemMovementPickerNoResults,
          message: l10n.itemMovementPickerSearchHint,
          compact: true,
        ),
      );
    }
    return ListView.builder(
      key: const Key('itemMovement_picker_list'),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final info = results[index];
        return _PickerProductRow(info: info, onTap: () => _pick(info));
      },
    );
  }
}

/// صف صنف واحد في نافذة الاختيار — الاسم + الباركود + المخزون.
class _PickerProductRow extends StatelessWidget {
  const _PickerProductRow({required this.info, required this.onTap});

  final ItemStockInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final item = info.item;
    final outOfStock = !item.isService && info.totalQty <= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (item.isService ? scheme.tertiary : scheme.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.isService
                        ? Icons.miscellaneous_services_rounded
                        : Icons.inventory_2_rounded,
                    size: 20,
                    color: item.isService ? scheme.tertiary : scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (item.barcode != null && item.barcode!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.barcode!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ] else
                        const SizedBox(height: 2),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (item.isService)
                  Text(
                    l10n.itemServiceBadge,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.tertiary),
                  )
                else
                  Text(
                    outOfStock
                        ? l10n.sellPickerOutOfStock
                        : l10n.sellPickerAvailable(_qtyText(info.totalQty)),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: outOfStock
                          ? colors.negative
                          : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// كمية مجردة للعرض (بلا إشارة — أرصدة وافتتاحيات).
String _qtyPlain(double qty) {
  final decimals = qty == qty.truncateToDouble() ? 0 : 3;
  return AmountText.format(qty.abs(), decimals);
}

/// كمية موقّعة للعرض: إشارة + أرقام غربية بفواصل (صفر منازل للصحيح
/// و٣ للكسري) — داخل LTR دائماً حتى لا تتبدّر في السياق العربي.
String _qtyText(double qty) =>
    qty < 0 ? '−${_qtyPlain(qty)}' : '+${_qtyPlain(qty)}';

/// مقدار صادر للعرض بإشارة السالب (المستودع يعيده موجباً).
String _qtyOut(double magnitude) => '−${_qtyPlain(magnitude)}';

/// تاريخ للعرض `يوم/شهر/سنة` بنظام أرقام السياق (نمط شاشة الأرباح).
String _fmtDate(BuildContext context, DateTime date) {
  final plain = '${date.day}/${date.month}/${date.year}';
  return NumeralsScope.of(context) ? Numerals.toArabicIndic(plain) : plain;
}

/// تاريخ ووقت للعرض `يوم/شهر/سنة ساعة:دقيقة` بنظام أرقام السياق.
String _fmtDateTime(BuildContext context, DateTime date) {
  final plain =
      '${date.day}/${date.month}/${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return NumeralsScope.of(context) ? Numerals.toArabicIndic(plain) : plain;
}
