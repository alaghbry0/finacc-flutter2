/// إدارة الصناديق (FR-04-01) — مسار `/cash/boxes`: قائمة بأرصدتها الحية
/// (سالب = تحذير) + تعيين افتراضي + تعديل + **أرشفة بتأكيد** (رصيد ≠ 0
/// يطلب تأكيداً صريحاً أقوى) + قسم المؤرشفة بإلغاء أرشفة. الجسم مغلّف
/// بـ RefreshOnActive بنمط `^/cash/boxes$` (درس §10).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/cash.dart';
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
import '../view_models/boxes_view_model.dart';

/// إدارة الصناديق (التبويب الرابع — فرع /cash).
class BoxesScreen extends StatefulWidget {
  const BoxesScreen({super.key});

  @override
  State<BoxesScreen> createState() => _BoxesScreenState();
}

class _BoxesScreenState extends State<BoxesScreen> {
  BoxesViewModel? _vm;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppController>();
    // النموذج يُنشأ بعد حلّ معرّف المستخدم الإداري (لسجلات التدقيق عند
    // التعيين/الأرشفة) — حتى ذلك الحين هيكل تحميل.
    unawaited(
      app.companies!.findAdminUserId().then((userId) {
        if (!mounted) return;
        final vm = BoxesViewModel(cashRepo: app.cash!, userId: userId);
        setState(() => _vm = vm);
        unawaited(vm.load());
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ChangeNotifierProvider<BoxesViewModel>.value(
      value: vm,
      // تحديث حي عند العودة من نموذج الصندوق أو ترحيل حركة (درس §10).
      child: RefreshOnActive(
        routePattern: RegExp(r'^/cash/boxes$'),
        onActivate: vm.load,
        child: const _BoxesBody(),
      ),
    );
  }
}

class _BoxesBody extends StatelessWidget {
  const _BoxesBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BoxesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/cash')),
        title: Text(l10n.cashBoxesTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/cash/box-form'),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.cashBoxesAddBox),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          if (state.loading)
            const ListSkeleton(rows: 4)
          else if (state.error != null)
            ErrorState(
              title: l10n.genericErrorTitle,
              message: l10n.dbOpenErrorMessage,
              technicalDetails: state.error.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: vm.load,
              compact: true,
            )
          else if (state.boxes.isEmpty && state.archived.isEmpty)
            EmptyState(
              icon: Icons.account_balance_wallet_rounded,
              title: l10n.cashBoxesEmptyTitle,
              message: l10n.cashBoxesEmptyBody,
              actionLabel: l10n.cashBoxesAddBox,
              onAction: () => context.go('/cash/box-form'),
              compact: true,
            )
          else ...[
            for (final box in state.boxes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ActiveBoxCard(box: box),
              ),
            if (state.archived.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  l10n.cashBoxesArchivedSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final box in state.archived)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ArchivedBoxCard(box: box),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// بطاقة صندوق نشط — الرصيد الحي + قائمة إجراءات (افتراضي/تعديل/أرشفة).
class _ActiveBoxCard extends StatelessWidget {
  const _ActiveBoxCard({required this.box});

  final CashboxWithBalance box;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BoxesViewModel>();
    return _BoxCardShell(
      box: box,
      dimmed: false,
      onTap: () => context.go('/cash/movements?box=${box.box.id}'),
      trailing: _BoxMenu(box: box),
      defaultBadge: box.box.isDefault,
      busy: vm.state.busyBoxId == box.box.id,
    );
  }
}

/// بطاقة صندوق مؤرشف — باهتة + إلغاء الأرشفة والتعديل.
class _ArchivedBoxCard extends StatelessWidget {
  const _ArchivedBoxCard({required this.box});

  final CashboxWithBalance box;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BoxesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final busy = vm.state.busyBoxId == box.box.id;
    return _BoxCardShell(
      box: box,
      dimmed: true,
      busy: busy,
      onTap: null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else ...[
            IconButton(
              tooltip: l10n.cashBoxesUnarchiveTooltip,
              icon: const Icon(Icons.unarchive_rounded, size: 20),
              onPressed: () => unawaited(_unarchive(context, vm, box)),
            ),
            IconButton(
              tooltip: l10n.cashBoxesEditTooltip,
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: () => context.go('/cash/box-form/${box.box.id}'),
            ),
          ],
        ],
      ),
      defaultBadge: box.box.isDefault,
    );
  }

  Future<void> _unarchive(
    BuildContext context,
    BoxesViewModel vm,
    CashboxWithBalance box,
  ) async {
    final result = await vm.unarchive(box.box.id);
    if (!context.mounted) return;
    _notifyResult(context, result.isOk, result.errorOrNull);
  }
}

/// هيكل بطاقة الصندوق المشترك (نشطة/مؤرشفة).
class _BoxCardShell extends StatelessWidget {
  const _BoxCardShell({
    required this.box,
    required this.trailing,
    required this.dimmed,
    required this.defaultBadge,
    this.onTap,
    this.busy = false,
  });

