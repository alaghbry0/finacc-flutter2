// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'تطبيقي';

  @override
  String get homeTitle => 'البيئة جاهزة';

  @override
  String get envReadyMessage =>
      'يعمل الهيكل المعماري النظيف مع التوطين والتوجيه التصريحي وإدارة حالة MVVM.';

  @override
  String get architectureSectionTitle => 'طبقات البنية المعمارية';

  @override
  String get layerUi => 'الواجهة — العروض ونماذج العرض';

  @override
  String get layerDomain => 'المجال — النماذج وحالات الاستخدام';

  @override
  String get layerData => 'البيانات — الخدمات والمستودعات';

  @override
  String get counterSectionTitle => 'عرض توضيحي للعداد MVVM';

  @override
  String counterValue(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نقرة',
      many: '$count نقرة',
      few: '$count نقرات',
      two: 'نقرتان',
      one: 'نقرة واحدة',
      zero: 'جاهز',
    );
    return '$_temp0';
  }

  @override
  String get increment => 'زيادة';

  @override
  String get reset => 'تصفير';
}
