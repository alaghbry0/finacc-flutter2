/// محور النقدية (تبويب /cash — الشريحة 6): بطاقة بطلة «صافي النقدية»
/// **بسطر مستقل لكل عملة بعملتها** (لا خلط عملات — 5.4-7) + بطاقات
/// الصناديق بأرصدتها الحية (سالب = أحمر بأيقونة تحذير — FR-04-06/09)
/// + شبكة وصول سريع (سندات/مصروف/مسحوبات/تحويل/بنكي/إدارة) + آخر
/// الحركات. الجسم مغلّف بـ RefreshOnActive بنمط `^/cash$` (درس §10).
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
import '../view_models/cash_home_view_model.dart';
import 'quick_movement_sheet.dart';
import 'widgets/cash_widgets.dart';

/// محور النقدية داخل هيكل التبويبات (مسار `/cash`).
class CashHomeScreen extends StatelessWidget {
  const CashHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final CashHomeViewModel vm;
    vm = CashHomeViewModel(cashRepo: app.cash!);
    unawaited(vm.load());
    return ChangeNotifierProvider<CashHomeViewModel>.value(
      value: vm,
      // تحديث حي عند تبديل التبويب/الرجوع: الأرصدة الحية تتغير بترحيل
      // سند أو مصروف من أي شاشة (الفرع يُستعاد من IndexedStack بلا
      // rebuild — درس §10 الملزم لنمط `^/cash$`).
      child: RefreshOnActive(
        routePattern: RegExp(r'^/cash$'),
        onActivate: vm.load,
        child: const _CashHomeBody(),
      ),
    );
  }
}

class _CashHomeBody extends StatelessWidget {
  const _CashHomeBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CashHomeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.cashHomeTitle),
        actions: [
          IconButton(
            tooltip: l10n.cashQuickMovements,
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () => context.go('/cash/movements'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _NetCashHeroCard(),
          const SizedBox(height: 16),
          if (state.loading)
            const ListSkeleton(rows: 5)
          else if (state.error != null)
            ErrorState(
              title: l10n.genericErrorTitle,
              message: l10n.dbOpenErrorMessage,
              technicalDetails: state.error.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: vm.load,
              compact: true,
            )
          else ...[
            const _QuickAccessGrid(),
            const SizedBox(height: 20),
            if (state.boxes.isEmpty)
              EmptyState(
                icon: Icons.account_balance_wallet_rounded,
                title: l10n.cashHomeNoBoxesTitle,
                message: l10n.cashHomeNoBoxesBody,
                actionLabel: l10n.cashHomeManageBoxes,
                onAction: () => context.go('/cash/boxes'),
                compact: true,
              )
            else ...[
              _BoxesSection(boxes: state.boxes),
              const SizedBox(height: 20),
            ],
            if (state.recent.isNotEmpty)
              _RecentMovementsCard(rows: state.recent),
          ],
        ],
      ),
    );
  }
}

/// البطاقة البطلة — صافي النقدية: سطر لكل عملة بعملتها حصراً؛ العملة
/// الأساسية بخط كبير وبقية العملات أسطراً مستقلة (الأمانة المحاسبية).
class _NetCashHeroCard extends StatelessWidget {
  const _NetCashHeroCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CashHomeViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final lines = vm.state.netLines;
    final base = vm.state.baseNetLine;
    final others = lines
        .where((l) => l.currencyId != base?.currencyId)
        .toList(growable: false);
    final now = DateTime.now();

