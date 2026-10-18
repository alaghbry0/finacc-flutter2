/// شاشة سجل التدقيق — FR-12-04 (الجانب العرضي):
/// أحداث أمنية موسّعة للقراءة فقط، مجمّعة باليوم (اليوم/أمس/تاريخ هجري
/// وميلادي)، لكل حدث أيقونة تصنيفية ولون دلالي واسم المنفّذ والوقوت —
/// مع بطاقة توضيح «للإضافة فقط» (Triggers داخل ملف القاعدة) وترقيم
/// صفحات بزر «المزيد».
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/audit_log_view_model.dart';
import 'widgets/audit_append_only_card.dart';
import 'widgets/audit_empty_state.dart';
import 'widgets/audit_filter_bar.dart';
import 'widgets/audit_load_more_button.dart';
import 'widgets/audit_timeline.dart';

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
          const AuditAppendOnlyCard(),
          const SizedBox(height: 12),
          AuditFilterBar(
            selected: state.filter,
            counts: state.counts,
            onSelect: vm.setFilter,
          ),
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
            AuditEmptyState(
              eventCount: state.totalCount,
              filtered: state.filter != null,
              onClearFilter: () => vm.setFilter(null),
            )
          else ...[
            AuditTimeline(events: state.events),
            if (state.hasMore) ...[
              const SizedBox(height: 14),
              AuditLoadMoreButton(
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
