/// شاشة «أعمار الديون» (FR-09-05 — الشريحة 9): أرصدة العملاء مصنّفة
/// (٠–٣٠ / ٣١–٦٠ / ٦١–٩٠ / +٩٠) على أساس FIFO بعملة واحدة، مع بطاقة
/// ملخص ملوّنة تدرّجياً، شريط دلاء مصغّر لكل عميل، توسيع لتفاصيل
/// الفواتير المفتوحة، وتذكير واتساب (wa.me) لكل مدين.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/debt_aging_repository.dart';
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
import '../../../core/widgets/refresh_on_return.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/aging_view_model.dart';

/// شاشة تقرير أعمار الديون — `/reports/aging`.
class AgingReportScreen extends StatelessWidget {
  const AgingReportScreen({super.key, this.viewModel, this.origin});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final AgingViewModel? viewModel;

  /// مسار الأصل الذي دخل منه المستخدم التقرير (A6/R17-b — نمط
  /// PurchasesOriginTracker)؛ null = مجهول فيرجع الجسم إلى مركز
  /// التقارير (جذر وحدة التقرير — قاعدة الدليل البصري للرجوع).
  final String? origin;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final AgingViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = AgingViewModel(
        debtRepo: DebtAgingRepository(app.database!.db),
        companyRepo: app.companies!,
        company: app.company,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<AgingViewModel>.value(
      value: vm,
      // إعادة التحميل عند العودة من مسار فرعي (سداد من تفاصيل الطرف…).
      child: RefreshOnReturn(onReappear: vm.refresh, child: _AgingBody(origin: origin)),
    );
  }
}

class _AgingBody extends StatefulWidget {
  const _AgingBody({this.origin});

  /// مسار الأصل الذي دخل منه المستخدم — يرجع إليه زر الرجوع.
  final String? origin;

  @override
  State<_AgingBody> createState() => _AgingBodyState();
}

class _AgingBodyState extends State<_AgingBody> {
  /// العملاء الموسّعون (تفاصيل الفواتير ظاهرة).
  final Set<int> _expanded = <int>{};

  void _toggle(int customerId) {
    setState(() {
      if (!_expanded.add(customerId)) {
        _expanded.remove(customerId);
      }
    });
  }

