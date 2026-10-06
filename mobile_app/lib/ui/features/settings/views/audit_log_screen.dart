/// شاشة سجل التدقيق — FR-12-04 (الجانب العرضي):
/// أحداث أمنية موسّعة للقراءة فقط، مجمّعة باليوم (اليوم/أمس/تاريخ هجري
/// وميلادي)، لكل حدث أيقونة تصنيفية ولون دلالي واسم المنفّذ والوقوت —
/// مع بطاقة توضيح «للإضافة فقط» (Triggers داخل ملف القاعدة) وترقيم
/// صفحات بزر «المزيد».
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/audit_event.dart';
import '../../../../domain/services/hijri_date.dart';
import '../../../../domain/services/numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../view_models/audit_log_view_model.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final AuditLogViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final AuditLogViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = AuditLogViewModel(repository: app.audit!);
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<AuditLogViewModel>.value(
      value: vm,
      child: const _AuditLogBody(),
    );
  }
}

class _AuditLogBody extends StatelessWidget {
  const _AuditLogBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuditLogViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.auditTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _AppendOnlyCard(),
          const SizedBox(height: 16),
          if (state.loading)
            const ListSkeleton(rows: 6)
          else if (state.error != null)
            ErrorState(
              title: l10n.genericErrorTitle,
              message: l10n.dbOpenErrorMessage,
              technicalDetails: state.error.toString(),
              retryLabel: l10n.commonRetry,
              onRetry: vm.load,
              compact: true,
            )
          else if (state.events.isEmpty)
            _AuditEmptyState(eventCount: state.totalCount)
          else ...[
            _Timeline(events: state.events),
            if (state.hasMore) ...[
              const SizedBox(height: 14),
              _LoadMoreButton(
                loading: vm.loadingMore,
                shown: state.events.length,
                total: state.totalCount,
                onLoadMore: vm.loadMore,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// بطاقة «للإضافة فقط» — شرح حماية FR-12-04 داخل ملف القاعدة.
class _AppendOnlyCard extends StatelessWidget {
  const _AppendOnlyCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return FinCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.gold,
                  Color.lerp(colors.gold, Colors.black, 0.3)!,
                ],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: scheme.surface,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.auditProtectedTitle,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.warningContainer,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        l10n.auditAppendOnlyBadge,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onWarningContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.auditProtectedBody,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// حالة السجل الفارغ (قبل أول حدث أمني).
class _AuditEmptyState extends StatelessWidget {
  const _AuditEmptyState({required this.eventCount});

  final int eventCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FinCard(
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 44,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.auditEmptyTitle,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.auditEmptyBody,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// الخط الزمني: رؤوس أيام + أحداث بخط عمودي واصل.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<AuditEvent> events;

  @override
  Widget build(BuildContext context) {
    final arabicIndic = NumeralsScope.of(context);
    // تجميع باليوم المحلي مع الحفاظ على الترتيب.
    final groups = <String, List<AuditEvent>>{};
    for (final e in events) {
      groups.putIfAbsent(_dayKey(e.atLocal), () => []).add(e);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          _DayHeader(dayKey: entry.key, arabicIndic: arabicIndic),
          for (final event in entry.value)
            _TimelineEvent(event: event, arabicIndic: arabicIndic),
        ],
      ],
    );
  }

  static String _dayKey(DateTime local) =>
      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

/// رأس اليوم: «اليوم/أمس» أو التاريخ هجري + ميلادي.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.dayKey, required this.arabicIndic});

  final String dayKey;
  final bool arabicIndic;

  (String, String) _labels(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parts = dayKey.split('-');
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;
    final hijri = HijriCalendar.fromDateTime(date).toString();
    final gregorian = DateFormat('d MMMM y', 'ar').format(date);
    final hijriText = arabicIndic ? Numerals.toArabicIndic(hijri) : hijri;
    final gregorianText = arabicIndic
        ? gregorian
        : Numerals.toWestern(gregorian);
    final prefix = switch (diff) {
      0 => l10n.auditDayToday,
      1 => l10n.auditDayYesterday,
      _ => '',
    };
    return (prefix, '$hijriText  •  $gregorianText');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final (prefix, dateText) = _labels(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          if (prefix.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    Color.lerp(scheme.primary, Colors.black, 0.2)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                prefix,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              dateText,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: colors.gold, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// حدث واحد على الخط الزمني.
class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({required this.event, required this.arabicIndic});

  final AuditEvent event;
  final bool arabicIndic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final time = DateFormat('HH:mm').format(event.atLocal);
    final timeText = arabicIndic ? Numerals.toArabicIndic(time) : time;

    final (icon, iconColor, container) = switch (event.category) {
      AuditCategory.setup => (
        Icons.rocket_launch_rounded,
        scheme.primary,
        scheme.primaryContainer,
      ),
      AuditCategory.security => (
        Icons.gpp_maybe_rounded,
        colors.negative,
        colors.negativeContainer,
      ),
      AuditCategory.settings => (
        Icons.tune_rounded,
        colors.warning,
        colors.warningContainer,
      ),
      AuditCategory.other => (
        Icons.event_note_rounded,
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHigh,
      ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // عمود الخط الزمني: نقطة + خيط واصل.
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor,
                    border: Border.all(color: scheme.surface, width: 2.5),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FinCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: container,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 18, color: iconColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _actionLabel(l10n, event.action),
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        timeText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (event.userName != null || event.details != null) ...[
                    const SizedBox(height: 8),
                    if (event.userName != null)
                      Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event.userName!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    if (event.details != null) ...[
                      if (event.userName != null) const SizedBox(height: 2),
                      Text(
                        event.details!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _actionLabel(AppLocalizations l10n, String action) =>
      switch (action) {
        'app_setup' => l10n.auditActionAppSetup,
        'pin_change' => l10n.auditActionPinChange,
        'pin_lockout_delay' => l10n.auditActionLockoutDelay,
        'pin_lockout_passphrase' => l10n.auditActionLockoutPassphrase,
        'settings_change' => l10n.auditActionSettingsChange,
        _ => l10n.auditActionUnknown(action),
      };
}

/// زر «المزيد» مع عدّاد المعروض من الإجمالي.
class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({
    required this.loading,
    required this.shown,
    required this.total,
    required this.onLoadMore,
  });

  final bool loading;
  final int shown;
  final int total;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final arabicIndic = NumeralsScope.of(context);
    String digits(int n) => arabicIndic ? Numerals.toArabicIndic('$n') : '$n';
    return OutlinedButton.icon(
      onPressed: loading ? null : onLoadMore,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.expand_more_rounded),
      label: Text(
        l10n.auditLoadMore(digits(shown), digits(total)),
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}
