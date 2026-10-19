/// لوحة التحكم الإحصائية (FR-09-01) — كانت الشاشة الرئيسية قبل V3،
/// والآن مسار مستقل `/home/dashboard` يُفتح من درج مركز المعاملات:
/// بطاقة ترحيب + بلاطات اليوم + رسم 30 يوماً + مبيعات الشهر + أعلى
/// الأصناف + تنبيهات المخزون — بياناتها ومكوناتها كما هي بلا تعديل.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/session/app_controller.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../view_models/home_view_model.dart';
import 'widgets/dashboard_body.dart';

/// شاشة لوحة التحكم الإحصائية.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final vm = DashboardViewModel(
      repository: app.dashboard!,
      companyRepository: app.companies,
      backupEngine: app.backupEngine,
    );
    unawaited(vm.load(companyName: app.company?.name));
    return ChangeNotifierProvider<DashboardViewModel>.value(
      value: vm,
      // تحديث حي عند الرجوع إلى اللوحة — نفس نمط مركز المعاملات.
      child: RefreshOnActive(
        routePattern: RegExp(r'^/home/dashboard$'),
        onActivate: () => vm.load(companyName: app.company?.name),
        child: const DashboardBody(),
      ),
    );
  }
}