  /// تذكير واتساب — رسالة معربة ثم wa.me، وتنبيه ودود عند غياب الرقم.
  Future<void> _remind(AgingViewModel vm, AgingCustomerRow row) async {
    final l10n = AppLocalizations.of(context)!;
    final message = vm.reminderMessage(l10n, row);
    final outcome = await vm.remind(row, message);
    if (!mounted) return;
    switch (outcome) {
      case AgingRemindOutcome.noNumber:
        _toast(l10n.agingNoPhone);
      case AgingRemindOutcome.failed:
        _toast(l10n.agingWhatsAppFailed);
      case AgingRemindOutcome.opened:
        break; // فُتح واتساب — لا حاجة لرسالة.
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AgingViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final report = state.report;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.agingTitle),
            if (report != null)
              Text(
                l10n.agingAsOfLabel(_formatDate(context, report.asOf)),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        // مسار علوي خارج الهيكل — رجوع صريح إلى أصل الدخول (A6/R17-b:
        // مركز التقارير أو محور الأطراف حسب المدخل؛ المجهول → المركز
        // جذر وحدة التقرير) بدل التصلّب على محور واحد.
        leading: BackButton(
          onPressed: () => context.go(widget.origin ?? '/reports'),
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
              if (state.currencies.isNotEmpty) ...[
                _CurrencySelector(state: state),
                const SizedBox(height: 14),
              ],
              ..._buildContent(context, vm),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context, AgingViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;
    final report = state.report;

    if (state.loading && report == null) {
      return const [ListSkeleton(rows: 6)];
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
      // لا عملات نشطة أصلاً — حالة نادرة جداً (البذر يضمن الأساس).
      return const [ListSkeleton(rows: 4)];
    }
    if (report.rows.isEmpty) {
      return [
        EmptyState(
          icon: Icons.celebration_rounded,
          title: l10n.agingNoDebtsTitle,
          message: l10n.agingNoDebtsBody,
          compact: true,
        ),
      ];
    }
    return [
      // تحديث فشل مع بقاء بيانات قديمة — تنبيه رقيق لا يحجب المحتوى.
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
                  l10n.agingStaleWarning,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      _SummaryCard(report: report, decimals: state.decimals),
      const SizedBox(height: 14),
      for (final row in report.rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CustomerCard(
            key: Key('aging_row_${report.currencyId}_${row.customerId}'),
            row: row,
            currencyCode: report.currencyCode,
            decimals: state.decimals,
            expanded: _expanded.contains(row.customerId),
            onToggle: () => _toggle(row.customerId),
            onRemind: () => unawaited(_remind(vm, row)),
          ),
        ),
      _FooterCard(report: report, decimals: state.decimals),
    ];
  }
}

/// منتقي العملة — قائمة منبثقة (الأساس أولاً، بلا حالة داخلية).
class _CurrencySelector extends StatelessWidget {
  const _CurrencySelector({required this.state});

  final AgingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final selected = state.currencies
        .where((currency) => currency.id == state.currencyId)
        .firstOrNull;
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.currency_exchange_rounded,
            size: 22,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.agingCurrencyLabel,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          PopupMenuButton<int>(
            initialValue: state.currencyId,
            tooltip: l10n.agingCurrencyLabel,
            onSelected: (currencyId) => unawaited(
              context.read<AgingViewModel>().setCurrency(currencyId),
            ),
            itemBuilder: (context) => [
              for (final currency in state.currencies)
                PopupMenuItem<int>(
                  value: currency.id,
                  child: Text(
                    '${currency.name} (${currency.code})'
                    '${currency.isBase ? ' ★' : ''}',
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    (selected?.code ?? '—'),
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة الملخص — شريحة «حتى تاريخ» + عدد المدينين، أربع بلاطات دلاء
/// بتدرّج أخضر ← أحمر، والإجمالي العام، ومعه الجزء غير المستحق بعد.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report, required this.decimals});

  final AgingReport report;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final buckets = <double>[
      report.total0to30,
      report.total31to60,
      report.total61to90,
      report.total90Plus,
    ];

    return FinCard(
      accent: colors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_rounded, size: 15, color: colors.gold),
              const SizedBox(width: 5),
              // Expanded يمنع فيض الصف على الشاشات الضيقة (٣٩٠) مع شريحة
              // عدد المدينين المجاورة.
              Expanded(
                child: Text(
                  l10n.agingAsOfLabel(_formatDate(context, report.asOf)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: l10n.agingCustomersCount(report.customersCount),
                tone: ChipTone.neutral,
                icon: Icons.groups_rounded,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BucketTile(
                  label: l10n.agingBucket0to30,
                  amount: buckets[0],
                  color: _bucketColor(context, 0),
                  decimals: decimals,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BucketTile(
                  label: l10n.agingBucket31to60,
                  amount: buckets[1],
                  color: _bucketColor(context, 1),
                  decimals: decimals,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BucketTile(
                  label: l10n.agingBucket61to90,
                  amount: buckets[2],
                  color: _bucketColor(context, 2),
                  decimals: decimals,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BucketTile(
                  label: l10n.agingBucket90plus,
                  amount: buckets[3],
                  color: _bucketColor(context, 3),
                  decimals: decimals,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.agingTotalLabel,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              AmountText(
                amount: report.grandTotal,
                decimals: decimals,
                size: AmountSize.large,
              ),
              const SizedBox(width: 8),
              _CurrencyPill(code: report.currencyCode, accent: colors.gold),
            ],
          ),
          if (report.currentNotDue > 0) ...[
            const SizedBox(height: 8),
            StatusChip(
              label:
                  '${l10n.agingNotYetDueLabel} '
                  '${AmountText.formatFor(context, report.currentNotDue, decimals)}',
              tone: ChipTone.positive,
              icon: Icons.schedule_rounded,
              dense: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// بلاطة دلو واحدة — نقطة ملوّنة + عنوان + المبلغ بلون الدلو (النص
/// نفسه علامة غير لونية حاملة للمعنى — §6.1).
class _BucketTile extends StatelessWidget {
  const _BucketTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.decimals,
  });

  final String label;
  final double amount;
  final Color color;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AmountText(amount: amount, decimals: decimals),
        ],
      ),
    );
  }
}

/// سطر عميل — الصورة الرمزية والاسم وعدد الفواتير وشريط الدلاء المصغّر
/// والإجمالي وزر واتساب؛ النقر يوسّع تفاصيل الفواتير المفتوحة.
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    super.key,
    required this.row,
    required this.currencyCode,
    required this.decimals,
    required this.expanded,
    required this.onToggle,
    required this.onRemind,
  });

  final AgingCustomerRow row;
  final String currencyCode;
  final int decimals;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return FinCard(
      onTap: onToggle,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CustomerAvatar(name: row.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.agingInvoicesCount(row.details.length),
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    _BucketBar(row: row),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(amount: row.total, decimals: decimals),
                  const SizedBox(height: 3),
                  _CurrencyPill(code: currencyCode, accent: colors.gold),
                ],
              ),
              const SizedBox(width: 6),
              _WhatsappButton(onTap: onRemind),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _InvoiceDetails(
              details: row.details,
              decimals: decimals,
            ),
          ),
        ],
      ),
    );
  }
}

