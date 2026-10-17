/// شاشة «النسخ الاحتياطي والاستعادة» — FR-11 (وحدة 11، الشريحة 8):
/// بطاقة الحالة بزر «إنشاء نسخة الآن» (FR-11-01)، إعدادات الجدولة
/// (FR-11-04) والاحتفاظ (FR-11-05)، سجل النسخ بكل بياناته (FR-11-06)
/// بزر استعادة ومشاركة لكل نسخة (FR-11-02/08)، واستعادة من ملف خارجي —
/// مع حوار فحص الملف وتحذير الاستبدال قبل التنفيذ.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../view_models/backup_view_model.dart';
import 'widgets/backup_external_restore_card.dart';
import 'widgets/backup_log_card.dart';
import 'widgets/backup_policy_cards.dart';
import 'widgets/backup_status_card.dart';
import 'widgets/backup_web_banner.dart';

/// يفتح شاشة النسخ الاحتياطي.
class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً — عند غيابه تُنشئ الشاشة نموذجها.
  final BackupViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final BackupViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = BackupViewModel(app: app);
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<BackupViewModel>.value(
      value: vm,
      // شاشة قائمة داخل فرع «المزيد» — تحديث عند عودة نشاط المسار.
      child: RefreshOnActive(
        routePattern: RegExp(r'^/more/backup$'),
        onActivate: vm.load,
        child: const _BackupBody(),
      ),
    );
  }
}

class _BackupBody extends StatelessWidget {
  const _BackupBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BackupViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.backupScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: _contentChildren(context, vm, state),
      ),
    );
  }

  /// محتوى القائمة بحرّاس خروج مبكرين — نفس دلالة سلاسل if/else
  /// الأصلية حرفياً: تحميل ← خطأ ← البطاقات.
  List<Widget> _contentChildren(
    BuildContext context,
    BackupViewModel vm,
    BackupScreenState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (state.loading) {
      return const [ListSkeleton(rows: 6)];
    }
    if (state.error != null) {
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
    return [
      if (!vm.filesSupported) ...[
        const BackupWebPreviewBanner(),
        const SizedBox(height: 16),
      ],
      BackupStatusCard(vm: vm),
      const SizedBox(height: 16),
      BackupScheduleCard(vm: vm),
      const SizedBox(height: 16),
      BackupRetentionCard(vm: vm),
      const SizedBox(height: 16),
      BackupLogCard(vm: vm),
      if (vm.filesSupported) ...[
        const SizedBox(height: 16),
        const BackupExternalRestoreCard(),
      ],
    ];
  }
}
