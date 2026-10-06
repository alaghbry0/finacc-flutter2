/// لوحة التحكم الرئيسية — FR-09-01 / §6.5:
/// بطاقة ترحيب (اسم المنشأة + التاريخ هجري/ميلادي) + 4 بلاطات (مبيعات
/// اليوم، أرباح اليوم، فواتير اليوم، صافي الصندوق) + رسم 30 يوماً +
/// تنبيهات المخزون — كل عنصر بحالاته (Skeleton/Error/Empty).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../domain/services/hijri_date.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/mini_sales_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stat_tile.dart';
import '../view_models/home_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final vm = DashboardViewModel(repository: app.dashboard!);
    unawaited(vm.load(companyName: app.company?.name));
    return ChangeNotifierProvider<DashboardViewModel>.value(
      value: vm,
      child: const _DashboardBody(),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => vm.load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              _WelcomeCard(
                companyName: vm.companyName ?? l10n.appTitle,
                hijriText: _hijriText(),
                gregorianText: _gregorianText(),
              ),
              const SizedBox(height: 18),
              if (state.loading)
                const StatTilesSkeleton()
              else if (state.error != null)
                ErrorState(
                  title: l10n.genericErrorTitle,
                  message: l10n.dbOpenErrorMessage,
                  technicalDetails: state.error.toString(),
                  retryLabel: l10n.commonRetry,
                  onRetry: () => vm.load(),
                  compact: true,
                )
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    StatTile(
                      label: l10n.todaySales,
                      value: state.stats.sales,
                      icon: Icons.trending_up_rounded,
                      sign: FinSign.incoming,
                    ),
                    StatTile(
                      label: l10n.todayProfit,
                      value: state.stats.profit,
                      icon: Icons.savings_rounded,
                      sign: FinSign.incoming,
                    ),
                    StatTile(
                      label: l10n.todayInvoices,
                      value: state.stats.invoiceCount.toDouble(),
                      icon: Icons.receipt_long_rounded,
                      isCount: true,
                    ),
                    StatTile(
                      label: l10n.netCash,
                      value: state.stats.netCash,
                      icon: Icons.account_balance_wallet_rounded,
                      sign: state.stats.netCash >= 0
                          ? FinSign.incoming
                          : FinSign.outgoing,
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              FinCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(title: l10n.last30DaysTitle),
                    if (state.loading)
                      const ChartSkeleton()
                    else
                      MiniSalesChart(points: state.series),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FinCard(
                child: Column(
                  children: [
                    SectionHeader(title: l10n.stockAlertsTitle),
                    if (state.loading)
                      const ListSkeleton(rows: 2)
                    else if (state.lowStock == 0)
                      EmptyState(
                        icon: Icons.inventory_2_rounded,
                        title: l10n.stockAlertsEmpty,
                        message: l10n.stockAlertsCount(0),
                        compact: true,
                      )
                    else
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.warning_amber_rounded,
                          color: scheme.error,
                        ),
                        title: Text(l10n.stockAlertsCount(state.lowStock)),
                        trailing: const Icon(Icons.chevron_left_rounded),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _hijriText() {
    final hijri = HijriCalendar.today();
    return hijri.toString();
  }

  static String _gregorianText() {
    return DateFormat('EEEE، d MMMM y', 'ar').format(DateTime.now());
  }
}

/// بطاقة الترحيب — اسم المنشأة + التاريخ هجري/ميلادي (§6.5).
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.companyName,
    required this.hijriText,
    required this.gregorianText,
  });

  final String companyName;
  final String hijriText;
  final String gregorianText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? l10n.morningGreeting : l10n.eveningGreeting;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.32)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      companyName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: scheme.onPrimary,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.onPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$hijriText  •  $gregorianText',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
