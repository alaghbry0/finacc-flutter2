/// نقطة الانطلاق — إنشاء متحكم الجلسة وتهيئة التطبيق.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'ui/core/session/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  // التهيئة غير محجوبة: شاشة الافتتاح تُظهر تقدّمها ثم يقود الموجّه.
  final boot = controller.bootstrap();
  // تجاهل واعٍ: أخطاء التهيئة تُدار داخل المتحكم (طور error + DS-33).
  boot.ignore();
  runApp(
    ChangeNotifierProvider<AppController>.value(
      value: controller,
      child: FinAccApp(controller: controller),
    ),
  );
}
