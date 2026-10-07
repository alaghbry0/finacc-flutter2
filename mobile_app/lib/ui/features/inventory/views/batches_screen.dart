/// شاشة «الدفعات وتواريخ الصلاحية» (FR-09-15): رقائق سلالم العدّادات
/// (منتهية / ≤30 / ≤60 / ≤90) وقائمة الدفعات باسم الصنف ورقم الدفعة
/// الأحادي وتاريخ الانتهاء ورقاقة الأيام الملونة والكمية.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/batch.dart';
import '../../../../domain/services/numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../view_models/batches_view_model.dart';
import 'widgets/inventory_widgets.dart';

class BatchesScreen extends StatelessWidget {
  const BatchesScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final BatchesViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final BatchesViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = BatchesViewModel(batchRepo: app.batches!);
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<BatchesViewModel>.value(
      value: vm,
      child: const _BatchesBody(),
    );
  }
}

class _BatchesBody extends StatelessWidget {
  const _BatchesBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BatchesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.batchesTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _BucketFilterBar(
              buckets: state.buckets,
              selected: state.selected,
              onSelect: vm.setBucket,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: [
                Text(
                  l10n.batchesResultCount(state.visible.length),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildContent(context, vm)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, BatchesViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    if (state.loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: const [ListSkeleton(rows: 5)],
      );
    }
    if (state.error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
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
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          EmptyState(
            icon: Icons.event_busy_rounded,
            title: l10n.batchesEmptyTitle,
            message: l10n.batchesEmptyBody,
            compact: true,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        for (final alert in state.visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BatchCard(alert: alert),
          ),
      ],
    );
  }
}

/// شريط رقائق السلالم — عدّادات حية بأرقام جدولية.
class _BucketFilterBar extends StatelessWidget {
  const _BucketFilterBar({
    required this.buckets,
    required this.selected,
    required this.onSelect,
  });

  final Map<String, int> buckets;
  final ExpiryBucket selected;
  final ValueChanged<ExpiryBucket> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final total =
        (buckets['expired'] ?? 0) +
        (buckets['30'] ?? 0) +
        (buckets['60'] ?? 0) +
        (buckets['90'] ?? 0);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _BucketChip(
            label: l10n.batchesFilterAll,
            count: total,
            selected: selected == ExpiryBucket.all,
            color: Theme.of(context).colorScheme.primary,
            onTap: () => onSelect(ExpiryBucket.all),
          ),
          const SizedBox(width: 8),
          _BucketChip(
            label: l10n.batchesBucketExpired,
            count: buckets['expired'] ?? 0,
            selected: selected == ExpiryBucket.expired,
            color: colors.negative,
            onTap: () => onSelect(ExpiryBucket.expired),
          ),
          const SizedBox(width: 8),
          _BucketChip(
            label: l10n.batchesBucket30,
            count: buckets['30'] ?? 0,
            selected: selected == ExpiryBucket.d30,
            color: colors.negative,
            onTap: () => onSelect(ExpiryBucket.d30),
          ),
          const SizedBox(width: 8),
          _BucketChip(
            label: l10n.batchesBucket60,
            count: buckets['60'] ?? 0,
            selected: selected == ExpiryBucket.d60,
            color: colors.warning,
            onTap: () => onSelect(ExpiryBucket.d60),
          ),
          const SizedBox(width: 8),
          _BucketChip(
            label: l10n.batchesBucket90,
            count: buckets['90'] ?? 0,
            selected: selected == ExpiryBucket.d90,
            color: colors.positive,
            onTap: () => onSelect(ExpiryBucket.d90),
          ),
        ],
      ),
    );
  }
}

/// رقاقة سلم واحدة بعدّاد.
class _BucketChip extends StatelessWidget {
  const _BucketChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.14)
            : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide(color: color.withValues(alpha: 0.55), width: 1.4)
              : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? color : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.18)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? color : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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

/// بطاقة دفعة واحدة — اسم الصنف ورقم الدفعة والانتهاء والأيام والكمية.
class _BatchCard extends StatelessWidget {
  const _BatchCard({required this.alert});

  final BatchExpiryAlert alert;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final arabicIndic = NumeralsScope.of(context);
    final expiry = DateFormat('yyyy/MM/dd').format(alert.expiryDate);
    final expiryText = arabicIndic ? Numerals.toArabicIndic(expiry) : expiry;

    return FinCard(
      onTap: () => context.go('/inventory/item/${alert.productId}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  (alert.isExpired
                          ? FinColors.of(context).negative
                          : FinColors.of(context).warning)
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              alert.isExpired
                  ? Icons.block_rounded
                  : Icons.hourglass_bottom_rounded,
              size: 21,
              color: alert.isExpired
                  ? FinColors.of(context).negative
                  : FinColors.of(context).warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.productName,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                MonoText(
                  alert.batchNumber,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.batchesExpiryLabel}: $expiryText',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                ExpiryDaysChip(days: alert.daysToExpiry),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // الكمية — أرقام جدولية (AmountText نفس كومة النمط).
              Text(
                _qtyText(context, alert.qty),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                l10n.batchesQtyLabel,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _qtyText(BuildContext context, double qty) {
    final pattern = qty == qty.truncateToDouble() ? '#,##0' : '#,##0.00';
    final formatted = NumberFormat(pattern, 'en_US').format(qty);
    return NumeralsScope.of(context)
        ? Numerals.toArabicIndic(formatted)
        : formatted;
  }
}
