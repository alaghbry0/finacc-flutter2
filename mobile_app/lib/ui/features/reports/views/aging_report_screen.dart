/// شاشة «أعمار الديون» (FR-09-05 — الشريحة 9): أرصدة العملاء مصنّفة
/// (٠–٣٠ / ٣١–٦٠ / ٦١–٩٠ / +٩٠) على أساس FIFO بعملة واحدة، مع بطاقة
/// ملخص ملوّنة تدرّجياً، شريط دلاء مصغّر لكل عميل، توسيع لتفاصيل
/// الفواتير المفتوحة، وتذكير واتساب (wa.me) لكل مدين.
///
/// (R19-D3a: الويدجت المركزّة في `widgets/` — منتقي العملة وبطاقة
/// الملخص وسطر العميل وتفاصيل الفواتير والتذييل والمساعدات.)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/debt_aging_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_return.dart';
import '../view_models/aging_view_model.dart';
import 'widgets/aging_currency_selector.dart';
import 'widgets/aging_customer_card.dart';
import 'widgets/aging_footer_card.dart';
import 'widgets/aging_format.dart';
import 'widgets/aging_summary_card.dart';

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
      child: RefreshOnReturn(
        onReappear: vm.refresh,
        child: _AgingBody(origin: origin),
      ),
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
                l10n.agingAsOfLabel(agingFormatDate(context, report.asOf)),
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
                AgingCurrencySelector(state: state),
                const SizedBox(height: 14),
              ],
              ..._buildContent(context, vm),
            ],
          ),
        ),
      ),
    );
  }

  /// محتوى الشاشة بحرّاس خروج مبكرين: تحميل ← خطأ ← لا تقرير ← لا ديون ←
  /// المحتوى (نفس دلالة السلاسل الأصلية حرفياً).
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
      AgingSummaryCard(report: report, decimals: state.decimals),
      const SizedBox(height: 14),
      for (final row in report.rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AgingCustomerCard(
            key: Key('aging_row_${report.currencyId}_${row.customerId}'),
            row: row,
            currencyCode: report.currencyCode,
            decimals: state.decimals,
            expanded: _expanded.contains(row.customerId),
            onToggle: () => _toggle(row.customerId),
            onRemind: () => unawaited(_remind(vm, row)),
          ),
        ),
      AgingFooterCard(report: report, decimals: state.decimals),
    ];
  }
}
