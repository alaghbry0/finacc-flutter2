/// لوحة التحكم الرئيسية — FR-09-01 / §6.5:
/// بطاقة ترحيب (اسم المنشأة + التاريخ هجري/ميلادي) + 4 بلاطات (مبيعات
/// اليوم، أرباح اليوم، فواتير اليوم، صافي الصندوق) + رسم 30 يوماً
/// تفاعلي + تنبيهات المخزون — كل عنصر بحالاته (Skeleton/Error/Empty).
///
/// هذه الجولة: حركات دخول متدرجة (fade+slide بتأخيرات متتابعة)، بطاقة
/// ترحيب بزخرفة هندسية خافتة وخط ذهبي فاصل، شارة «آخر تحديث»، وبلاطات
/// بحلقة أيقونة متدرجة.
///
/// إكمال 17-c (FR-09-01): بطاقة «مبيعات الشهر» العريضة أسفل بلاطات
/// اليوم (الإجمالي + شارة المقارنة ٪ بالأخضر/الأحمر أو «جديد» + عدد
/// الفواتير) + قسم «أعلى الأصناف مبيعاً» بعد رسم 30 يوماً (شارات
/// ترتيب ذهبية/فضية/برونزية + شريط حصة الكمية النسبي) — كلها عبر
/// NumeralsScope وتنسيق المبالغ الموحّد.
///
/// R18-D3b: الشاشة صارت هيكلاً ركيباً — كل مكوّنات الداشبورد انتقلت
/// إلى `views/widgets/` بملفات مركزة (بطاقة الترحيب، بلاطات الوصول،
/// بطاقة الشهر، الأعلى أصنافاً، بانر النسخ، لوحة التاريخ، الجسم).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/session/app_controller.dart';
import '../../../core/widgets/refresh_on_active.dart';
import '../view_models/home_view_model.dart';
import 'widgets/dashboard_body.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      // تحديث حي عند تبديل التبويب/الرجوع — إحصاءات اليوم تتغير بترحيل
      // فواتير من فرع البيع والداشبورد يُستعاد من IndexedStack بلا rebuild
      // (اكتُشف بالتحقق الحي 2026-10-07).
      child: RefreshOnActive(
        routePattern: RegExp(r'^/home$'),
        onActivate: () => vm.load(companyName: app.company?.name),
        child: const DashboardBody(),
      ),
    );
  }
}