    return FinCard(
      accent: colors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary,
                      Color.lerp(scheme.primary, Colors.black, 0.25)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: scheme.onPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.cashHomeHeroTitle,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cashFormatDate(now)} · ${l10n.cashHomeHeroHint}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: FinText.tabularNums,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (base != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: AmountText(
                    amount: base.amount,
                    size: AmountSize.display,
                    decimals: 2,
                    sign: base.amount < 0 ? FinSign.outgoing : FinSign.neutral,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  base.currencyCode,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.gold,
                    fontWeight: FontWeight.w800,
                    fontFeatures: FinText.tabularNums,
                  ),
                ),
              ],
            ),
          ],
          // بقية العملات — سطر مستقل لكل عملة بعملتها (لا تحويل ولا دمج).
          for (final line in others)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      line.currencyCode,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: FinText.tabularNums,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AmountText(
                      amount: line.amount,
                      size: AmountSize.row,
                      decimals: 2,
                      sign: line.amount < 0
                          ? FinSign.outgoing
                          : FinSign.neutral,
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                l10n.cashHomeEmptyTitle,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// شبكة الوصول السريع — الأفعال اليومية العشرة للوحدة.
class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid();

  /// إصلاح جولة 13: النافذة السريعة لا تغيّر المسار فلا يفعّل
  /// RefreshOnActive — بعد أي ترحيل ناجح أعد تحميل أرصدة المحور فوراً.
  void _openQuickSheet(BuildContext context, QuickMovementKind kind) {
    // خذ الـ VM قبل الفجوة غير المتزامنة (بوابة التحليل).
    final vm = context.read<CashHomeViewModel>();
    unawaited(
      showQuickMovementSheet(context, initialKind: kind).then((posted) {
        if (posted) unawaited(vm.load());
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.94,
      children: [
        CashQuickTile(
          icon: Icons.south_west_rounded,
          label: l10n.cashQuickReceiptVoucher,
          color: colors.positive,
          onTap: () => context.go('/cash/voucher/receipt'),
        ),
        CashQuickTile(
          icon: Icons.north_east_rounded,
          label: l10n.cashQuickPaymentVoucher,
          color: colors.negative,
          onTap: () => context.go('/cash/voucher/payment'),
        ),
        CashQuickTile(
          icon: Icons.receipt_long_rounded,
          label: l10n.cashQuickExpense,
          color: colors.warning,
          onTap: () => _openQuickSheet(context, QuickMovementKind.expense),
        ),
        CashQuickTile(
          icon: Icons.person_remove_rounded,
          label: l10n.cashQuickOwnerDraw,
          color: scheme.tertiary,
          onTap: () => _openQuickSheet(context, QuickMovementKind.ownerDraw),
        ),
        CashQuickTile(
          icon: Icons.person_add_rounded,
          label: l10n.cashQuickCapitalIn,
          color: colors.positive,
          onTap: () => _openQuickSheet(context, QuickMovementKind.capitalIn),
        ),
        CashQuickTile(
          icon: Icons.swap_horiz_rounded,
          label: l10n.cashQuickTransfer,
          color: scheme.primary,
          onTap: () => _openQuickSheet(context, QuickMovementKind.boxTransfer),
        ),
        CashQuickTile(
          icon: Icons.account_balance_rounded,
          label: l10n.cashQuickBank,
          color: colors.gold,
          onTap: () => _openQuickSheet(context, QuickMovementKind.bankDeposit),
        ),
        CashQuickTile(
          icon: Icons.account_balance_wallet_rounded,
          label: l10n.cashQuickBoxes,
          color: colors.neutral,
          onTap: () => context.go('/cash/boxes'),
        ),
        CashQuickTile(
          icon: Icons.history_rounded,
          label: l10n.cashQuickMovements,
          color: colors.neutral,
          onTap: () => context.go('/cash/movements'),
        ),
        CashQuickTile(
          icon: Icons.category_rounded,
          label: l10n.cashQuickCategories,
          color: colors.neutral,
          onTap: () => context.go('/cash/categories'),
        ),
      ],
    );
  }
}

/// قسم الصناديق — ترويسة + بطاقة لكل صندوق (نقرها يفتح سجل حركاتها).
class _BoxesSection extends StatelessWidget {
  const _BoxesSection({required this.boxes});

  final List<CashboxWithBalance> boxes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.cashHomeBoxesSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () => context.go('/cash/boxes'),
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: Text(l10n.cashHomeManageBoxes),
              ),
            ],
          ),
        ),
        for (final box in boxes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HomeBoxCard(box: box),
          ),
      ],
    );
  }
}

/// بطاقة صندوق في المحور — رقاقة «افتراضي» + نقر يفتح حركات الصندوق.
class _HomeBoxCard extends StatelessWidget {
  const _HomeBoxCard({required this.box});

  final CashboxWithBalance box;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return CashBoxCard(
      box: box,
      onTap: () => context.go('/cash/movements?box=${box.box.id}'),
      trailing: box.box.isDefault
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.cashDefaultChip,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
    );
  }
}

/// آخر الحركات — وصول سريع للسجل الكامل.
class _RecentMovementsCard extends StatelessWidget {
  const _RecentMovementsCard({required this.rows});

  final List<CashMovementRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FinCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.cashHomeRecentSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/cash/movements'),
                child: Text(l10n.commonViewAll),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => context.go('/cash/movements'),
                    borderRadius: BorderRadius.circular(10),
                    child: CashMovementTile(
                      movement: rows[i],
                      dimmed: rows[i].isVoided,
                    ),
                  ),
                  if (i != rows.length - 1)
                    const Divider(height: 1, thickness: 0.6),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
