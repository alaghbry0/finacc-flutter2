// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'المحاسب الشخصي';

  @override
  String get appBrand => 'FinAcc';

  @override
  String get brandTagline => 'نظام محاسبي ومخزون متكامل — يعمل بلا إنترنت';

  @override
  String get commonNext => 'التالي';

  @override
  String get commonBack => 'السابق';

  @override
  String get commonDone => 'إنهاء';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonConfirm => 'تأكيد';

  @override
  String get commonContinue => 'متابعة';

  @override
  String get commonDetails => 'التفاصيل';

  @override
  String get commonViewAll => 'عرض الكل';

  @override
  String get splashLoading => 'جارٍ تجهيز قاعدتك المحلية…';

  @override
  String get onboardWelcomeTitle => 'أهلاً بك في المحاسب الشخصي';

  @override
  String get onboardWelcomeMessage =>
      'نظام محاسبي ومخزون متكامل لمتجرك — بياناتك تبقى على جهازك وحدك، بلا إنترنت وبلا اشتراكات.';

  @override
  String get onboardFeature1Title => 'يعمل بلا إنترنت 100%';

  @override
  String get onboardFeature1Desc =>
      'بيع وشراء وجرد وتقارير — حتى بلا شبكة نهائياً.';

  @override
  String get onboardFeature2Title => 'أرقام موثوقة';

  @override
  String get onboardFeature2Desc =>
      'ترقيم مستندات ذرّي لا يتكرر، وتكلفة متوسط مرجّح، وحماية من السالب المخزوني.';

  @override
  String get onboardFeature3Title => 'خصوصية كاملة';

  @override
  String get onboardFeature3Desc =>
      'لا تُرسل أي بيانات لأي خادم — نسخك الاحتياطية ملكك.';

  @override
  String get onboardStepCompany => 'بيانات المنشأة';

  @override
  String get onboardStepSecurity => 'الأمان';

  @override
  String get onboardStepReview => 'جاهز';

  @override
  String get companyNameLabel => 'اسم المنشأة';

  @override
  String get companyNameHint => 'كما يظهر للعملاء في الفواتير';

  @override
  String get companyPhoneLabel => 'رقم الهاتف (اختياري)';

  @override
  String get companyPhoneHint => 'للتفاوض والدعم عبر واتساب لاحقاً';

  @override
  String get baseCurrencyLabel => 'العملة الأساسية';

  @override
  String get baseCurrencyHint =>
      'تُثبَّت بعد الإعداد ولا تُغيَّر لاحقاً — أسعار ما تبقى تُدخل يومياً';

  @override
  String baseCurrencyDecimalsNote(num decimals) {
    String _temp0 = intl.Intl.pluralLogic(
      decimals,
      locale: localeName,
      other: 'عدد المنازل: $decimals',
      one: 'منزلة عشرية واحدة',
      zero: 'بلا كسور عشرية',
    );
    return '$_temp0';
  }

  @override
  String get companyFormInvalid => 'أكمل اسم المنشأة واختر عملة أساسية';

  @override
  String get pinSetupTitle => 'رمز PIN الخاص بك';

  @override
  String get pinSetupSubtitle => 'من 4 إلى 6 خانات — سيُطلب عند كل فتح للتطبيق';

  @override
  String get pinConfirmTitle => 'تأكيد الرمز';

  @override
  String get pinConfirmSubtitle => 'أعد إدخال نفس الرمز للتأكيد';

  @override
  String get pinMismatch => 'الرمزان غير متطابقين. أعد الإدخال.';

  @override
  String get pinInvalidLength => 'الرمز يجب أن يكون من 4 إلى 6 خانات رقمية.';

  @override
  String get passphraseTitle => 'عبارة المرور';

  @override
  String get passphraseSubtitle =>
      'بوابة الاسترداد عند نسيان PIN (بعد 10 محاولات خاطئة) — لا تُستعاد أبداً';

  @override
  String get passphraseLabel => 'عبارة المرور (8 خانات فأكثر)';

  @override
  String get passphraseConfirmLabel => 'تأكيد عبارة المرور';

  @override
  String get passphraseMismatch => 'العبارتان غير متطابقتين. أعد الإدخال.';

  @override
  String get passphraseWarningTitle => 'تحذير مهم — اقرأه قبل المتابعة';

  @override
  String get passphraseWarningBody =>
      'نسيان عبارة المرور يعني فقدان الوصول نهائياً؛ الاسترداد الوحيد هو ملف نسخة احتياطية تحتفظ به بنفسك. ثبتها في مكان آمن وفعّل النسخ الاحتياطي مبكراً.';

  @override
  String get passphraseShort => 'العبارة يجب ألا تقل عن 8 خانات.';

  @override
  String get creatingTitle => 'جارٍ تأسيس متجرك…';

  @override
  String get creatingMessage =>
      'ننشئ المنشأة والمخزن الرئيسي والصندوق الرئيسي والسنة المالية داخل معاملة واحدة آمنة — أي فشل يرجع كل شيء ولا يكتب نصف تأسيس.';

  @override
  String get createdTitle => 'تم التأسيس بنجاح';

  @override
  String createdMessage(Object cashbox, Object warehouse) {
    return 'أنشأنا «$warehouse» و«$cashbox» جاهزين لأول عملية — لم يتبقَّ أي إعداد إلزامي.';
  }

  @override
  String get startUsing => 'ابدأ الاستخدام';

  @override
  String get setupFailedTitle => 'تعذّر إتمام التأسيس';

  @override
  String get setupFailedBody =>
      'راجع البيانات وأعد المحاولة — لم يُكتب شيء في القاعدة.';

  @override
  String get lockTitle => 'أدخل رمز PIN';

  @override
  String get lockSubtitle => 'التطبيق مقفل لحماية بياناتك المالية';

  @override
  String get lockWrong => 'رمز غير صحيح';

  @override
  String lockAttemptsBeforeLock(Object count) {
    return 'أتبقى $count من المحاولات قبل التأخير المؤقت';
  }

  @override
  String lockDelayedMessage(Object duration) {
    return 'انتظر $duration ثم أعد المحاولة';
  }

  @override
  String get lockPassphraseTitle => 'عبارة المرور مطلوبة';

  @override
  String get lockPassphraseMessage =>
      'استُنفدت محاولات PIN العشر. أدخل عبارة المرور التي اخترتها عند التأسيس لاستعادة الوصول.';

  @override
  String get lockPassphraseFieldLabel => 'عبارة المرور';

  @override
  String get lockPassphraseFailed => 'عبارة المرور غير صحيحة.';

  @override
  String get lockUnlockButton => 'فتح';

  @override
  String get lockUsePassphrase => 'استخدم عبارة المرور';

  @override
  String get lockBackToPin => 'العودة إلى PIN';

  @override
  String get lockVerifying => 'جارٍ التحقق…';

  @override
  String get wipeDialogTitle => 'مسح كل البيانات؟';

  @override
  String get wipeDialogBody =>
      'سيُمحى كل شيء نهائياً — الفواتير والأصناف والأرصدة والإعدادات — ويعود التطبيق كأنه مثبَّت لأول مرة. لا يمكن التراجع عن هذه الخطوة.';

  @override
  String get wipeConfirmWord => 'مسح';

  @override
  String get wipeFinalTitle => 'تأكيد نهائي';

  @override
  String get wipeFinalBody =>
      'كتب «مسح» بحروف مطابقة لتأكيد محو القاعدة بالكامل. إن كانت لديك نسخة احتياطية فستبقى سليمة خارج التطبيق.';

  @override
  String get wipeDoneTitle => 'تم المسح';

  @override
  String get wipeDoneBody => 'الآن سيعاد فتح التطبيق على شاشة التأسيس.';

  @override
  String get dashboardTitle => 'الرئيسية';

  @override
  String get morningGreeting => 'صباح الخير';

  @override
  String get eveningGreeting => 'مساء الخير';

  @override
  String get todaySales => 'مبيعات اليوم';

  @override
  String get todayProfit => 'أرباح اليوم';

  @override
  String get todayInvoices => 'فواتير اليوم';

  @override
  String get netCash => 'صافي الصندوق';

  @override
  String get last30DaysTitle => 'مبيعات آخر 30 يوماً';

  @override
  String get chartEmptyMessage => 'ستظهر مبيعاتك هنا بعد أول فاتورة';

  @override
  String get stockAlertsTitle => 'تنبيهات المخزون';

  @override
  String get stockAlertsEmpty => 'لا تنبيهات — كل الأصناف فوق الحد الأدنى';

  @override
  String stockAlertsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صنف',
      many: '$count صنفاً',
      few: '$count أصناف',
      two: 'صنفان',
      one: 'صنف واحد',
      zero: 'لا أصناف',
    );
    return '$_temp0 تحت الحد الأدنى';
  }

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabSell => 'البيع';

  @override
  String get tabInventory => 'المخزون';

  @override
  String get tabCash => 'النقدية';

  @override
  String get tabMore => 'المزيد';

  @override
  String get comingSoonTitle => 'قادم في الشرائح التالية';

  @override
  String comingSoonBody(Object feature) {
    return 'وحدة «$feature» تُبنى في شريحتها المخصصة بعد اعتماد المرحلة الأولى — البنية وقاعدة البيانات جاهزة لها الآن.';
  }

  @override
  String get featureSell => 'البيع والكاشير';

  @override
  String get featureInventory => 'الأصناف والمخزون والدفعات';

  @override
  String get featureCash => 'الصناديق والنقدية';

  @override
  String get featureMore => 'الأطراف والتقارير والإعدادات';

  @override
  String get dbOpenErrorTitle => 'تعذّر فتح قاعدة البيانات';

  @override
  String get dbOpenErrorMessage =>
      'قد يكون ملف القاعدة مشغولاً أو المساحة ممتلئة. أعد المحاولة — بياناتك لم تتأثر.';

  @override
  String get genericErrorTitle => 'حدث خطأ غير متوقع';

  @override
  String get loadingData => 'جارٍ التحميل…';
}
