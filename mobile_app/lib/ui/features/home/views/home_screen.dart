/// لوحة التحكم الرئيسية — FR-09-01 / §6.5:
/// بطاقة ترحيب (اسم المنشأة + التاريخ هجري/ميلادي) + 4 بلاطات (مبيعات
/// اليوم، أرباح اليوم، فواتير اليوم، صافي الصندوق) + رسم 30 يوماً
/// تفاعلي + تنبيهات المخزون — كل عنصر بحالاته (Skeleton/Error/Empty).
///
/// هذه الجولة: حركات دخول متدرجة (fade+slide بتأخيرات متتابعة)، بطاقة
/// ترحيب بزخرفة هندسية خافتة وخط ذهبي فاصل، شارة «آخر تحديث»، وبلاطات
/// بحلقة أيقونة متدرجة.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../domain/services/hijri_date.dart';
import '../../../../domain/services/numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/mini_sales_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../../../core/widgets/stat_tile.dart';
import '../view_models/home_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final vm = DashboardViewModel(
      repository: app.dashboard!,
      companyRepository: app.companies,
    );
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
              _StaggeredEntrance(
                index: 0,
                child: _WelcomeCard(
                  companyName: vm.companyName ?? l10n.appTitle,
                  hijriText: _hijriText(NumeralsScope.of(context)),
                  gregorianText: _gregorianText(NumeralsScope.of(context)),
                ),
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
                _StaggeredEntrance(
                  index: 1,
                  child: GridView.count(
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
                ),
              const SizedBox(height: 18),
              _StaggeredEntrance(
                index: 2,
                child: FinCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SectionHeader(title: l10n.last30DaysTitle),
                          ),
                          if (state.lastUpdated != null)
                            _LastUpdatedChip(at: state.lastUpdated!),
                        ],
                      ),
                      if (state.loading)
                        const ChartSkeleton()
                      else
                        MiniSalesChart(
                          points: state.series,
                          currency: vm.currencyCode,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _StaggeredEntrance(
                index: 3,
                child: FinCard(
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
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: scheme.onErrorContainer,
                              size: 22,
                            ),
                          ),
                          title: Text(l10n.stockAlertsCount(state.lowStock)),
                          trailing: const Icon(Icons.chevron_left_rounded),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _hijriText(bool arabicIndic) {
    final hijri = HijriCalendar.today().toString();
    // الهجري يُخرَج بأرقام غربية — يُحوَّل للشرقية عند تفعيل النظام العربي.
    return arabicIndic ? Numerals.toArabicIndic(hijri) : hijri;
  }

  static String _gregorianText(bool arabicIndic) {
    // الميلادي بـ intl العربي يخرج بأرقام شرقية — يُوحَّد مع النظام المختار.
    final text = DateFormat('EEEE، d MMMM y', 'ar').format(DateTime.now());
    return arabicIndic ? text : Numerals.toWestern(text);
  }
}

/// دخول متدرج: انزلاق رأسي خفيف + تلاشٍ بتأخير index*90ms.
class _StaggeredEntrance extends StatelessWidget {
  const _StaggeredEntrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - Curves.easeOutCubic.transform(t))),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// شارة «آخر تحديث HH:mm» بأرقام جدولية.
class _LastUpdatedChip extends StatelessWidget {
  const _LastUpdatedChip({required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 12,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            DateFormat('HH:mm').format(at),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة الترحيب — اسم المنشأة + التاريخ هجري/ميلادي (§6.5) بزخرفة
/// هندسية مالية خافتة وخط ذهبي فاصل وحلقة متدرجة حول أيقونة المتجر.
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
    final colors = FinColors.of(context);
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
      foregroundDecoration: _PatternOverlay(color: colors.gold),
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
              // حلقة متدرجة حول أيقونة المتجر (لمسة فاخرة).
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.gold.withValues(alpha: 0.9),
                      scheme.onPrimary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(2.4),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(scheme.primary, Colors.black, 0.22),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: scheme.onPrimary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // خط ذهبي فاصل رفيع قبل شريط التاريخ.
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  colors.gold.withValues(alpha: 0.75),
                  colors.gold.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // شريط التاريخ — قابل للنقر يفتح لوحة تفاصيل التقويمين.
          Material(
            color: scheme.onPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => _showDateDetails(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: scheme.onPrimary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$hijriText  •  $gregorianText',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.expand_less_rounded,
                      size: 14,
                      color: scheme.onPrimary.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// يفتح لوحة تفاصيل التاريخ — التقويمان هجري/ميلادي بيوم الأسبوع.
Future<void> _showDateDetails(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (context) => const _DateDetailSheet(),
  );
}

/// لوحة تفاصيل التاريخ: هجري كبير + ميلادي + يوم الأسبوع بنظام الأرقام الحي.
class _DateDetailSheet extends StatelessWidget {
  const _DateDetailSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final arabicIndic = NumeralsScope.of(context);
    final now = DateTime.now();
    final hijri = HijriCalendar.today();
    final hijriText = hijri.toString();
    final weekday = DateFormat('EEEE', 'ar').format(now);
    final gregorian = DateFormat('d MMMM y', 'ar').format(now);
    String num(String t) => arabicIndic ? Numerals.toArabicIndic(t) : t;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.dateSheetTitle,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.gold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    l10n.dateSheetTodayBadge,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // البطاقة الهجرية — البطاقة البطلة بلون دلالي إيجابي.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    scheme.primary,
                    Color.lerp(scheme.primary, Colors.black, 0.3)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.nightlight_round,
                        color: colors.gold,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.dateSheetHijriLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimary.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    num(hijriText),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // البطاقة الميلادية + يوم الأسبوع.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.wb_sunny_rounded,
                              color: colors.warning,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              l10n.dateSheetGregorianLabel,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          num(gregorian),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.today_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          weekday,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
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

/// زخرفة هندسية خافتة فوق البطاقة: دوائر عملة وخطوط دقيقة بزوايا
/// إسلامية هندسية — تُرسم مرة واحدة (CustomPainter) بشفافية منخفضة.
class _PatternOverlay extends Decoration {
  const _PatternOverlay({required this.color});

  final Color color;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _PatternPainter(color: color);
  }
}

class _PatternPainter extends BoxPainter {
  _PatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    canvas.save();
    try {
      // قصّ داخل البطاقة حتى لا تتجاوز الزخرفة حوافها المستديرة.
      canvas.clipRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.16);

      // دوائر متراكزة ركنية (يمين أعلى — اتجاه البداية في RTL).
      final c = Offset(rect.right - 26, rect.top + 30);
      for (final r in [46.0, 34.0, 22.0]) {
        canvas.drawCircle(c, r, paint);
      }
      // خطوط قطرية دقيقة أسفل يسار.
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.10);
      for (var i = 0; i < 4; i++) {
        final x = rect.left + 18.0 + i * 14;
        canvas.drawLine(
          Offset(x, rect.bottom),
          Offset(x + 26, rect.bottom - 26),
          p,
        );
      }
      // نقاط عملة صغيرة على قوس.
      final dots = Paint()..color = color.withValues(alpha: 0.22);
      for (var i = 0; i < 5; i++) {
        final angle = -1.2 + i * 0.3;
        canvas.drawCircle(
          Offset(c.dx + 58 * math.cos(angle), c.dy + 58 * math.sin(angle)),
          1.6,
          dots,
        );
      }
    } finally {
      canvas.restore();
    }
  }
}
