/// شاشة «المزيد» — **مركز أقسام الإعدادات** (UX-2a): بطاقات أقسام بنمط
/// التطبيق (FinCard) تفتح شاشات فرعية متخصصة:
/// بطاقة المنشأة (شعار + مدة القفل التلقائي القابلة للضبط — FR-12-05)
/// → بيانات المنشأة `/more/company` · تفضيلات البيع `/more/sale-prefs` ·
/// العرض والمظهر `/more/appearance` · قوالب طباعة الفواتير
/// `/more/print-templates` (UX-3) · الأمان (تغيير PIN/سجل التدقيق/
/// القفل الفوري) · البيانات (النسخ/المسح المحروس) · مركز التقارير · حول.
/// الأقسام كلها بملفاتها المركزّة بجوارها (R19-D3b).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/settings_view_model.dart';
import 'widgets/settings_about_card.dart';
import 'widgets/settings_company_card.dart';
import 'widgets/settings_sections.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.viewModel});

  /// Seam اختبار: نموذج محمّل مسبقاً (في `runAsync`) — عند غيابه
  /// تُنشئ الشاشة نموذجها وتحمّله بنفسها.
  final SettingsViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    late final SettingsViewModel vm;
    if (viewModel != null) {
      vm = viewModel!;
    } else {
      vm = SettingsViewModel(
        companyRepo: app.companies!,
        userRepo: app.users!,
        settingsRepo: app.settings!,
        backupEngine: app.backupEngine,
      );
      unawaited(vm.load());
    }
    return ChangeNotifierProvider<SettingsViewModel>.value(
      value: vm,
      child: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final state = vm.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.tabMore)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (state.loading)
            const ListSkeleton()
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
            SettingsCompanyCard(state: state),
            const SizedBox(height: 16),
            // مركز التقارير (الشريحة 10) — بوابة الأرباح والرقابة اليومية.
            const SettingsReportsSection(),
            const SizedBox(height: 16),
            SettingsCustomizationSection(state: state),
            const SizedBox(height: 16),
            const SettingsSecuritySection(),
            const SizedBox(height: 16),
            const SettingsDataSection(),
            const SizedBox(height: 16),
            SettingsAboutCard(state: state),
          ],
        ],
      ),
    );
  }
}