/// زر تذكير واتساب — دائرة خضراء بروح واتساب (رموز FinColors الإيجابية
/// تتطابق مع ألوانه في الوضعين).
class _WhatsappButton extends StatelessWidget {
  const _WhatsappButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Tooltip(
      message: l10n.agingRemindTooltip,
      child: Material(
        color: colors.positiveContainer,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              Icons.chat_rounded,
              size: 18,
              color: colors.onPositiveContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// تفاصيل الفواتير المفتوحة — سطر لكل فاتورة: الرقم، الاستحقاق، شريحة
/// الأيام الملوّنة بحسب دلوها، والمتبقي.
class _InvoiceDetails extends StatelessWidget {
  const _InvoiceDetails({required this.details, required this.decimals});

  final List<AgingInvoiceDetail> details;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          Divider(height: 1, color: colors.divider),
          for (var i = 0; i < details.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: colors.divider.withValues(alpha: 0.5)),
            _InvoiceDetailRow(
              key: Key('aging_detail_${details[i].invoiceId}'),
              detail: details[i],
              decimals: decimals,
              dueDateLabel: l10n.agingDueDateLabel,
            ),
          ],
        ],
      ),
    );
  }
}

class _InvoiceDetailRow extends StatelessWidget {
  const _InvoiceDetailRow({
    super.key,
    required this.detail,
    required this.decimals,
    required this.dueDateLabel,
  });

  final AgingInvoiceDetail detail;
  final int decimals;
  final String dueDateLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = detail.daysPastDue;
    final bucketIndex = days <= 30
        ? 0
        : days <= 60
        ? 1
        : days <= 90
        ? 2
        : 3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.invoiceNo,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$dueDateLabel: ${_formatDate(context, detail.dueDate ?? detail.issuedAt)}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _DaysBadge(days: days, bucketIndex: bucketIndex),
          const SizedBox(width: 10),
          AmountText(amount: detail.dueAmount, decimals: decimals),
        ],
      ),
    );
  }
}

/// شريحة أيام التأخير — النص حامل المعنى واللون تدرّج الدلاء (§6.1).
class _DaysBadge extends StatelessWidget {
  const _DaysBadge({required this.days, required this.bucketIndex});

  final int days;
  final int bucketIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = days < 0
        ? _bucketColor(context, 0)
        : _bucketColor(context, bucketIndex);
    final label = days < 0
        ? l10n.agingDueInDays(-days)
        : days == 0
        ? l10n.agingDueToday
        : l10n.agingDaysOverdue(days);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// تذييل الإجماليات — الإجمالي العام بعملة التقرير وعدد المدينين.
class _FooterCard extends StatelessWidget {
  const _FooterCard({required this.report, required this.decimals});

  final AgingReport report;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.functions_rounded, size: 18, color: colors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.agingTotalLabel,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AmountText(
                amount: report.grandTotal,
                decimals: decimals,
                size: AmountSize.large,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.agingCustomersCount(report.customersCount),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(width: 8),
          _CurrencyPill(code: report.currencyCode, accent: colors.gold),
        ],
      ),
    );
  }
}

/// الصورة الرمزية للعميل — دائرة بالاسمين الأولين.
class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .take(2)
        .map((word) => word.isEmpty ? '' : word.characters.first)
        .join();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// شريط الدلاء المصغّر — أربع مقاطع بعرضٍ متناسب مع كل دلو (٠–٣٠ يميناً
/// في RTL ثم أعمق فأعمق حتى +٩٠ أقصى اليسار).
class _BucketBar extends StatelessWidget {
  const _BucketBar({required this.row});

  final AgingCustomerRow row;

  @override
  Widget build(BuildContext context) {
    final total = row.total;
    if (total <= 0) return const SizedBox.shrink();
    final segments = <double>[
      row.bucket0to30,
      row.bucket31to60,
      row.bucket61to90,
      row.bucket90Plus,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          // stretch يمدّد المقاطع عديمة الطفل لكامل الارتفاع — وإلا
          // انهارت أبعادها إلى صفر فاختفى الشريط.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < segments.length; i++)
              if (segments[i] > 0)
                Expanded(
                  flex: math.max(1, (segments[i] / total * 1000).round()),
                  child: ColoredBox(
                    color: _bucketColor(context, i).withValues(alpha: 0.85),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// كبسولة رمز العملة الصغيرة.
class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({required this.code, this.accent});

  final String code;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent?.withValues(alpha: 0.14) ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// لون الدلو بتدرّج دلالي أخضر ← كهرماني ← برتقالي ← أحمر (رموز
/// FinColors نقطتا النهاية — الوضعان فاتح/داكن مدعومان).
Color _bucketColor(BuildContext context, int bucket) {
  final colors = FinColors.of(context);
  return switch (bucket) {
    0 => colors.positive,
    1 => colors.warning,
    2 => Color.lerp(colors.warning, colors.negative, 0.55)!,
    _ => colors.negative,
  };
}

/// تاريخ للعرض `يوم/شهر/سنة` بنظام أرقام السياق الحي.
String _formatDate(BuildContext context, DateTime? date) {
  if (date == null) return '—';
  final plain = '${date.day}/${date.month}/${date.year}';
  return NumeralsScope.of(context) ? Numerals.toArabicIndic(plain) : plain;
}
