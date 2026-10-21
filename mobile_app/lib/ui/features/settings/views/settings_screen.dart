/// شاشة «إعدادات» (جذر تبويب `/more`) — **مركز SIM** (V7): ترويسة فرعية
/// بعنوان «إعدادات» **بلا زر رجوع** (جذر تبويب في StatefulShellRoute لا
/// أب يُرجَع إليه — قرار نقد F9-a المحسوم)، بطاقة المنشأة أعلى كما هي
/// (شعار + مدة القفل التلقائي القابلة للضبط — FR-12-05)، ثم الصفوف
/// الستة المقفلة بنمط `.setting-row` من النموذج الأولي، ثم فاصل
/// «المزيد من إعدادات FinAcc» والأقسام الباقية بصفوف SIM (التخصيص/
/// الأمان/البيانات/مركز التقارير) وبطاقة «حول» أسفل القائمة — كل
/// وجهة/فعل من الشاشة القائمة محفوظ (`widgets/sim_settings_sections.dart`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/sim_list_widgets.dart';
import '../view_models/settings_view_model.dart';
import 'widgets/settings_about_card.dart';
import 'widgets/settings_company_card.dart';
import 'widgets/sim_settings_sections.dart';

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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // جذر تبويب: بلا onBack — لا زر رجوع اصطناعي إلى /home.
            SimSubHeader(
              titleKey: const Key('sim_settings_title'),
              title: l10n.homeSettingsLabel,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
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
                    // بطاقة المنشأة — كما هي حرفيًا (FR-12-05 محمية).
                    SettingsCompanyCard(state: state),
                    const SizedBox(height: 16),
                    // الصفوف الستة المقفلة (screen-settings بالنموذج).
                    const SimSettingsCoreRows(),
                    const SizedBox(height: 20),
                    // فاصل القسم: بقية إعدادات FinAcc خلف نموذج SIM.
                    SimSettingsSectionLabel(
                      labelKey: const Key('sim_settings_more_title'),
                      title: l10n.settingsSimMoreTitle,
                      prominent: true,
                    ),
                    const SizedBox(height: 8),
                    SimSettingsSectionLabel(
                      title: l10n.settings2CustomizationTitle,
                    ),
                    const SizedBox(height: 8),
                    const SimSettingsCustomizationRows(),
                    const SizedBox(height: 16),
                    SimSettingsSectionLabel(title: l10n.settingsSecurity),
                    const SizedBox(height: 8),
                    const SimSettingsSecurityRows(),
                    const SizedBox(height: 16),
                    SimSettingsSectionLabel(title: l10n.settingsData),
                    const SizedBox(height: 8),
                    const SimSettingsDataRows(),
                    const SizedBox(height: 16),
                    SimSettingsSectionLabel(title: l10n.reportsTitle),
                    const SizedBox(height: 8),
                    const SimSettingsReportsRows(),
                    const SizedBox(height: 16),
                    // بطاقة «حول» — كما هي أسفل القائمة (بلا مسار).
                    SettingsAboutCard(state: state),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
