/// قائمة عروض الأسعار — رقائق تصفية الحالة (الكل/مسودة/مرسل/محوّل/ملغى)
/// وبطاقات برقم العرض وتاريخه وعميله وصافيه، وأزرار سريعة (تعليم مرسل،
/// إلغاء) وفتح التفاصيل للتحويل إلى فاتورة.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/quotation.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/quotations_view_model.dart';
import 'widgets/sell_widgets.dart';

/// قائمة عروض الأسعار (مسار مقترح `/sell/quotations`).
class QuotationsScreen extends StatelessWidget {
  const QuotationsScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً.
  final QuotationsViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final QuotationsViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = QuotationsViewModel(quotationRepo: app.quotations!);
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<QuotationsViewModel>.value(
      value: vm,
      // تحديث حي عند تبديل التبويب/الرجوع — تحويل عرض لفاتورة يغيّر الحالة
      // والقائمة تُستعاد من IndexedStack بلا rebuild.
      child: RefreshOnActive(
        routePattern: RegExp(r'^/sell/quotations$'),
        onActivate: vm.load,
        child: const _QuotationsBody(),
      ),
    );
  }
}

class _QuotationsBody extends StatelessWidget {
  const _QuotationsBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<QuotationsViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/sell')),
        title: Text(l10n.sellQuotationsTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _StatusFilterBar(
              selected: state.statusFilter,
              onSelect: vm.setStatusFilter,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildContent(context, vm)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, QuotationsViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    if (state.loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: const [ListSkeleton(rows: 6)],
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
    if (state.quotations.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          EmptyState(
            icon: Icons.request_quote_rounded,
            title: l10n.sellQuotationsEmptyTitle,
            message: l10n.sellQuotationsEmptyBody,
            actionLabel: l10n.sellHomeNewInvoice,
            onAction: () => context.go('/sell/new'),
            compact: true,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        for (final quotation in state.quotations)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _QuotationCard(
              quotation: quotation,
              busy: state.busyQuotationId == quotation.id,
            ),
          ),
      ],
    );
  }
}

/// شريط رقائق تصفية الحالة.
class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onSelect});

  final QuotationStatus? selected;
  final ValueChanged<QuotationStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String label, QuotationStatus? value) {
      final isSelected = selected == value;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Material(
          color: isSelected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? scheme.primary.withValues(alpha: 0.55)
                  : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: InkWell(
            onTap: () => onSelect(value),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: isSelected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          chip(l10n.sellQuotationFilterAll, null),
          chip(l10n.sellQuotationStatusDraft, QuotationStatus.draft),
          chip(l10n.sellQuotationStatusSent, QuotationStatus.sent),
          chip(l10n.sellQuotationStatusConverted, QuotationStatus.converted),
          chip(l10n.sellQuotationStatusCancelled, QuotationStatus.rejected),
        ],
      ),
    );
  }
}

/// تسمية حالة العرض برقاقة دلالية.
class QuotationStatusChip extends StatelessWidget {
  const QuotationStatusChip({super.key, required this.status});

  final QuotationStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, tone, icon) = switch (status) {
      QuotationStatus.draft => (
        l10n.sellQuotationStatusDraft,
        ChipTone.neutral,
        Icons.edit_note_rounded,
      ),
      QuotationStatus.sent => (
        l10n.sellQuotationStatusSent,
        ChipTone.brand,
        Icons.send_rounded,
      ),
      QuotationStatus.converted => (
        l10n.sellQuotationStatusConverted,
        ChipTone.positive,
        Icons.check_circle_rounded,
      ),
      QuotationStatus.expired => (
        l10n.sellQuotationStatusExpired,
        ChipTone.warning,
        Icons.history_toggle_off_rounded,
      ),
      QuotationStatus.rejected => (
        l10n.sellQuotationStatusCancelled,
        ChipTone.negative,
        Icons.cancel_rounded,
      ),
    };
    return StatusChip(label: label, tone: tone, icon: icon, dense: true);
  }
}

/// بطاقة عرض سعر واحدة.
class _QuotationCard extends StatelessWidget {
  const _QuotationCard({required this.quotation, required this.busy});

  final QuotationSummary quotation;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<QuotationsViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final local = quotation.issuedAt.toLocal();

    return FinCard(
      onTap: () => context.go('/sell/quotations/${quotation.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  quotation.quotationNo,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ),
              QuotationStatusChip(status: quotation.status),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  quotation.customerName ?? l10n.sellCashCustomer,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                sellFormatDate(local),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: FinText.tabularNums,
                ),
              ),
            ],
          ),
          if (quotation.validUntil != null) ...[
            const SizedBox(height: 2),
            Text(
              l10n.sellQuotationValidUntil(
                sellFormatDate(quotation.validUntil!.toLocal()),
              ),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: colors.warning),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (quotation.status.convertible) ...[
                _QuickAction(
                  icon: Icons.send_rounded,
                  label: l10n.sellQuotationMarkSent,
                  visible: quotation.status == QuotationStatus.draft,
                  busy: busy,
                  onTap: () async {
                    final app = context.read<AppController>();
                    final result = await vm.markSent(
                      quotation.id,
                      userId: (await app.companies!.findAdminUserId()) ?? 1,
                    );
                    if (!context.mounted) return;
                    final failure = result.errorOrNull;
                    if (failure != null) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text(failure)));
                    }
                  },
                ),
                const Spacer(),
                _QuickAction(
                  icon: Icons.cancel_outlined,
                  label: l10n.sellQuotationCancel,
                  color: colors.negative,
                  visible: true,
                  busy: busy,
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text(l10n.sellQuotationCancelConfirmTitle),
                        content: Text(
                          l10n.sellQuotationCancelConfirmBody(
                            quotation.quotationNo,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: Text(l10n.commonCancel),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: Text(l10n.commonConfirm),
                          ),
                        ],
                      ),
                    );
                    if (!context.mounted) return;
                    if (confirmed ?? false) {
                      final app = context.read<AppController>();
                      final result = await vm.cancel(
                        quotation.id,
                        userId: (await app.companies!.findAdminUserId()) ?? 1,
                      );
                      if (!context.mounted) return;
                      final failure = result.errorOrNull;
                      if (failure != null) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(failure)));
                      }
                    }
                  },
                ),
              ] else ...[
                const Spacer(),
                if (quotation.convertedInvoiceId != null)
                  Text(
                    l10n.sellQuotationConvertedTo(
                      '${quotation.convertedInvoiceId}',
                    ),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.positive,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
              const SizedBox(width: 12),
              Row(
                children: [
                  AmountText(
                    amount: quotation.total,
                    decimals:
                        quotation.total == quotation.total.truncateToDouble()
                        ? 0
                        : 2,
                  ),
                  if (quotation.currencyCode != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      quotation.currencyCode!,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: colors.gold),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.visible,
    required this.busy,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final bool visible;
  final bool busy;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final effective = color ?? scheme.primary;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: effective.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 15, color: effective),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: effective, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