  final CashboxWithBalance box;
  final Widget trailing;
  final bool dimmed;
  final bool defaultBadge;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final negative = box.isNegative;
    return Opacity(
      opacity: dimmed ? 0.62 : 1,
      child: FinCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (negative ? colors.negative : scheme.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 22,
                    color: negative ? colors.negative : scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              box.box.name,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (defaultBadge) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                l10n.cashDefaultChip,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: scheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        box.box.currencyCode,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.gold,
                          fontWeight: FontWeight.w800,
                          fontFeatures: FinText.tabularNums,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(
                      amount: box.nativeBalance,
                      size: AmountSize.row,
                      decimals: 2,
                      sign: negative ? FinSign.outgoing : FinSign.neutral,
                    ),
                    if (negative)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 13,
                            color: colors.negative,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.cashNegativeBalance,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.negative,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                trailing,
              ],
            ),
            for (final bucket in box.foreignBuckets)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 54),
                child: Row(
                  children: [
                    Icon(
                      Icons.currency_exchange_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        bucket.currencyCode,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(fontFeatures: FinText.tabularNums),
                      ),
                    ),
                    AmountText(
                      amount: bucket.amount,
                      decimals: 2,
                      sign: bucket.amount < 0
                          ? FinSign.outgoing
                          : FinSign.neutral,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// قائمة إجراءات الصندوق النشط (افتراضي/تعديل/أرشفة).
class _BoxMenu extends StatelessWidget {
  const _BoxMenu({required this.box});

  final CashboxWithBalance box;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BoxesViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final busy = vm.state.busyBoxId == box.box.id;
    if (busy) {
      return const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    }
    return PopupMenuButton<String>(
      tooltip: l10n.commonDetails,
      icon: const Icon(Icons.more_vert_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (action) {
        switch (action) {
          case 'default':
            unawaited(_setDefault(context, vm));
          case 'edit':
            context.go('/cash/box-form/${box.box.id}');
          case 'archive':
            unawaited(_confirmArchive(context, vm));
        }
      },
      itemBuilder: (context) => [
        if (!box.box.isDefault)
          PopupMenuItem(
            value: 'default',
            child: Row(
              children: [
                const Icon(Icons.star_rounded, size: 20),
                const SizedBox(width: 10),
                Text(l10n.cashBoxesSetDefault),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_rounded, size: 20),
              const SizedBox(width: 10),
              Text(l10n.cashBoxesEditTooltip),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'archive',
          child: Row(
            children: [
              const Icon(Icons.archive_rounded, size: 20),
              const SizedBox(width: 10),
              Text(l10n.cashBoxesArchiveTooltip),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _setDefault(BuildContext context, BoxesViewModel vm) async {
    final result = await vm.setDefault(box.box.id);
    if (!context.mounted) return;
    if (result.isOk) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.cashBoxesDefaultDone(box.box.name))),
        );
    } else {
      _notifyResult(context, false, result.errorOrNull);
    }
  }

  /// أرشفة بتأكيد — رصيد ≠ 0 يستلزم تأكيداً صريحاً أقوى (FR-04-01).
  Future<void> _confirmArchive(BuildContext context, BoxesViewModel vm) async {
    final l10n = AppLocalizations.of(context)!;
    final nonZero =
        box.nativeBalance.abs() > 0.005 ||
        box.foreignBuckets.any((b) => b.amount.abs() > 0.005);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          nonZero
              ? l10n.cashBoxesArchiveNonZeroTitle(box.box.name)
              : l10n.cashBoxesArchiveTitle(box.box.name),
        ),
        content: Text(
          nonZero
              ? l10n.cashBoxesArchiveNonZeroBody
              : l10n.cashBoxesArchiveBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: nonZero
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              nonZero ? l10n.cashBoxesArchiveForce : l10n.commonConfirm,
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      final result = await vm.archive(box.box.id);
      if (!context.mounted) return;
      _notifyResult(context, result.isOk, result.errorOrNull);
    }
  }
}

/// إشعار نتيجة عملية (نجاح صامت — القائمة تتحدث؛ الفشل برسالة المستودع).
void _notifyResult(BuildContext context, bool ok, String? error) {
  if (ok) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        content: Text(
          error ?? '',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
        ),
      ),
    );
}
