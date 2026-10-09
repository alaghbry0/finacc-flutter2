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
  String get dashboardQuickAccess => 'الوصول السريع';

  @override
  String get dashboardQuickRates => 'الصرف';

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
  String get comingGatedBadge => 'بانتظار اعتماد المرحلة الأولى';

  @override
  String get featureSell => 'البيع والكاشير';

  @override
  String get featureInventory => 'الأصناف والمخزون والدفعات';

  @override
  String get featureCash => 'الصناديق والنقدية';

  @override
  String get featureMore => 'الأطراف والتقارير والإعدادات';

  @override
  String get comingSellH1 => 'كاشير سريع بلمسة أو اثنتين لكل صنف';

  @override
  String get comingSellH2 => 'فواتير آجلة وتقسيط دفعات كامل مع سياسات الحماية';

  @override
  String get comingInventoryH1 => 'أصناف بتكلفة المتوسط المرجّح وبطاقات باركود';

  @override
  String get comingInventoryH2 =>
      'دفعات توريد وتاريخ صلاحية FEFO ومنع السالب المخزوني';

  @override
  String get comingCashH1 => 'حركات قبض وصرف بين صناديق متعددة';

  @override
  String get comingCashH2 => 'تسويات وحساب أرصدة نهاية اليوم بالعملات';

  @override
  String get comingMoreH1 => 'أطراف (عملاء/موردون) بحدود ائتمان محكومة';

  @override
  String get comingMoreH2 => 'تقارير وتحليلات ونسخ احتياطي مجدول';

  @override
  String get settingsBaseCurrency => 'العملة الأساسية';

  @override
  String get settingsAdmin => 'المدير';

  @override
  String get settingsAutolock => 'القفل التلقائي بعد';

  @override
  String settingsAutolackValue(num minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقائق',
      one: 'دقيقة واحدة',
    );
    return '$_temp0 من الخمول';
  }

  @override
  String get settingsSecurity => 'الأمان';

  @override
  String get settingsChangePin => 'تغيير رمز PIN';

  @override
  String get settingsChangePinDesc =>
      'تحقق من الرمز الحالي ثم ثبّت رمزاً جديداً';

  @override
  String get settingsLockNow => 'قفل التطبيق الآن';

  @override
  String get settingsLockNowDesc => 'يعود إلى شاشة الدخول فوراً';

  @override
  String get settingsTheme => 'المظهر';

  @override
  String get themeSystem => 'تلقائي (حسب النظام)';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get settingsThemeNote =>
      'يُحفظ اختيارك في قاعدتك المحلية ويبقى بعد إعادة التشغيل.';

  @override
  String get settingsData => 'البيانات';

  @override
  String get settingsWipe => 'مسح كل البيانات';

  @override
  String get settingsWipeDesc => 'إعادة التطبيق لحالة التثبيت الأول — لا تراجع';

  @override
  String get settingsAboutSrs => 'وفق وثيقة المتطلبات SRS v1.5 المعتمدة';

  @override
  String get changePinStep1Label => 'الحالي';

  @override
  String get changePinStep2Label => 'الجديد';

  @override
  String get changePinStep3Label => 'التأكيد';

  @override
  String get changePinStepCurrent => 'أدخل رمز PIN الحالي للمتابعة';

  @override
  String get changePinStepNew => 'اختر رمزاً جديداً من 4 إلى 6 خانات';

  @override
  String get changePinStepConfirm => 'أعد إدخال الرمز الجديد للتأكيد';

  @override
  String get changePinDoneTitle => 'تم تغيير الرمز بنجاح';

  @override
  String get changePinDoneBody =>
      'استخدم الرمز الجديد عند فتح التطبيق من الآن — وقد سُجّل التغيير في سجل التدقيق.';

  @override
  String get changePinWrongCurrent => 'الرمز الحالي غير صحيح — أعد المحاولة';

  @override
  String get changePinSameAsCurrent =>
      'الرمز الجديد مطابق للحالي — اختر رمزاً مختلفاً';

  @override
  String get changePinNoPin => 'لا يوجد رمز مضبوط — أعد تأسيس التطبيق';

  @override
  String get dbOpenErrorTitle => 'تعذّر فتح قاعدة البيانات';

  @override
  String get dbOpenErrorMessage =>
      'قد يكون ملف القاعدة مشغولاً أو المساحة ممتلئة. أعد المحاولة — بياناتك لم تتأثر.';

  @override
  String get genericErrorTitle => 'حدث خطأ غير متوقع';

  @override
  String get loadingData => 'جارٍ التحميل…';

  @override
  String get settingsAutolockSheetTitle => 'مدة القفل التلقائي';

  @override
  String get settingsAutolockSheetSubtitle =>
      'يُقفل التطبيق بعد هذه المدة من الخمول — النطاق المسموح من دقيقة إلى ٦٠ دقيقة.';

  @override
  String get settingsNumerals => 'نظام الأرقام';

  @override
  String get numeralsWestern => 'غربي';

  @override
  String get numeralsArabicIndic => 'عربي شرقي';

  @override
  String get settingsNumeralsNote =>
      'ينعكس فوراً على المبالغ والتواريخ في كل التطبيق — التخزين يبقى بأرقام غربية دائماً.';

  @override
  String get settingsAuditLog => 'سجل التدقيق';

  @override
  String get settingsAuditLogDesc => 'أحداث أمنية موسّعة — للإضافة فقط';

  @override
  String get auditTitle => 'سجل التدقيق';

  @override
  String get auditProtectedTitle => 'سجل محمي داخل قاعدة بياناتك';

  @override
  String get auditProtectedBody =>
      'الأحداث الأمنية الحرجة تُسجّل هنا ولا يمكن تعديلها أو حذفها من التطبيق — الحماية نفسها مبنية داخل ملف القاعدة (Triggers تمنع التعديل والحذف من أي جهة).';

  @override
  String get auditAppendOnlyBadge => 'للإضافة فقط';

  @override
  String get auditEmptyTitle => 'لا أحداث مسجّلة بعد';

  @override
  String get auditEmptyBody =>
      'تظهر هنا الأحداث الأمنية الحرجة: التأسيس، تغيير الرمز، تجاوز عتبات المحاولات، والتغييرات الأمنية في الإعدادات.';

  @override
  String get auditDayToday => 'اليوم';

  @override
  String get auditDayYesterday => 'أمس';

  @override
  String get auditActionAppSetup => 'تأسيس التطبيق';

  @override
  String get auditActionPinChange => 'تغيير رمز PIN';

  @override
  String get auditActionLockoutDelay => 'تجاوز حد المحاولات — تأخير مؤقت';

  @override
  String get auditActionLockoutPassphrase =>
      'استنفاد المحاولات — طلب عبارة المرور';

  @override
  String get auditActionSettingsChange => 'تغيير إعداد أمني';

  @override
  String auditActionUnknown(Object action) {
    return 'حدث: $action';
  }

  @override
  String auditLoadMore(Object shown, Object total) {
    return 'عرض المزيد ($shown من $total)';
  }

  @override
  String get auditFilterAll => 'الكل';

  @override
  String get auditFilterSetup => 'التأسيس';

  @override
  String get auditFilterSecurity => 'الأمان';

  @override
  String get auditFilterSettings => 'الإعدادات';

  @override
  String get auditFilterOther => 'أخرى';

  @override
  String get auditFilterEmptyTitle => 'لا أحداث في هذا التصنيف';

  @override
  String get auditFilterEmptyBody =>
      'اختر تصنيفاً آخر أو أزل التصفية لعرض كل الأحداث المسجلة.';

  @override
  String auditCountsAll(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أحداث',
      two: 'حدثان',
      one: 'حدث واحد',
      zero: 'لا أحداث',
    );
    return '$_temp0';
  }

  @override
  String get settingsLicenses => 'التراخيص المفتوحة';

  @override
  String get settingsLicensesDesc => 'مكونات مفتوحة المصدر داخل التطبيق';

  @override
  String get dateSheetTitle => 'تاريخ اليوم';

  @override
  String get dateSheetTodayBadge => 'اليوم';

  @override
  String get dateSheetHijriLabel => 'التقويم الهجري';

  @override
  String get dateSheetGregorianLabel => 'التقويم الميلادي';

  @override
  String get dateSheetWeekdayLabel => 'اليوم';

  @override
  String get commonAdd => 'إضافة';

  @override
  String get inventoryHomeHeroTitle => 'إدارة المخزن';

  @override
  String get inventoryHomeHeroSubtitle =>
      'أصنافك ودفعاتك ومخزونك في مكان واحد — تصنيف، تتبع، وتنبيه قبل النفاد';

  @override
  String get inventoryHubAddItem => 'إضافة صنف جديد';

  @override
  String get inventoryHubAddItemDesc => 'اسم وباركود وفئة وأسعار بكل العملات';

  @override
  String get inventoryHubItems => 'الأصناف المتوفرة';

  @override
  String get inventoryHubItemsDesc =>
      'بحث فوري بالاسم أو الباركود مع تصفية بالفئات';

  @override
  String get inventoryHubLowStock => 'أصناف تنفذ قريباً';

  @override
  String get inventoryHubLowStockDesc =>
      'كل صنف وصل تحت حد إعادة الطلب — النفاد التام مشمول';

  @override
  String get inventoryHubBatches => 'الدفعات وتواريخ الصلاحية';

  @override
  String get inventoryHubBatchesDesc =>
      'تنبيهات FEFO للدفعات المنتهية والقريبة من الانتهاء';

  @override
  String get inventoryHubImport => 'استيراد أصناف من ملف';

  @override
  String get inventoryHubImportDesc =>
      'CSV أو Excel مع فحص ومراجعة قبل الإدخال';

  @override
  String get inventoryHubCategoriesUnits => 'الفئات والوحدات';

  @override
  String get inventoryHubCategoriesUnitsDesc =>
      'شجرة فئات بمستويين ووحدات بمعامل تحويل';

  @override
  String get itemsListTitle => 'الأصناف المتوفرة';

  @override
  String itemsListSubtitleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صنف',
      many: '$count صنفاً',
      few: '$count أصناف',
      two: 'صنفان',
      one: 'صنف واحد',
      zero: 'لا أصناف بعد',
    );
    return '$_temp0';
  }

  @override
  String itemsListSubtitleApprox(Object count) {
    return 'أكثر من $count صنفاً';
  }

  @override
  String get itemsListSearchHint => 'ابحث بالاسم أو الباركود';

  @override
  String get itemsListFilterAll => 'الكل';

  @override
  String get itemsListStockLabel => 'المتوفر';

  @override
  String get itemsListPriceLabel => 'السعر';

  @override
  String get itemsListOutOfStockBadge => 'نفد';

  @override
  String get itemsListLowStockBadge => 'قرب النفاد';

  @override
  String get itemServiceBadge => 'خدمي';

  @override
  String get itemBatchesBadge => 'دفعات';

  @override
  String get itemsListAddTooltip => 'إضافة صنف جديد';

  @override
  String itemsListLoadMore(Object shown) {
    return 'عرض المزيد ($shown)';
  }

  @override
  String get itemsListEmptyTitle => 'لا أصناف بعد';

  @override
  String get itemsListEmptyBody =>
      'أنشئ أول صنف لتتبع مخزونه وأسعاره، أو استورد قائمة جاهزة من ملف CSV أو Excel.';

  @override
  String get itemsListEmptyAction => 'إضافة أول صنف';

  @override
  String get itemsListSearchEmptyTitle => 'لا نتائج مطابقة';

  @override
  String get itemsListSearchEmptyBody =>
      'جرّب كلمة أخرى أو امسح البحث لعرض كل الأصناف.';

  @override
  String get itemFormAddTitle => 'إضافة صنف جديد';

  @override
  String get itemFormEditTitle => 'تعديل الصنف';

  @override
  String get itemFormEditNote =>
      'المخزون لا يُعدَّل من هنا — الكمية الافتتاحية تُدخل عند الإنشاء فقط، وما بعدها بحركات الشراء والبيع والجرد.';

  @override
  String get itemFormNameLabel => 'اسم الصنف';

  @override
  String get itemFormNameHint => 'كما يظهر في الفواتير والبحث';

  @override
  String get itemFormNameRequired => 'اسم الصنف مطلوب';

  @override
  String get itemFormBarcodeLabel => 'الباركود';

  @override
  String get itemFormBarcodeHint =>
      'اتركه فارغاً ليولَّد EAN-13 تلقائياً عند الحفظ';

  @override
  String get itemFormBarcodeGenerate => 'توليد';

  @override
  String get itemFormBarcodeRegenerate => 'إعادة التوليد';

  @override
  String get itemFormBarcodeQrToggle => 'QR';

  @override
  String get itemFormBarcodeEanToggle => 'EAN';

  @override
  String get itemFormCode128Caption => 'Code128 — باركود المورد';

  @override
  String get itemFormCategoryLabel => 'الفئة';

  @override
  String get itemFormCategoryNone => 'بلا فئة';

  @override
  String get itemFormCategoryAdd => 'فئة جديدة…';

  @override
  String get itemFormUnitLabel => 'وحدة القياس';

  @override
  String get itemFormUnitNone => 'بلا وحدة';

  @override
  String get itemFormUnitAdd => 'وحدة جديدة…';

  @override
  String get itemFormCostLabel => 'سعر التكلفة';

  @override
  String get itemFormCostInvalid => 'أدخل سعر تكلفة صحيحاً (صفر أو أكثر)';

  @override
  String get itemFormMinStockLabel => 'حد إعادة الطلب';

  @override
  String get itemFormMinStockHint => 'تنبيه عندما يقل المتوفر عن هذا الحد';

  @override
  String get itemFormMinStockInvalid => 'أدخل حداً صحيحاً (صفر أو أكثر)';

  @override
  String get itemFormOpeningQtyLabel => 'الكمية الافتتاحية';

  @override
  String get itemFormOpeningQtyHint =>
      'تُقيَّد كرصيد افتتاحي في المخزن الرئيسي';

  @override
  String get itemFormOpeningQtyInvalid => 'أدخل كمية صحيحة (صفر أو أكثر)';

  @override
  String get itemFormServiceLabel => 'صنف خدمي';

  @override
  String get itemFormServiceDesc => 'بلا مخزون ولا كمية — مثل النقل أو التركيب';

  @override
  String get itemFormTrackBatchesLabel => 'تتبع الدفعات والصلاحية';

  @override
  String get itemFormTrackBatchesDesc =>
      'تُدار كميته بدفعات مرتبة FEFO مع تواريخ انتهاء — سجّل الدفعات من بطاقة الصنف بعد الحفظ.';

  @override
  String get itemFormPricesSection => 'أسعار البيع';

  @override
  String itemFormPriceLabel(Object currency) {
    return 'سعر البيع — $currency';
  }

  @override
  String get itemFormPriceInvalid => 'أدخل سعراً صحيحاً (صفر أو أكثر)';

  @override
  String get itemFormNotesLabel => 'ملاحظات';

  @override
  String get itemFormNotesHint => 'اختياري — تظهر في بطاقة الصنف';

  @override
  String get itemFormSave => 'حفظ البيانات';

  @override
  String get itemFormSaving => 'جارٍ الحفظ…';

  @override
  String get itemFormSavedMessage => 'تم حفظ الصنف بنجاح';

  @override
  String get categoryNameLabel => 'اسم الفئة';

  @override
  String get categoryParentLabel => 'الفئة الأم';

  @override
  String get categoryParentNone => '— فئة رئيسية —';

  @override
  String get unitNameLabel => 'اسم الوحدة';

  @override
  String get unitFactorLabel => 'معامل التحويل';

  @override
  String get unitFactorHint => 'مثال: 1 كرتون = 24 قطعة ← اكتب 24';

  @override
  String get unitFactorInvalid => 'معامل التحويل يجب أن يكون رقماً أكبر من صفر';

  @override
  String get itemDetailTitle => 'بطاقة الصنف';

  @override
  String get itemDetailArchivedBadge => 'مؤرشف';

  @override
  String get itemDetailBatchesBadge => 'دفعات FEFO';

  @override
  String get itemDetailCostLabel => 'التكلفة';

  @override
  String get itemDetailPricesSection => 'أسعار البيع';

  @override
  String get itemDetailStockSection => 'المخزون';

  @override
  String get itemDetailTotalLabel => 'الإجمالي';

  @override
  String get itemDetailMinStockLabel => 'حد الطلب';

  @override
  String get itemDetailServiceNote =>
      'صنف خدمي — لا يُتتبع له مخزون ولا كميات.';

  @override
  String get itemDetailBatchesSection =>
      'الدفعات — الأقرب انتهاءً أولاً (FEFO)';

  @override
  String get itemDetailNoBatches =>
      'لا دفعات مسجلة بعد — تُنشأ الدفعات مع فواتير الشراء.';

  @override
  String get itemDetailMovementsSection => 'آخر الحركات';

  @override
  String get itemDetailNoMovements => 'لا حركات بعد';

  @override
  String get itemDetailRemainingLabel => 'الرصيد';

  @override
  String get itemDetailBarcodeNote =>
      'الطباعة والمشاركة تُتاحان في وحدة الطباعة لاحقاً — الباركود جاهز للمسح من الشاشة.';

  @override
  String get itemDetailQrTitle => 'رمز QR للصنف';

  @override
  String get itemDetailEditAction => 'تعديل الصنف';

  @override
  String get itemDetailArchiveAction => 'أرشفة الصنف';

  @override
  String get itemDetailArchiveTitle => 'أرشفة الصنف؟';

  @override
  String get itemDetailArchiveBody =>
      'الأرشفة بدل الحذف — يختفي الصنف من البحث والبيع وتبقى حركاته وأسعاره كاملة في التاريخ. لا يُحذف صنف له حركات أبداً.';

  @override
  String get itemDetailArchivedMessage => 'أُرشف الصنف — تاريخه محفوظ بالكامل';

  @override
  String get itemDetailNotFound => 'الصنف غير موجود أو محذوف من القاعدة.';

  @override
  String batchDaysLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'باقٍ $count يوماً',
      many: 'باقٍ $count يوماً',
      few: 'باقٍ $count أيام',
      two: 'باقٍ يومان',
      one: 'باقٍ يوم واحد',
      zero: 'ينتهي اليوم',
    );
    return '$_temp0';
  }

  @override
  String get batchExpired => 'منتهية';

  @override
  String get batchNoExpiry => 'بلا صلاحية';

  @override
  String get itemMovementOpening => 'رصيد افتتاحي';

  @override
  String get itemMovementPurchase => 'شراء';

  @override
  String get itemMovementSale => 'بيع';

  @override
  String get itemMovementSaleReturn => 'مرتجع بيع';

  @override
  String get itemMovementPurchaseReturn => 'مرتجع شراء';

  @override
  String get itemMovementStocktakeAdjust => 'تسوية جرد';

  @override
  String get itemMovementManualAdjust => 'تسوية يدوية';

  @override
  String get itemMovementTransferIn => 'تحويل وارد';

  @override
  String get itemMovementTransferOut => 'تحويل صادر';

  @override
  String get itemMovementUnknown => 'حركة';

  @override
  String get lowStockTitle => 'أصناف تنفذ قريباً';

  @override
  String get lowStockThresholdLabel => 'الحد الأدنى';

  @override
  String get lowStockSearchHint => 'ابحث بالاسم';

  @override
  String lowStockResultCount(num count) {
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
    return '$_temp0';
  }

  @override
  String get lowStockEmptyTitle => 'لا توجد أصناف ضمن هذه المعايير';

  @override
  String get lowStockEmptyBody =>
      'كل الأصناف فوق الحد المحدد — ارفع الحد لعرض المزيد أو غيّر كلمة البحث.';

  @override
  String get batchesTitle => 'الدفعات وتواريخ الصلاحية';

  @override
  String get batchesFilterAll => 'الكل';

  @override
  String get batchesBucketExpired => 'منتهية';

  @override
  String get batchesBucket30 => '≤ 30 يوماً';

  @override
  String get batchesBucket60 => '≤ 60 يوماً';

  @override
  String get batchesBucket90 => '≤ 90 يوماً';

  @override
  String batchesResultCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دفعة',
      many: '$count دفعة',
      few: '$count دفعات',
      two: 'دفعتان',
      one: 'دفعة واحدة',
      zero: 'لا دفعات',
    );
    return '$_temp0';
  }

  @override
  String get batchesEmptyTitle => 'لا دفعات في هذا السلم';

  @override
  String get batchesEmptyBody =>
      'الدفعات تُنشأ مع فواتير الشراء للأصناف المتتبعة، وتُعرض هنا مرتبة بالأقرب انتهاءً.';

  @override
  String get batchesQtyLabel => 'الكمية';

  @override
  String get batchesExpiryLabel => 'الانتهاء';

  @override
  String get importTitle => 'استيراد أصناف';

  @override
  String get importModeFile => 'ملف (CSV / Excel)';

  @override
  String get importModePaste => 'لصق CSV';

  @override
  String get importPickFile => 'اختيار ملف';

  @override
  String get importPickFileDesc =>
      'ملف CSV أو Excel (xlsx) — تُقرأ الورقة الأولى';

  @override
  String get importPasteHint => 'ألصق محتوى CSV هنا — السطر الأول رأس الجدول';

  @override
  String get importPasteFieldHint =>
      'الاسم,الباركود,التكلفة,الكمية,الحد,الفئة,الوحدة';

  @override
  String get importClearSource => 'إزالة';

  @override
  String get importContinue => 'متابعة لربط الأعمدة';

  @override
  String get importMappingSection => 'ربط الأعمدة';

  @override
  String get importMappingDesc =>
      'خمّنّا الربط من رأس الجدول — راجعه وصحّح إن لزم.';

  @override
  String get importMappingIgnore => '— تجاهل —';

  @override
  String get importColumnName => 'الاسم';

  @override
  String get importColumnBarcode => 'الباركود';

  @override
  String get importColumnCost => 'التكلفة';

  @override
  String get importColumnQty => 'الكمية الافتتاحية';

  @override
  String get importColumnMinStock => 'حد الطلب';

  @override
  String get importColumnCategory => 'الفئة';

  @override
  String get importColumnUnit => 'الوحدة';

  @override
  String get importColumnNotes => 'ملاحظات';

  @override
  String importColumnPrice(Object code) {
    return 'سعر $code';
  }

  @override
  String get importAnalyze => 'تحليل الملف';

  @override
  String get importAnalyzing => 'جارٍ التحليل…';

  @override
  String get importNoSource => 'اختر ملفاً أو ألصق محتوى CSV أولاً';

  @override
  String get importNameNotMapped => 'اربط عمود «الاسم» أولاً — حقل إلزامي';

  @override
  String importValidRows(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صف سليم',
      many: '$count صفاً سليماً',
      few: '$count صفوف سليمة',
      two: 'صفان سليمان',
      one: 'صف سليم',
    );
    return '$_temp0';
  }

  @override
  String importFailedRows(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صف فاشل',
      many: '$count صفاً فاشلاً',
      few: '$count صفوف فاشلة',
      two: 'صفان فاشلان',
      one: 'صف فاشل',
    );
    return '$_temp0';
  }

  @override
  String importFailuresExpand(Object count) {
    return 'عرض الصفوف الفاشلة ($count)';
  }

  @override
  String get importFailuresCollapse => 'إخفاء الصفوف الفاشلة';

  @override
  String importFailureRow(Object row) {
    return 'الصف $row';
  }

  @override
  String importNewCategories(Object names) {
    return 'فئات ستُنشأ: $names';
  }

  @override
  String importNewUnits(Object names) {
    return 'وحدات ستُنشأ: $names';
  }

  @override
  String get importAckLabel => 'أقرّ بإدخال الصفوف السليمة فقط وتجاهل الفاشلة';

  @override
  String get importCommit => 'إدخال الصفوف السليمة';

  @override
  String get importCommitClean => 'إدخال كل الصفوف';

  @override
  String get importCommitting => 'جارٍ الإدخال…';

  @override
  String get importResultTitle => 'نتيجة الاستيراد';

  @override
  String importResultInserted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُدخل $count صنف',
      many: 'أُدخل $count صنفاً',
      few: 'أُدخل $count أصناف',
      two: 'أُدخل صنفان',
      one: 'أُدخل صنف واحد',
    );
    return '$_temp0';
  }

  @override
  String importResultFailed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فشل $count صف',
      many: 'فشل $count صفاً',
      few: 'فشل $count صفوف',
      two: 'فشل صفان',
      one: 'فشل صف واحد',
      zero: 'بلا صفوف فاشلة',
    );
    return '$_temp0';
  }

  @override
  String importResultCategories(Object count) {
    return 'فئات أُنشئت: $count';
  }

  @override
  String importResultUnits(Object count) {
    return 'وحدات أُنشئت: $count';
  }

  @override
  String importResultSnackbar(Object failed, Object inserted) {
    return 'أُدخل $inserted وفشل $failed';
  }

  @override
  String get importFileReadError =>
      'تعذّر قراءة الملف — تأكد أنه ملف CSV أو Excel سليم';

  @override
  String get importRestart => 'استيراد ملف آخر';

  @override
  String get categoriesUnitsTitle => 'الفئات والوحدات';

  @override
  String get categoriesSectionTitle => 'فئات الأصناف';

  @override
  String get categoriesAdd => 'إضافة فئة';

  @override
  String get categoriesEmptyTitle => 'لا فئات بعد';

  @override
  String get categoriesEmptyBody =>
      'نظّم أصنافك بفئات رئيسية وفرعية — تظهر في تصفية قائمة الأصناف.';

  @override
  String get categoriesRootBadge => 'رئيسية';

  @override
  String categoriesChildCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فرع',
      many: '$count فرعاً',
      few: '$count فروع',
      two: 'فرعان',
      one: 'فرع واحد',
    );
    return '$_temp0';
  }

  @override
  String get unitsSectionTitle => 'وحدات القياس';

  @override
  String get unitsAdd => 'إضافة وحدة';

  @override
  String get unitsEmptyTitle => 'لا وحدات بعد';

  @override
  String get unitsEmptyBody =>
      'قطعة، كرتون، كيلوغرام — مع معامل تحويل للتحويل بين الوحدات.';

  @override
  String unitFactorTimes(Object factor) {
    return '× $factor';
  }

  @override
  String get partiesTabTitle => 'الأطراف';

  @override
  String get partiesHomeHeroTitle => 'إدارة الأطراف';

  @override
  String get partiesHomeHeroSubtitle =>
      'العملاء والموردون وأرصدتهم — كل عملة على حدة، بلا خلط';

  @override
  String get partiesHubCustomers => 'العملاء';

  @override
  String get partiesHubCustomersDesc => 'ملفات العملاء وأرصدتهم وكشوف حساباتهم';

  @override
  String get partiesHubSuppliers => 'الموردون';

  @override
  String get partiesHubSuppliersDesc => 'ملفات الموردين وما عليك دفعه لهم';

  @override
  String get partiesHubReceivables => 'المبالغ المتبقية عند العملاء';

  @override
  String get partiesHubReceivablesDesc =>
      'المديونيات القائمة مرتّبة بأقدم فاتورة';

  @override
  String get partiesHubPayables => 'المبالغ المتبقية للموردين';

  @override
  String get partiesHubPayablesDesc => 'الذمم الدائنة على المنشأة بكل عملة';

  @override
  String get partiesHubRates => 'أسعار الصرف اليومية';

  @override
  String get partiesHubRatesDesc =>
      'حدّث أسعار اليوم قبل إصدار أي فاتورة بعملة غير الأساس';

  @override
  String get partiesFxChipComplete => 'أسعار اليوم مكتملة';

  @override
  String partiesFxChipMissing(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عملة بلا سعر اليوم',
      many: '$count عملة بلا سعر اليوم',
      few: '$count عملات بلا سعر اليوم',
      two: 'عملتان بلا سعر اليوم',
      one: 'عملة واحدة بلا سعر اليوم',
    );
    return '$_temp0';
  }

  @override
  String get partiesHomeEmptyTitle => 'لا أطراف بعد';

  @override
  String get partiesHomeEmptyBody =>
      'سجّل أول عميل أو مورد ليتّبع التطبيق الأرصدة وكشوف الحساب بكل عملة.';

  @override
  String get partiesHomeEmptyAction => 'تسجيل عميل';

  @override
  String partiesCountCustomers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عميل',
      many: '$count عميلاً',
      few: '$count عملاء',
      two: 'عميلان',
      one: 'عميل واحد',
      zero: 'لا عملاء بعد',
    );
    return '$_temp0';
  }

  @override
  String partiesCountSuppliers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مورد',
      many: '$count مورداً',
      few: '$count موردين',
      two: 'موردان',
      one: 'مورد واحد',
      zero: 'لا موردين بعد',
    );
    return '$_temp0';
  }

  @override
  String partiesDuesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طرف',
      many: '$count طرفاً',
      few: '$count أطراف',
      two: 'طرفان',
      one: 'طرف واحد',
      zero: 'لا أطراف',
    );
    return '$_temp0';
  }

  @override
  String get partiesListCustomersTitle => 'جميع العملاء';

  @override
  String get partiesListSuppliersTitle => 'جميع الموردين';

  @override
  String get partiesListSearchHint => 'ابحث بالاسم أو رقم الهاتف';

  @override
  String get partiesListSearchEmptyTitle => 'لا نتائج مطابقة';

  @override
  String get partiesListSearchEmptyBody => 'جرّب اسماً آخر أو امسح البحث.';

  @override
  String get partiesListEmptyCustomersTitle => 'لا عملاء بعد';

  @override
  String get partiesListEmptyCustomersBody =>
      'سجّل عملاءك ليتّبع التطبيق أرصدتهم وكشوف حساباتهم بكل عملة.';

  @override
  String get partiesListEmptySuppliersTitle => 'لا موردين بعد';

  @override
  String get partiesListEmptySuppliersBody =>
      'سجّل مورديك ليتّبع التطبيق ما عليك دفعه لهم بكل عملة.';

  @override
  String get partiesListAddCustomersAction => 'تسجيل عميل';

  @override
  String get partiesListAddSuppliersAction => 'تسجيل مورد';

  @override
  String get partiesListAddTooltip => 'إضافة';

  @override
  String get partiesFilterAll => 'الكل';

  @override
  String get partiesFilterWithBalance => 'بأرصدة';

  @override
  String get partiesFilterZeroBalance => 'بدون أرصدة';

  @override
  String get partiesFilterArchived => 'مؤرشفون';

  @override
  String get partiesArchivedBadge => 'مؤرشف';

  @override
  String get partiesBalanceLabel => 'الرصيد';

  @override
  String get partiesBalanceOwed => 'مستحق';

  @override
  String get partiesBalanceCredit => 'دائن';

  @override
  String get partiesSwipeArchiveLabel => 'أرشفة';

  @override
  String partiesArchiveConfirmTitle(Object name) {
    return 'أرشفة $name؟';
  }

  @override
  String get partiesArchiveConfirmBody =>
      'سيُستثنى من قوائم البيع والشراء الجديدة، وتبقى حركاته وأرصدته كاملة في التقارير.';

  @override
  String partiesArchiveHasMovements(Object name) {
    return 'لا يمكن أرشفة $name — له حركات مالية مسجّلة تُحفظ في تقاريره.';
  }

  @override
  String get partiesArchivedDone => 'تمت الأرشفة';

  @override
  String get partiesNoPhone => 'بلا هاتف مسجّل';

  @override
  String get partyFormAddCustomerTitle => 'تسجيل عميل جديد';

  @override
  String get partyFormEditCustomerTitle => 'تعديل بيانات العميل';

  @override
  String get partyFormAddSupplierTitle => 'تسجيل مورد جديد';

  @override
  String get partyFormEditSupplierTitle => 'تعديل بيانات المورد';

  @override
  String get partyFormNameLabel => 'الاسم بالكامل';

  @override
  String get partyFormNameHint => 'مثال: عبدالله محمد السامعي';

  @override
  String get partyFormNameRequired => 'الاسم مطلوب — أدخل الاسم ثم احفظ.';

  @override
  String get partyFormPhoneLabel => 'رقم الهاتف';

  @override
  String get partyFormWhatsappLabel => 'رقم الواتساب';

  @override
  String get partyFormWhatsappHint => 'اتركه فارغاً إن كان نفس رقم الهاتف';

  @override
  String get partyFormAddressLabel => 'العنوان';

  @override
  String get partyFormAreaLabel => 'الحي / المنطقة';

  @override
  String get partyFormCreditLimitLabel => 'حد الائتمان';

  @override
  String get partyFormCreditLimitHint => 'فارغ أو رقم';

  @override
  String get partyFormCreditLimitHelp =>
      'فارغ = بلا حد إطلاقاً · صفر = منع البيع الآجل كلياً · رقم = أقصى دَين مسموح به';

  @override
  String get partyFormCreditLimitInvalid =>
      'حد الائتمان يجب أن يكون رقماً لا يقل عن صفر — أو اتركه فارغاً.';

  @override
  String get partyFormOpeningSection => 'الرصيد الافتتاحي';

  @override
  String get partyFormOpeningAmountLabel => 'المبلغ';

  @override
  String get partyFormOpeningAmountHint => '0 إن لم يكن له رصيد سابق';

  @override
  String get partyFormOpeningAmountInvalid =>
      'الرصيد الافتتاحي يجب أن يكون رقماً موجباً.';

  @override
  String get partyFormOpeningCurrencyLabel => 'العملة';

  @override
  String get partyFormOpeningCurrencyRequired =>
      'الرصيد الافتتاحي غير الصفري يتطلب اختيار عملة.';

  @override
  String get partyFormOpeningCurrencyNone =>
      'بلا عملة — اخترها عند إدخال مبلغ غير صفري';

  @override
  String get partyFormOpeningDateLabel => 'تاريخ الرصيد';

  @override
  String get partyFormOpeningLockedNote =>
      'لهذا الطرف حركات مالية — الرصيد الافتتاحي مقفل ولا يُعدّل بعد أول حركة.';

  @override
  String get partyFormNoRateError =>
      'لا يوجد سعر صرف مسجّل لهذه العملة — سجّل سعر اليوم من شاشة «أسعار الصرف» أولاً.';

  @override
  String get partyFormNoUserError =>
      'تعذّر إتمام الحفظ — لا مستخدم مدير نشط في القاعدة.';

  @override
  String get partyFormNotesLabel => 'ملاحظات';

  @override
  String get partyFormNotesHint => 'ملاحظات داخلية لا تظهر في الفواتير';

  @override
  String get partyFormSaveLabel => 'حفظ البيانات';

  @override
  String get partyFormSavedCustomer => 'حُفظت بيانات العميل';

  @override
  String get partyFormSavedSupplier => 'حُفظت بيانات المورد';

  @override
  String get partiesCreditLimitLabel => 'حد الائتمان';

  @override
  String get partiesCreditUnlimited => 'بلا حد';

  @override
  String get partiesCreditForbidden => 'الآجل ممنوع';

  @override
  String partiesCreditLimitValue(Object amount) {
    return 'الحد $amount';
  }

  @override
  String get partyDetailInfoSection => 'بيانات الطرف';

  @override
  String get partyDetailBalancesSection => 'الأرصدة حسب العملة';

  @override
  String get partyDetailBalancesEmpty =>
      'لا أرصدة بعد — يظهر الرصيد مع أول فاتورة آجلة أو سند.';

  @override
  String get partyDetailStatementSection => 'كشف الحساب';

  @override
  String get partyDetailStatementCurrency => 'عملة الكشف';

  @override
  String get partyDetailStatementFrom => 'من تاريخ';

  @override
  String get partyDetailStatementTo => 'إلى تاريخ';

  @override
  String get partyDetailPeriodAll => 'كل الفترات';

  @override
  String get partyDetailPeriodThisMonth => 'هذا الشهر';

  @override
  String get partyDetailPeriodThisYear => 'هذه السنة';

  @override
  String get partyDetailFinalBalance => 'الرصيد النهائي';

  @override
  String get partyDetailCarryInBalance => 'رصيد ماضٍ بداية الفترة';

  @override
  String get partyDetailNoEntries => 'لا قيود بهذه العملة في الفترة المحددة.';

  @override
  String get partyDetailNotFoundTitle => 'الطرف غير موجود';

  @override
  String get partyDetailEditAction => 'تعديل البيانات';

  @override
  String get partyDetailNotFoundBody =>
      'قد يكون المعرّف خاطئاً أو محذوفاً من قاعدة البيانات.';

  @override
  String get partyDetailArchivedBanner =>
      'طرف مؤرشف — بياناته للتقارير ولا يُستخدم في عمليات جديدة.';

  @override
  String partyDetailOpeningRow(Object date) {
    return 'رصيد افتتاحي مسجّل بتاريخ $date';
  }

  @override
  String get partyDetailNotesLabel => 'ملاحظات';

  @override
  String get statementKindInvoice => 'فاتورة بيع';

  @override
  String get statementKindReceipt => 'سند قبض';

  @override
  String get statementKindSaleReturn => 'مرتجع بيع';

  @override
  String get statementKindPurchase => 'فاتورة شراء';

  @override
  String get statementKindPayment => 'سند صرف';

  @override
  String get statementKindPurchaseReturn => 'مرتجع شراء';

  @override
  String get statementKindOpening => 'رصيد افتتاحي';

  @override
  String get statementKindCarryIn => 'رصيد ماضٍ';

  @override
  String get statementBalanceColumn => 'الرصيد';

  @override
  String get statementAmountColumn => 'المبلغ';

  @override
  String get receivablesTitle => 'المبالغ المتبقية عند العملاء';

  @override
  String get payablesTitle => 'المبالغ المتبقية للموردين';

  @override
  String get receivablesEmptyTitle => 'لا مبالغ متبقية';

  @override
  String get receivablesEmptyBody => 'لا مديونيات قائمة على أي عميل حالياً.';

  @override
  String get payablesEmptyBody =>
      'لا ذمم قائمة على المنشأة تجاه أي مورد حالياً.';

  @override
  String get partiesBalancesSearchHint => 'ابحث بالاسم أو الهاتف';

  @override
  String get partiesBalancesSearchEmptyTitle => 'لا نتائج مطابقة';

  @override
  String get partiesBalancesSearchEmptyBody => 'جرّب اسماً آخر أو امسح البحث.';

  @override
  String get partiesBalancesTotalLabel => 'إجمالي المستحق';

  @override
  String partiesDaysLateChip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوماً',
      many: '$count يوماً',
      few: '$count أيام',
      two: 'يومين',
      one: 'يوم واحد',
    );
    return 'متأخر منذ $_temp0';
  }

  @override
  String partiesLastPaymentLabel(Object date) {
    return 'آخر سداد $date';
  }

  @override
  String get partiesNoMixNote =>
      'كل رصيد مقيد بعملته وحدها — طرف له أرصدة بعملتين يظهر في سطرين مستقلين ولا يُجمَع أبداً.';

  @override
  String get fxRatesTitle => 'أسعار الصرف اليومية';

  @override
  String get fxTodayCardTitle => 'أسعار اليوم';

  @override
  String fxTodayHijriDate(Object date) {
    return 'أسعار يوم $date';
  }

  @override
  String fxBaseNote(Object code) {
    return 'العملة الأساسية $code — سعرها 1 دائماً ولا يُدخل لها سعر.';
  }

  @override
  String fxAgainstBase(Object code) {
    return 'مقابل $code';
  }

  @override
  String get fxRateFieldLabel => 'سعر اليوم';

  @override
  String fxLastKnownRate(Object date, Object rate) {
    return 'آخر سعر معروف: $rate بتاريخ $date';
  }

  @override
  String get fxNoRateYet => 'لا سعر مسجّل لهذه العملة بعد';

  @override
  String get fxEnteredToday => 'مُدخل اليوم';

  @override
  String get fxMissingToday => 'بلا سعر اليوم';

  @override
  String get fxSaveLabel => 'حفظ';

  @override
  String get fxSavingLabel => 'جارٍ الحفظ…';

  @override
  String get fxRateInvalid => 'أدخل رقماً أكبر من صفر.';

  @override
  String fxRateSaved(Object code) {
    return 'حُفظ سعر اليوم لـ $code';
  }

  @override
  String get fxHistorySection => 'آخر الأسعار';

  @override
  String get fxHistoryEmpty => 'لا أسعار مسجّلة لهذه العملة بعد.';

  @override
  String get fxShowHistory => 'عرض السجل';

  @override
  String get fxHideHistory => 'إخفاء السجل';

  @override
  String get fxAllComplete => 'أسعار اليوم مكتملة لكل العملات';

  @override
  String get fxMissingWarning =>
      'إدخال اليوم ناقص — الفواتير بعملة غير الأساس تتطلب سعراً مسجّلاً لليوم';

  @override
  String get sellScreenTitle => 'فاتورة بيع جديدة';

  @override
  String get sellNewInvoiceLabel => 'فاتورة جديدة';

  @override
  String get sellClearCartTooltip => 'تفريغ السلة';

  @override
  String get sellClearCartTitle => 'تفريغ سلة الفاتورة؟';

  @override
  String get sellClearCartBody =>
      'ستُحذف كل بنود السلة الحالية ولا يمكن التراجع.';

  @override
  String get sellEmptyCartTitle => 'السلة فارغة';

  @override
  String get sellEmptyCartBody =>
      'أضف أول صنف بالبحث أو بمسح الباركود لتبدأ الفاتورة.';

  @override
  String get sellAddItem => 'إضافة صنف';

  @override
  String get sellBarcodeHint => 'امسح أو أدخل الباركود ثم اضغط Enter';

  @override
  String get sellPickCustomer => 'اختيار عميل';

  @override
  String get sellCashCustomer => 'عميل نقدي';

  @override
  String get sellCashCustomerHint => 'بيع فوري بلا حساب — الدفع نقدي كامل';

  @override
  String get sellCurrencyBaseTag => 'أساسية';

  @override
  String get sellCurrencyNoRate => 'بلا سعر اليوم';

  @override
  String sellLineAvailable(Object qty) {
    return 'المتاح: $qty';
  }

  @override
  String sellLineOverAvailable(Object qty) {
    return 'الكمية تجاوزت المتاح ($qty)';
  }

  @override
  String get sellLineTotal => 'إجمالي السطر';

  @override
  String get sellUnitPriceLabel => 'السعر';

  @override
  String sellEditPriceTitle(Object name) {
    return 'سعر وحدة: $name';
  }

  @override
  String sellLineDiscountTitle(Object name) {
    return 'خصم سطر: $name';
  }

  @override
  String get sellLineDiscountNone => 'خصم';

  @override
  String sellLineDiscountPercent(Object value) {
    return 'خصم $value%';
  }

  @override
  String sellLineDiscountAmount(Object value) {
    return 'خصم $value';
  }

  @override
  String get sellInvoiceDiscountTitle => 'خصم رأس الفاتورة';

  @override
  String get sellInvoiceDiscountButton => 'خصم الفاتورة';

  @override
  String sellInvoiceDiscountPercent(Object value) {
    return 'خصم $value%';
  }

  @override
  String sellInvoiceDiscountAmount(Object value) {
    return 'خصم $value';
  }

  @override
  String get sellDiscountAmount => 'مبلغ';

  @override
  String get sellDiscountPercent => 'نسبة ٪';

  @override
  String get sellDiscountAmountHint => 'قيمة الخصم بالمبلغ';

  @override
  String get sellDiscountPercentHint => 'نسبة الخصم من 0 إلى 100';

  @override
  String get sellDiscountAmountError => 'أدخل مبلغ خصم صالحاً لا يقل عن صفر.';

  @override
  String get sellDiscountPercentError => 'النسبة بين 0 و100 حصراً.';

  @override
  String get sellDiscountApply => 'تطبيق الخصم';

  @override
  String get sellInvalidNumber => 'أدخل رقماً صالحاً.';

  @override
  String get sellTotalsSubtotal => 'المجموع';

  @override
  String get sellTotalsLineDiscounts => 'خصومات البنود';

  @override
  String get sellTotalsInvoiceDiscount => 'خصم الفاتورة';

  @override
  String get sellTotalsGrandTotal => 'الصافي المستحق';

  @override
  String get sellPayButton => 'الدفع';

  @override
  String sellPayButtonWithTotal(Object total) {
    return 'الدفع · $total';
  }

  @override
  String get sellSaveQuotation => 'عرض سعر';

  @override
  String sellQuotationSaved(Object no) {
    return 'حُفظ عرض السعر $no';
  }

  @override
  String get sellQuotationSavedOpen => 'عروض الأسعار';

  @override
  String sellFxGateTitle(Object code) {
    return 'سعر اليوم لعملة $code';
  }

  @override
  String get sellFxGateBody =>
      'لا يُحفظ أي مستند بسعر افتراضي — أدخل سعر اليوم لهذه العملة ثم أكمل الدفع.';

  @override
  String get sellFxGateFieldLabel => 'سعر اليوم';

  @override
  String get sellFxGateFieldHelper => 'قيمة الوحدة مقابل العملة الأساسية';

  @override
  String get sellFxGateSave => 'حفظ ومتابعة';

  @override
  String get sellFxSavedAndResumed =>
      'حُفظ سعر اليوم — يمكنك إكمال الدفع الآن.';

  @override
  String get sellPayMethodCash => 'نقدي كامل';

  @override
  String get sellPayMethodCredit => 'آجل كامل';

  @override
  String get sellPayMethodMixed => 'مختلط';

  @override
  String get sellPayNetTotalLabel => 'الصافي المستحق';

  @override
  String get sellPayWalkInCustomer => 'عميل نقدي';

  @override
  String get sellPayCashFieldLabel => 'المبلغ المستلم نقداً';

  @override
  String get sellPayCashFieldHelper => 'قد يزيد عن الصافي — الفرق باقٍ للعميل';

  @override
  String get sellPayNetPaid => 'المدفوع نقداً';

  @override
  String get sellPaySettledFully => 'تسديد كامل';

  @override
  String get sellPayInvalidAmount => 'أدخل مبلغاً صالحاً.';

  @override
  String sellPayCashShort(Object total) {
    return 'النقدي أقل من الصافي ($total) — اختر الدفع المختلط أو الآجل.';
  }

  @override
  String get sellPayCreditNeedsCustomer =>
      'البيع الآجل يتطلب اختيار عميل أولاً — العميل النقدي يسدد كاملاً.';

  @override
  String sellPayMixedRange(Object total) {
    return 'في الدفع المختلط أدخل مبلغاً بين صفر والصافي ($total) حصراً.';
  }

  @override
  String get sellPayAnonymousCashOnly =>
      'العميل النقدي المجهول يسدد نقداً كاملاً فقط.';

  @override
  String get sellPayConfirm => 'تأكيد الترحيل';

  @override
  String get sellReceiptSuccessTitle => 'تم ترحيل الفاتورة';

  @override
  String get sellReceiptTotal => 'الإجمالي';

  @override
  String get sellReceiptPaidCash => 'المدفوع نقداً';

  @override
  String get sellReceiptChangeDue => 'الباقي للعميل';

  @override
  String get sellReceiptRemainingCredit => 'المتبقي آجلاً';

  @override
  String get sellReceiptNewInvoice => 'فاتورة جديدة';

  @override
  String get sellFallbackRateBadge => 'سعر صرف تقديري';

  @override
  String get sellPickerTitle => 'اختر الصنف';

  @override
  String get sellPickerSearchHint => 'ابحث بالاسم أو الباركود';

  @override
  String sellPickerBarcodeNotFound(Object code) {
    return 'لا صنف بباركود «$code»';
  }

  @override
  String get sellPickerDone => 'تم';

  @override
  String get sellPickerEmptyTitle => 'لا أصناف بعد';

  @override
  String get sellPickerEmptyBody =>
      'أضف أصنافك من وحدة المخزن ثم عُد لبيعها هنا.';

  @override
  String get sellPickerNoResultsTitle => 'لا نتائج مطابقة';

  @override
  String get sellPickerNoResultsBody => 'جرّب اسماً أو باركوداً آخر.';

  @override
  String get sellPickerOutOfStock => 'نفد المخزون';

  @override
  String sellPickerAvailable(Object qty) {
    return 'المتاح: $qty';
  }

  @override
  String get sellCustomerPickerTitle => 'عميل الفاتورة';

  @override
  String get sellCustomerPickerSearchHint => 'ابحث بالاسم أو الهاتف';

  @override
  String get sellCustomerPickerEmptyTitle => 'لا عملاء بعد';

  @override
  String get sellCustomerPickerEmptyBody =>
      'سجّل عملاءك من وحدة الأطراف لتبيع لهم بالآجل.';

  @override
  String get sellCustomerPickerNoResultsTitle => 'لا نتائج مطابقة';

  @override
  String get sellCustomerPickerNoResultsBody => 'جرّب اسماً أو هاتفاً آخر.';

  @override
  String get sellCustomerPickerFooterNote =>
      'الأرصدة تُعرض بعملاتها ولا تُخلط أبداً';

  @override
  String get sellCustomerOwes => 'مستحق عليه';

  @override
  String get sellCustomerCredit => 'رصيد دائن';

  @override
  String get sellCustomerClear => 'لا مديونية';

  @override
  String get sellHomeTitle => 'البيع';

  @override
  String get sellHomeHeroTitle => 'نقطة البيع';

  @override
  String get sellHomeTodaySales => 'مبيعات اليوم';

  @override
  String get sellHomeTodayCash => 'صافي الصندوق اليوم';

  @override
  String get sellHomeNewInvoice => 'فاتورة بيع جديدة';

  @override
  String get sellHomeNewInvoiceHint =>
      'ابدأ البيع فوراً — البحث والمسح والخصومات والدفع';

  @override
  String get sellHomeRecentInvoices => 'آخر الفواتير';

  @override
  String get sellInvoicesTitle => 'فواتير المبيعات';

  @override
  String get sellInvoicesSubtitle => 'سجل الفواتير المُرحَّلة';

  @override
  String get sellInvoicesSearchHint => 'ابحث برقم الفاتورة أو اسم العميل';

  @override
  String get sellInvoicesEmptyTitle => 'لا فواتير بعد';

  @override
  String get sellInvoicesEmptyBody =>
      'رحّل أول فاتورة بيع لتظهر هنا ببنودها وحالة دفعها.';

  @override
  String get sellInvoicesNoResultsTitle => 'لا نتائج مطابقة';

  @override
  String get sellInvoicesNoResultsBody => 'جرّب رقماً أو اسماً آخر.';

  @override
  String get sellInvoicesPaidLabel => 'المدفوع';

  @override
  String get sellInvoicesDueLabel => 'المتبقي';

  @override
  String get sellInvoicesTotalLabel => 'الإجمالي';

  @override
  String get sellInvoiceDetailTitle => 'تفاصيل الفاتورة';

  @override
  String get sellInvoiceNotFoundTitle => 'الفاتورة غير موجودة';

  @override
  String get sellInvoiceNotFoundBody => 'ربما حُذفت أو الرابط غير صحيح.';

  @override
  String get sellDetailCustomer => 'العميل';

  @override
  String get sellDetailPhone => 'الهاتف';

  @override
  String get sellDetailCurrency => 'العملة';

  @override
  String get sellDetailExchangeRate => 'سعر الصرف المطبَّق';

  @override
  String get sellDetailItemsSection => 'بنود الفاتورة';

  @override
  String get sellDetailUnknownItem => 'صنف محذوف';

  @override
  String get sellDetailQtyLabel => 'كمية';

  @override
  String get sellDetailDiscountLabel => 'خصم';

  @override
  String get sellDetailTotalDiscount => 'إجمالي الخصم';

  @override
  String get sellQuotationsTitle => 'عروض الأسعار';

  @override
  String get sellQuotationsSubtitle => 'عروض قابلة للتحويل لفواتير';

  @override
  String get sellQuotationsEmptyTitle => 'لا عروض أسعار بعد';

  @override
  String get sellQuotationsEmptyBody =>
      'احفظ سلة البيع كعرض سعر لتراجعه لاحقاً قبل الترحيل.';

  @override
  String get sellQuotationFilterAll => 'الكل';

  @override
  String get sellQuotationStatusDraft => 'مسودة';

  @override
  String get sellQuotationStatusSent => 'مُرسَل';

  @override
  String get sellQuotationStatusConverted => 'مُحوَّل';

  @override
  String get sellQuotationStatusExpired => 'منتهي';

  @override
  String get sellQuotationStatusCancelled => 'ملغى';

  @override
  String sellQuotationValidUntil(Object date) {
    return 'صالح حتى $date';
  }

  @override
  String get sellQuotationValidUntilLabel => 'صالح حتى';

  @override
  String get sellQuotationMarkSent => 'تعليم مُرسَل';

  @override
  String get sellQuotationCancel => 'إلغاء';

  @override
  String get sellQuotationCancelConfirmTitle => 'إلغاء عرض السعر؟';

  @override
  String sellQuotationCancelConfirmBody(Object no) {
    return 'سيُلغى العرض $no ولن يقبل التحويل إلى فاتورة.';
  }

  @override
  String sellQuotationConvertedTo(Object id) {
    return 'حوِّل إلى الفاتورة رقم $id';
  }

  @override
  String get sellQuotationDetailTitle => 'تفاصيل العرض';

  @override
  String get sellQuotationNotFoundTitle => 'العرض غير موجود';

  @override
  String get sellQuotationNotFoundBody => 'ربما أُلغي أو الرابط غير صحيح.';

  @override
  String get sellQuotationRateLabel => 'السعر وقت الإنشاء';

  @override
  String get sellQuotationNetTotal => 'صافي العرض';

  @override
  String get sellQuotationPrintedNotes => 'ملاحظة تُطبع';

  @override
  String get sellQuotationConvertButton => 'تحويل إلى فاتورة';

  @override
  String get sellQuotationConvertedMessage =>
      'حوِّل العرض إلى فاتورة مُرحَّلة بنجاح.';

  @override
  String get sellQuotationSentMessage => 'عُلِّم العرض كمُرسَل.';

  @override
  String get purHomeTitle => 'المشتريات';

  @override
  String get purHubSubtitle => 'شراء جديد ومرتجعات ومحرك WAC';

  @override
  String get purHomeHeroTitle => 'الشراء والوارد';

  @override
  String get purHomeTodayCount => 'فواتير شراء اليوم';

  @override
  String get purHomeTodayTotal => 'قيمة مشتريات اليوم';

  @override
  String get purHomeNewInvoice => 'فاتورة شراء جديدة';

  @override
  String get purHomeNewInvoiceHint =>
      'أدخل الوارد بتكلفته ودفعة صلاحيته — الترحيل يحدّث متوسط التكلفة';

  @override
  String get purHomeRecent => 'آخر المشتريات';

  @override
  String get purInvoicesTitle => 'فواتير المشتريات';

  @override
  String get purInvoicesSubtitle => 'سجل فواتير PUR المُرحَّلة';

  @override
  String get purInvoicesSearchHint => 'ابحث برقم الفاتورة أو اسم المورد';

  @override
  String get purInvoicesEmptyTitle => 'لا مشتريات بعد';

  @override
  String get purInvoicesEmptyBody =>
      'رحّل أول فاتورة شراء ليظهر الوارد في المخزون وتتحدث التكلفة.';

  @override
  String get purInvoicesNoResultsTitle => 'لا نتائج مطابقة';

  @override
  String get purInvoicesNoResultsBody => 'جرّب رقماً أو اسم مورد آخر.';

  @override
  String get purInvoicesPaidLabel => 'المدفوع';

  @override
  String get purInvoicesDueLabel => 'المتبقي';

  @override
  String get purInvoicesTotalLabel => 'الإجمالي';

  @override
  String get purDetailTitle => 'تفاصيل فاتورة الشراء';

  @override
  String get purDetailNotFoundTitle => 'الفاتورة غير موجودة';

  @override
  String get purDetailNotFoundBody => 'ربما حُذفت أو الرابط غير صحيح.';

  @override
  String get purDetailSupplier => 'المورد';

  @override
  String get purDetailStockValue => 'قيمة الوارد بالتكلفة';

  @override
  String get purDetailStockValueNote =>
      'بالعملة الأساسية — أساس متوسط التكلفة المرجّح';

  @override
  String get purDetailReturnAction => 'إرجاع للمورد (مرتجع شراء)';

  @override
  String get purSupplierRequired => 'اختر المورد';

  @override
  String get purSupplierOwes => 'مستحق له';

  @override
  String get purSupplierCredit => 'رصيد لنا لديه';

  @override
  String get purSupplierPickerTitle => 'مورد الفاتورة';

  @override
  String get purSupplierPickerSearchHint => 'ابحث بالاسم أو الهاتف';

  @override
  String get purSupplierPickerEmptyTitle => 'لا موردين بعد';

  @override
  String get purSupplierPickerEmptyBody =>
      'سجّل مورديك من وحدة الأطراف لتشتري منهم.';

  @override
  String get purSupplierPickerNoResultsTitle => 'لا نتائج مطابقة';

  @override
  String get purSupplierPickerNoResultsBody => 'جرّب اسماً أو هاتفاً آخر.';

  @override
  String get purScreenTitle => 'فاتورة شراء جديدة';

  @override
  String get purNewInvoiceLabel => 'رقم PUR القادم';

  @override
  String get purPickSupplier => 'اختيار المورد';

  @override
  String get purClearCartTooltip => 'تفريغ الفاتورة';

  @override
  String get purClearCartTitle => 'تفريغ فاتورة الشراء؟';

  @override
  String get purClearCartBody =>
      'ستُحذف البنود غير المُرحَّلة ولن يُكتب شيء في القاعدة.';

  @override
  String get purEmptyCartTitle => 'الفاتورة فارغة';

  @override
  String get purEmptyCartBody =>
      'أضف أصناف الوارد بتكلفة الشراء — الدفعات تُنشأ لكل بند متتبع بصلاحيته.';

  @override
  String get purAddItem => 'إضافة صنف';

  @override
  String purLineStock(Object qty) {
    return 'المتوفر حالياً: $qty';
  }

  @override
  String get purUnitCostLabel => 'التكلفة';

  @override
  String purEditCostTitle(Object name) {
    return 'تكلفة الوحدة: $name';
  }

  @override
  String get purIncomingBatchTitle => 'الدفعة الواردة';

  @override
  String get purBatchNoHint => 'رقم دفعة المورد';

  @override
  String get purExpiryPick => 'حدد تاريخ الصلاحية';

  @override
  String purExpiryValue(Object date) {
    return 'تنتهي $date';
  }

  @override
  String get purExpiryQuickMonth => '+30 يوماً';

  @override
  String get purExpiryQuick3Months => '+90 يوماً';

  @override
  String get purExpiryQuick6Months => '+180 يوماً';

  @override
  String get purExpiryQuickYear => '+سنة';

  @override
  String get purExpiryDialogTitle => 'تاريخ انتهاء الصلاحية';

  @override
  String get purInvoiceDiscountButton => 'خصم الفاتورة';

  @override
  String get purInvoiceDiscountTitle => 'خصم رأس فاتورة الشراء';

  @override
  String get purPayButton => 'ترحيل الشراء';

  @override
  String purPayButtonWithTotal(Object total) {
    return 'الدفع · $total';
  }

  @override
  String get purPayCashFieldLabel => 'المبلغ المدفوع للمورد نقداً';

  @override
  String get purPayCashFieldHelper => 'يخرج من الصندوق — لا يزيد عن الصافي';

  @override
  String purPayCashShort(Object total) {
    return 'النقدي أقل من الصافي ($total) — اختر المختلط أو الآجل.';
  }

  @override
  String purPayMixedRange(Object total) {
    return 'في الدفع المختلط أدخل مبلغاً بين صفر والصافي ($total) حصراً.';
  }

  @override
  String get purPayConfirm => 'تأكيد ترحيل الشراء';

  @override
  String get purReceiptSuccessTitle => 'تم ترحيل فاتورة الشراء';

  @override
  String get purReceiptSupplierCredit => 'المتبقي آجلاً (دين للمورد)';

  @override
  String get purReceiptNewInvoice => 'شراء جديد';

  @override
  String get purPickerTitle => 'اختر الصنف للشراء';

  @override
  String get purPickerSearchHint => 'ابحث بالاسم أو الباركود';

  @override
  String get purPickerEmptyTitle => 'لا أصناف بعد';

  @override
  String get purPickerEmptyBody =>
      'أضف أصنافك من وحدة المخزن ثم اشترِ الوارد هنا.';

  @override
  String purPickerAvailable(Object qty) {
    return 'المتوفر: $qty';
  }

  @override
  String purPickerLastCost(Object cost) {
    return 'آخر تكلفة: $cost';
  }

  @override
  String get retSaleTitle => 'مرتجع بيع';

  @override
  String get retSaleSubtitle => 'إرجاع مبيعات بمرتجع SRN';

  @override
  String get retPurchaseTitle => 'مرتجع شراء';

  @override
  String get retPurchaseSubtitle => 'إرجاع وارد للمورد بمرتجع PRN';

  @override
  String get retPickInvoiceSearchHint => 'ابحث برقم الفاتورة أو اسم العميل';

  @override
  String get retPickPurchaseSearchHint => 'ابحث برقم PUR أو اسم المورد';

  @override
  String get retPickInvoiceEmptyTitle => 'لا فواتير مكتملة';

  @override
  String get retPickInvoiceEmptyBody =>
      'المرتجع يرتبط بفاتورة أصلية مكتملة حصراً — لا مرتجع حر.';

  @override
  String get retPickInvoiceNoResultsTitle => 'لا نتائج مطابقة';

  @override
  String get retPickInvoiceNoResultsBody => 'جرّب رقماً أو اسماً آخر.';

  @override
  String get retChangeInvoice => 'تغيير الفاتورة';

  @override
  String get retLinesTitle => 'البنود القابلة للإرجاع';

  @override
  String get retNoLinesTitle => 'لا بنود قابلة للإرجاع';

  @override
  String get retNoLinesBody => 'ربما أُرجعت كل كميات هذه الفاتورة سابقاً.';

  @override
  String retOriginalQty(Object qty) {
    return 'الأصلية: $qty';
  }

  @override
  String retReturnedQty(Object qty) {
    return 'أُرجع سابقاً: $qty';
  }

  @override
  String retAvailableQty(Object qty) {
    return 'المتاح للإرجاع: $qty';
  }

  @override
  String get retQtyLabel => 'كمية الإرجاع';

  @override
  String get retLineRefundLabel => 'قيمة الرد';

  @override
  String get retRefundTotalLabel => 'قيمة المرتجع';

  @override
  String get retRefundCash => 'رد نقدي';

  @override
  String get retRefundCredit => 'خصم من الحساب';

  @override
  String get retRefundCashOnlyNote =>
      'الفاتورة الأصلية بعميل نقدي مجهول — الرد نقداً من الصندوق حصراً.';

  @override
  String get retRefundCashFieldLabel => 'المبلغ المردود نقداً';

  @override
  String retRefundCashShort(Object total) {
    return 'النقدي أقل من قيمة المرتجع ($total) — اختر الخصم من الحساب أو المختلط.';
  }

  @override
  String retRefundMixedRange(Object total) {
    return 'في الرد المختلط أدخل مبلغاً بين صفر وقيمة المرتجع ($total) حصراً.';
  }

  @override
  String get retPostButton => 'ترحيل المرتجع';

  @override
  String get retNewReturn => 'مرتجع جديد';

  @override
  String get retReceiptSuccessTitle => 'تم ترحيل المرتجع';

  @override
  String retReceiptOriginal(Object no) {
    return 'عن الفاتورة الأصلية $no';
  }

  @override
  String get retReceiptRefundCash => 'المردود نقداً';

  @override
  String get retReceiptRefundCredit => 'المخصوم من الحساب';

  @override
  String get cashHomeTitle => 'النقدية';

  @override
  String get cashHomeHeroTitle => 'صافي النقدية';

  @override
  String get cashHomeHeroHint => 'سطر لكل عملة — لا تُخلط العملات';

  @override
  String get cashHomeEmptyTitle => 'لا حركات نقدية بعد';

  @override
  String get cashHomeEmptyBody =>
      'ابدأ من أزرار الوصول السريع بالأسفل — كل حركة تُسجَّل فوراً هنا.';

  @override
  String get cashHomeBoxesSection => 'الصناديق';

  @override
  String get cashHomeNoBoxesTitle => 'لا صناديق بعد';

  @override
  String get cashHomeNoBoxesBody =>
      'أنشئ صندوقاً من إدارة الصناديق لبدء تتبع النقدية.';

  @override
  String get cashHomeRecentSection => 'آخر الحركات';

  @override
  String get cashHomeManageBoxes => 'إدارة الصناديق';

  @override
  String get cashDefaultChip => 'افتراضي';

  @override
  String get cashNegativeBalance => 'رصيد سالب';

  @override
  String get cashQuickReceiptVoucher => 'سند قبض';

  @override
  String get cashQuickPaymentVoucher => 'سند صرف';

  @override
  String get cashQuickExpense => 'مصروف';

  @override
  String get cashQuickOwnerDraw => 'مسحوبات المالك';

  @override
  String get cashQuickCapitalIn => 'إيداع مالك';

  @override
  String get cashQuickTransfer => 'تحويل';

  @override
  String get cashQuickBank => 'بنكي';

  @override
  String get cashQuickBoxes => 'الصناديق';

  @override
  String get cashQuickMovements => 'الحركات';

  @override
  String get cashQuickCategories => 'الفئات';

  @override
  String get cashQmSheetTitle => 'حركة نقدية';

  @override
  String get cashQmKindExpense => 'مصروف';

  @override
  String get cashQmKindOwnerDraw => 'مسحوبات مالك';

  @override
  String get cashQmKindCapitalIn => 'إيداع مالك';

  @override
  String get cashQmKindTransfer => 'تحويل';

  @override
  String get cashQmKindBankDeposit => 'إيداع بنكي';

  @override
  String get cashQmKindBankWithdraw => 'سحب بنكي';

  @override
  String get cashQmAmountLabel => 'المبلغ';

  @override
  String get cashQmAmountHint => 'بعملة الصندوق المصدر';

  @override
  String get cashQmSourceBoxLabel => 'من صندوق';

  @override
  String get cashQmTargetBoxLabel => 'إلى صندوق';

  @override
  String get cashQmDateLabel => 'التاريخ';

  @override
  String get cashQmCategoryLabel => 'فئة المصروف';

  @override
  String get cashQmCategoryHint => 'إلزامية للمصروف حصراً';

  @override
  String get cashQmDescriptionLabel => 'الوصف';

  @override
  String get cashQmDescriptionHint => 'اختياري — يظهر في سجل الحركات';

  @override
  String get cashQmProjectedSource => 'رصيد المصدر بعد الحركة';

  @override
  String get cashQmNegativeWarning =>
      'سيصبح رصيد المصدر سالباً بعد هذه الحركة — التسجيل مسموح والتنبيه للعلم فقط.';

  @override
  String cashQmArrivesAtTarget(Object amount, Object box, Object code) {
    return 'يصل إلى «$box»: $amount $code';
  }

  @override
  String get cashQmSave => 'ترحيل الحركة';

  @override
  String get cashQmReceiptTitle => 'تمت الحركة بنجاح';

  @override
  String get cashQmReceiptArrived => 'وصل للهدف';

  @override
  String get cashQmNewMovement => 'حركة أخرى';

  @override
  String get cashQmNoBoxesTitle => 'لا صناديق بعد';

  @override
  String get cashQmNoBoxesBody =>
      'أنشئ صندوقاً أولاً من «الصناديق» ثم عد للحركة.';

  @override
  String get cashVoucherReceiptTitle => 'سند قبض';

  @override
  String get cashVoucherReceiptSubtitle => 'تحصيل من عميل — برقم RVT';

  @override
  String get cashVoucherPaymentTitle => 'سند صرف';

  @override
  String get cashVoucherPaymentSubtitle => 'دفع لمورد — برقم PMT';

  @override
  String get cashVoucherPartySection => 'الطرف';

  @override
  String get cashVoucherPickParty => 'اختر الطرف';

  @override
  String get cashVoucherChangeParty => 'تغيير الطرف';

  @override
  String get cashVoucherPartyBalance => 'رصيد الطرف';

  @override
  String get cashVoucherAmountSection => 'المبلغ والعملة';

  @override
  String get cashVoucherCurrencyLabel => 'عملة السند';

  @override
  String get cashVoucherBoxSection => 'الصندوق والتاريخ';

  @override
  String get cashVoucherAllocationSection => 'التخصيص';

  @override
  String get cashVoucherAllocFifo => 'تخصيص FIFO';

  @override
  String get cashVoucherAllocOnAccount => 'على الحساب';

  @override
  String get cashVoucherOpenDuesTotal => 'مديونية مفتوحة';

  @override
  String get cashVoucherOpenRemaining => 'المتبقي';

  @override
  String get cashVoucherNoOpenDues =>
      'لا مديونية مفتوحة بعملة السند لهذا الطرف — اختر «على الحساب» أو غيّر العملة.';

  @override
  String get cashVoucherPlanTitle => 'سيُخصص على';

  @override
  String get cashVoucherUnallocated => 'الباقي على الحساب';

  @override
  String get cashVoucherLoadingInvoices => 'تحميل الفواتير المفتوحة…';

  @override
  String cashVoucherCrossDeposit(Object amount, Object code) {
    return 'يودع في الصندوق: $amount $code';
  }

  @override
  String get cashVoucherNotesLabel => 'ملاحظات';

  @override
  String get cashVoucherNotesHint => 'اختياري — تُحفظ مع السند';

  @override
  String get cashVoucherPost => 'ترحيل السند';

  @override
  String cashVoucherPostedSnackBar(Object amount, Object code, Object no) {
    return 'تم ترحيل السند $no بمبلغ $amount $code';
  }

  @override
  String get cashVoucherPickerTitle => 'اختيار الطرف';

  @override
  String get cashVoucherPickerSearchHint => 'ابحث بالاسم أو الهاتف';

  @override
  String get cashVoucherPickerEmptyTitle => 'لا أطراف بعد';

  @override
  String get cashVoucherPickerEmptyBody =>
      'سجّل العملاء أو الموردين في وحدة الأطراف أولاً ثم عد لترحيل السند.';

  @override
  String get cashVoucherPickerNoResultsTitle => 'لا نتائج مطابقة';

  @override
  String get cashVoucherPickerNoResultsBody => 'جرب اسماً أو هاتفاً آخر.';

  @override
  String get cashVoucherPartyOwesYou => 'مدين لك';

  @override
  String get cashVoucherPartyWeOwe => 'ندين له';

  @override
  String get cashVoucherPartyCredit => 'رصيد دائن';

  @override
  String get cashMovementsTitle => 'سجل حركات الصندوق';

  @override
  String get cashMovementsSearchHint => 'ابحث في البيان أو رقم السند أو الطرف';

  @override
  String get cashMovementsAllBoxes => 'كل الصناديق';

  @override
  String get cashMovementsAllTypes => 'كل الأنواع';

  @override
  String get cashMovementsPeriodAll => 'الكل';

  @override
  String get cashMovementsPeriodToday => 'اليوم';

  @override
  String get cashMovementsPeriodWeek => '٧ أيام';

  @override
  String get cashMovementsPeriodMonth => 'الشهر';

  @override
  String get cashMovementsEmptyTitle => 'لا حركات بعد';

  @override
  String get cashMovementsEmptyBody =>
      'كل حركة نقدية — سنداً أو مصروفاً أو تحويلاً — تظهر هنا فور ترحيلها.';

  @override
  String get cashMovementsNoResultsTitle => 'لا نتائج مطابقة';

  @override
  String get cashMovementsNoResultsBody =>
      'غيّر الصندوق أو النوع أو الفترة أو البحث.';

  @override
  String get cashMovementsVoidedChip => 'ملغاة';

  @override
  String get cashMovementsReversalChip => 'سطر إبطال';

  @override
  String get cashTypeReceipt => 'قبض';

  @override
  String get cashTypePayment => 'صرف';

  @override
  String get cashTypeExpense => 'مصروف';

  @override
  String get cashTypeOwnerDraw => 'مسحوبات مالك';

  @override
  String get cashTypeCapitalIn => 'إيداع مالك';

  @override
  String get cashTypeBoxTransfer => 'تحويل';

  @override
  String get cashTypeBankDeposit => 'إيداع بنكي';

  @override
  String get cashTypeBankWithdraw => 'سحب بنكي';

  @override
  String get cashTypeOpening => 'رصيد افتتاحي';

  @override
  String get cashMovementDetailTitle => 'تفاصيل الحركة';

  @override
  String get cashMovementFieldDate => 'التاريخ';

  @override
  String get cashMovementFieldBox => 'الصندوق';

  @override
  String get cashMovementFieldTo => 'إلى';

  @override
  String get cashMovementFieldVoucher => 'رقم السند';

  @override
  String get cashMovementFieldParty => 'الطرف';

  @override
  String get cashMovementFieldCategory => 'الفئة';

  @override
  String get cashMovementFieldRate => 'سعر الصرف';

  @override
  String get cashMovementFieldSettlement => 'سعر التحويل';

  @override
  String get cashMovementFieldFx => 'فرق الصرف';

  @override
  String get cashMovementFieldDescription => 'البيان';

  @override
  String get cashMovementAllocationsTitle => 'التخصيصات';

  @override
  String get cashAllocSaleInvoice => 'فاتورة بيع';

  @override
  String get cashAllocPurchaseInvoice => 'فاتورة شراء';

  @override
  String get cashMovementVoidButton => 'إبطال الحركة';

  @override
  String get cashMovementVoidTitle => 'إبطال هذه الحركة؟';

  @override
  String get cashMovementVoidBody =>
      'الإبطال لا يحذف السجل: تُنشأ حركة معاكسة داخل معاملة واحدة تعيد كل الأرصدة كما كانت، ويبقى الأصل في السجل بعلامة «ملغاة». الرقم المرقّم لا يُعاد استخدامه أبداً.';

  @override
  String get cashMovementVoidReasonLabel => 'سبب الإبطال (اختياري)';

  @override
  String get cashMovementVoidConfirm => 'إبطال نهائي';

  @override
  String get cashMovementVoidedSnackBar =>
      'أُبطلت الحركة وسُجِّل السطر المعاكس.';

  @override
  String get cashMovementNotVoidableNote =>
      'هذه الحركة مرتبطة بمستند آخر (تحصيل فاتورة أو رد مرتجع) — تُبطل من مستندها الأصلي لا من هنا.';

  @override
  String get cashBoxesTitle => 'إدارة الصناديق';

  @override
  String get cashBoxesAddBox => 'صندوق جديد';

  @override
  String get cashBoxesEmptyTitle => 'لا صناديق بعد';

  @override
  String get cashBoxesEmptyBody =>
      'أنشئ صندوقاً لكل عملة أو وعاء نقد تتعامل معه — البنك مجرد صندوق باسم بنك.';

  @override
  String get cashBoxesArchivedSection => 'صناديق مؤرشفة';

  @override
  String get cashBoxesSetDefault => 'تعيين افتراضياً';

  @override
  String get cashBoxesEditTooltip => 'تعديل الصندوق';

  @override
  String get cashBoxesArchiveTooltip => 'أرشفة الصندوق';

  @override
  String get cashBoxesUnarchiveTooltip => 'إلغاء الأرشفة';

  @override
  String cashBoxesArchiveTitle(Object name) {
    return 'أرشفة «$name»؟';
  }

  @override
  String get cashBoxesArchiveBody =>
      'يختفي الصندوق من الشاشات اليومية ويبقى تاريخه كاملاً في سجل الحركات.';

  @override
  String cashBoxesArchiveNonZeroTitle(Object name) {
    return 'رصيد «$name» ليس صفراً';
  }

  @override
  String get cashBoxesArchiveNonZeroBody =>
      'رصيد الصندوق غير الصفري يبقى محسوباً في صافي النقدية بعد الأرشفة. الأفضل تصفير الرصيد أولاً — أو أكّد الأرشفة صراحةً.';

  @override
  String get cashBoxesArchiveForce => 'أرشفة مع بقاء الرصيد';

  @override
  String cashBoxesDefaultDone(Object name) {
    return 'أصبح «$name» هو الصندوق الافتراضي.';
  }

  @override
  String get cashBoxFormNewTitle => 'صندوق جديد';

  @override
  String get cashBoxFormEditTitle => 'تعديل الصندوق';

  @override
  String get cashBoxFormNameLabel => 'اسم الصندوق';

  @override
  String get cashBoxFormNameHint => 'مثال: الدرج الرئيسي، بنك التوفير';

  @override
  String get cashBoxFormCurrencyLabel => 'عملة الصندوق';

  @override
  String get cashBoxFormCurrencyLocked =>
      'عملة الصندوق تُحدَّد عند الإنشاء ولا تتغير بعده — عدّل الاسم أو الافتراضية فقط.';

  @override
  String get cashBoxFormMakeDefault => 'صندوق افتراضي';

  @override
  String get cashBoxFormMakeDefaultHint => 'تفتحه نماذج النقدية تلقائياً';

  @override
  String get cashBoxFormSave => 'حفظ الصندوق';

  @override
  String get cashBoxFormSaved => 'حُفظ الصندوق بنجاح.';

  @override
  String get cashBoxFormNotFound => 'الصندوق المطلوب غير موجود.';

  @override
  String get cashCategoriesTitle => 'فئات المصاريف';

  @override
  String get cashCategoriesAdd => 'فئة جديدة';

  @override
  String get cashCategoriesNameLabel => 'اسم الفئة';

  @override
  String get cashCategoriesNameHint => 'مثال: كهرباء، إيجار، نقل';

  @override
  String get cashCategoriesAddButton => 'إضافة';

  @override
  String get cashCategoriesEmptyTitle => 'لا فئات بعد';

  @override
  String get cashCategoriesEmptyBody =>
      'الفئات تصنّف المصاريف لتقارير لاحقة — فئة «رواتب» محمية نظامياً.';

  @override
  String get cashCategoriesProtected => 'محمية';

  @override
  String get cashCategoriesProtectedTooltip => 'فئة نظامية لا تُؤرشف';

  @override
  String get cashCategoriesRename => 'إعادة تسمية';

  @override
  String get cashCategoriesRenameTitle => 'إعادة تسمية الفئة';

  @override
  String get cashCategoriesArchive => 'أرشفة';

  @override
  String cashCategoriesArchiveTitle(Object name) {
    return 'أرشفة «$name»؟';
  }

  @override
  String get cashCategoriesArchiveBody =>
      'تختفي من منتقي المصاريف الجديدة ويبقى تاريخها في سجل الحركات.';

  @override
  String get cashCategoriesUnarchive => 'إلغاء الأرشفة';

  @override
  String get cashCategoriesArchivedSection => 'فئات مؤرشفة';

  @override
  String get printingPdfTooltip => 'طباعة PDF';

  @override
  String get printingPreviewTitle => 'معاينة الطباعة';

  @override
  String printingPreviewFileSize(int sizeKb) {
    return 'الحجم: $sizeKb ك.ب';
  }

  @override
  String get printingPrint => 'طباعة';

  @override
  String get printingShare => 'مشاركة';

  @override
  String get printingWhatsApp => 'واتساب';

  @override
  String get printingClose => 'إغلاق';

  @override
  String get printingBuildError => 'تعذّر تجهيز المستند';

  @override
  String get printingBuildErrorBody =>
      'لم يكتمل توليد ملف PDF. أعد المحاولة أو أغلق النافذة وافتح المستند من جديد.';

  @override
  String get printingPrintFailed => 'تعذّر فتح حوار الطباعة';

  @override
  String get printingShareFailed => 'تعذّر فتح المشاركة';

  @override
  String get printingWhatsAppFailed => 'تعذّر فتح واتساب';

  @override
  String get printingInvoiceDocTitle => 'فاتورة مبيعات';

  @override
  String get printingVoucherReceiptTitle => 'سند قبض';

  @override
  String get printingVoucherPaymentTitle => 'سند صرف';

  @override
  String get printingLblCustomer => 'العميل';

  @override
  String get printingLblParty => 'الطرف';

  @override
  String get printingLblAmount => 'المبلغ';

  @override
  String get printingLblDate => 'التاريخ';

  @override
  String get printingLblCurrency => 'العملة';

  @override
  String get printingLblItem => 'الصنف';

  @override
  String get printingLblQty => 'كمية';

  @override
  String get printingLblPrice => 'السعر';

  @override
  String get printingLblDiscount => 'خصم';

  @override
  String get printingLblSubtotal => 'الإجمالي قبل الخصم';

  @override
  String get printingLblTotalDiscount => 'إجمالي الخصم';

  @override
  String get printingLblGrandTotal => 'الإجمالي';

  @override
  String get printingLblPaid => 'المدفوع';

  @override
  String get printingLblDue => 'المتبقي';

  @override
  String get printingLblItemsSection => 'البنود';

  @override
  String get printingLblDescription => 'البيان';

  @override
  String get printingLblBox => 'الصندوق';

  @override
  String get printingLblSignature => 'التوقيع';

  @override
  String get printingFooterThanks => 'شكراً لتعاملكم معنا';

  @override
  String get printingCashCustomer => 'عميل نقدي';

  @override
  String printingShareMessageInvoice(Object docNo, Object total) {
    return 'فاتورة $docNo بإجمالي $total';
  }

  @override
  String printingShareMessageVoucher(Object amount, Object voucherNo) {
    return 'سند $voucherNo بمبلغ $amount';
  }

  @override
  String get printingVoucherPdfButton => 'طباعة السند PDF';

  @override
  String get printingStatementDocTitle => 'كشف حساب';

  @override
  String get printingLblGeneratedAt => 'تاريخ الإصدار';

  @override
  String get printingLblPeriod => 'الفترة';

  @override
  String printingStatementPeriodRange(Object from, Object to) {
    return 'من $from إلى $to';
  }

  @override
  String get printingStatementDebit => 'مدين';

  @override
  String get printingStatementCredit => 'دائن';

  @override
  String get printingStatementBalance => 'الرصيد';

  @override
  String get printingStatementTotalDebit => 'إجمالي المدين';

  @override
  String get printingStatementTotalCredit => 'إجمالي الدائن';

  @override
  String get printingStatementClosing => 'الرصيد الختامي';

  @override
  String get printingStatementEmpty => 'لا قيود في هذه الفترة';

  @override
  String printingShareMessageStatement(Object balance, Object party) {
    return 'كشف حساب $party — الرصيد الختامي $balance';
  }

  @override
  String get backupScreenTitle => 'النسخ الاحتياطي والاستعادة';

  @override
  String get backupWebPreviewTitle => 'معاينة ويب';

  @override
  String get backupWebPreviewBody =>
      'بيانات هذه المعاينة داخل متصفحك، والنسخ الاحتياطي الفعلي — إنشاءً واستعادةً ومشاركةً للملف — متاح في تطبيق أندرويد.';

  @override
  String get backupLastBackupLabel => 'آخر نسخة ناجحة';

  @override
  String get backupLastNever => 'لم تُنشأ أي نسخة بعد';

  @override
  String get backupSavedCountLabel => 'نسخ محفوظة';

  @override
  String get backupCreateNow => 'إنشاء نسخة الآن';

  @override
  String get backupCreating => 'جارٍ إنشاء النسخة…';

  @override
  String get backupCreateHint =>
      'ملف واحد مضغوط مؤرَّخ بالتاريخ والوقت يُحفظ في مجلد نسخ التطبيق';

  @override
  String backupCreateSuccess(String fileName) {
    return 'تم إنشاء النسخة: $fileName';
  }

  @override
  String get backupCreateFailed => 'تعذّر إنشاء النسخة الاحتياطية';

  @override
  String get backupScheduleTitle => 'الجدولة التلقائية';

  @override
  String get backupScheduleDesc =>
      'نسخة تلقائية صامتة عند فتح التطبيق متى مضى الوقت المحدد';

  @override
  String get backupScheduleDaily => 'يومي';

  @override
  String get backupScheduleWeekly => 'أسبوعي';

  @override
  String get backupScheduleOff => 'إيقاف';

  @override
  String get backupRetentionTitle => 'الاحتفاظ بالنسخ';

  @override
  String backupRetentionDesc(int count) {
    return 'يُحتفظ بآخر $count نسخة وتُحذف الأقدم تلقائياً';
  }

  @override
  String get backupLogTitle => 'سجل النسخ';

  @override
  String get backupLogEmptyTitle => 'لا نسخ بعد';

  @override
  String get backupLogEmptyBody =>
      'أنشئ أول نسخة احتياطية بضغطة واحدة — ملف واحد يحمل كل بياناتك.';

  @override
  String get backupKindManual => 'يدوية';

  @override
  String get backupKindAuto => 'تلقائية';

  @override
  String get backupKindSafety => 'أمان قبل الاستعادة';

  @override
  String get backupKindGeneric => 'نسخة';

  @override
  String get backupStatusOk => 'ناجحة';

  @override
  String get backupStatusFailed => 'فاشلة';

  @override
  String get backupFileMissing => 'الملف محذوف';

  @override
  String get backupRestoreTooltip => 'استعادة هذه النسخة';

  @override
  String get backupShareTooltip => 'مشاركة الملف';

  @override
  String get backupRestoreFromFile => 'استعادة من ملف خارجي';

  @override
  String get backupRestoreFromFileDesc =>
      'اختر ملف .finbak وصلك بالمشاركة أو بنسخ يدوي';

  @override
  String backupSizeKb(String value) {
    return '$value ك.ب';
  }

  @override
  String backupSizeMb(String value) {
    return '$value م.ب';
  }

  @override
  String get backupShareFailed => 'تعذّرت مشاركة الملف';

  @override
  String get backupSettingSaveFailed => 'تعذّر حفظ الإعداد';

  @override
  String get backupRestoreDialogTitle => 'استعادة نسخة احتياطية';

  @override
  String get backupRestoreWarnBody =>
      'سيستبدل هذا كل البيانات الحالية ببيانات النسخة. تُنشأ نسخة أمان من بياناتك الحالية تلقائياً قبل الاستبدال.';

  @override
  String get backupRestoreConfirm => 'استبدال البيانات';

  @override
  String get backupRestoreRunning => 'جارٍ الاستعادة…';

  @override
  String get backupRestoreSuccessTitle => 'تمت الاستعادة بنجاح';

  @override
  String get backupRestoreSuccessBody =>
      'عادت بيانات النسخة إلى التطبيق، وسيُطلب منك الآن رمز القفل الخاص بها.';

  @override
  String get backupRestoreFailedTitle => 'تعذّرت الاستعادة';

  @override
  String get backupRestoreClose => 'إغلاق';

  @override
  String get backupInspectFile => 'الملف';

  @override
  String get backupInspectCreated => 'تاريخ النسخة';

  @override
  String get backupInspectSize => 'الحجم';

  @override
  String get backupInspectSchema => 'إصدار المخطط';

  @override
  String get backupInspectChecksum => 'البصمة (SHA-256)';

  @override
  String get backupInspectKind => 'النوع';

  @override
  String get backupErrNotFile =>
      'الملف المختار ليس نسخة احتياطية صالحة من FinAcc (‎.finbak).';

  @override
  String get backupErrChecksum =>
      'فشل فحص السلامة — الملف تالف أو عُدِّل بعد إنشائه.';

  @override
  String backupErrNewerSchema(int fileVersion, int appVersion) {
    return 'هذه النسخة بمخطط أحدث (v$fileVersion) من تطبيق التطبيق (v$appVersion) — حدِّث التطبيق أولاً.';
  }

  @override
  String get backupErrSafety =>
      'تعذّر إنشاء نسخة الأمان قبل الاستعادة — أُلغيت العملية وبياناتك كما هي.';

  @override
  String get backupErrOpenFailed =>
      'فشل فتح القاعدة المستعادة — أُعيدت بياناتك الحالية كما كانت.';

  @override
  String get backupErrUnsupported => 'الاستعادة متاحة في تطبيق أندرويد فقط.';

  @override
  String backupBannerAutoDone(String time) {
    return 'أُنشئت نسخة احتياطية تلقائية بنجاح عند $time';
  }

  @override
  String get backupBannerAutoFailed =>
      'تعذّرت النسخة التلقائية — أنشئ نسخة يدوياً من الإعدادات.';

  @override
  String get backupBannerWebDue =>
      'حان وقت نسخة احتياطية — ميزات النسخ الكاملة في تطبيق أندرويد.';

  @override
  String get backupBannerOpen => 'إدارة النسخ';

  @override
  String get settingsBackupTitle => 'النسخ الاحتياطي والاستعادة';

  @override
  String get settingsBackupDesc =>
      'نسخة محلية مضغوطة بضغطة واحدة، جدولة واستعادة ومشاركة';

  @override
  String settingsAboutDbSize(String size) {
    return 'حجم القاعدة: $size';
  }

  @override
  String get shiftTitle => 'الوردية';

  @override
  String get shiftOpenNoneTitle => 'لا توجد وردية مفتوحة';

  @override
  String get shiftOpenNoneBody =>
      'افتح الوردية بتسجيل الرصيد الافتتاحي للصندوق، ثم تابع المبيعات والتحصيلات حتى الإقفال بالمعادلة الشاملة.';

  @override
  String get shiftOpeningCountLabel => 'الرصيد الافتتاحي';

  @override
  String get shiftOpenButton => 'فتح الوردية';

  @override
  String get shiftInvalidAmount =>
      'أدخل رقماً صالحاً أكبر من صفر أو مساوياً له.';

  @override
  String get shiftLiveTitle => 'وردية مفتوحة';

  @override
  String get shiftOpenedAtLabel => 'وقت الفتح';

  @override
  String get shiftRunningIn => 'الوارد حتى الآن';

  @override
  String get shiftRunningOut => 'الصادر حتى الآن';

  @override
  String get shiftExpectedSoFar => 'المتوقع حتى الآن';

  @override
  String get shiftAutoRefreshNote => 'يتحدّث تلقائياً كل 30 ثانية';

  @override
  String get shiftCloseButton => 'إقفال الوردية';

  @override
  String get shiftHistoryTitle => 'آخر الورديات';

  @override
  String get shiftHistoryEmpty =>
      'لا ورديات مقفلة بعد — أقفل أول وردية ليظهر تقريرها هنا.';

  @override
  String get shiftCountedLabel => 'العدّ الفعلي';

  @override
  String get shiftCountedHint => 'المبلغ المعدود فعلاً في الصندوق الآن';

  @override
  String get shiftExpectedLabel => 'المتوقع';

  @override
  String get shiftDifferenceLabel => 'الفرق';

  @override
  String get shiftSurplus => 'زيادة';

  @override
  String get shiftDeficit => 'عجز';

  @override
  String get shiftMatched => 'مطابق';

  @override
  String get shiftNotesLabel => 'ملاحظات';

  @override
  String get shiftNotesHint => 'اختياري — مثلاً سبب الزيادة أو العجز';

  @override
  String get shiftConfirmClose => 'تأكيد الإقفال';

  @override
  String get shiftCloseSuccessTitle => 'أُقفلت الوردية';

  @override
  String get shiftEquationTitle => 'تفصيل المعادلة الشاملة';

  @override
  String get shiftChequesDeferredNote =>
      'الشيكات مؤجلة إلى الإصدار 1.1 — تظهر صفراً في المعادلة.';

  @override
  String get shiftCompCashSales => 'مبيعات نقدية';

  @override
  String get shiftCompCollections => 'تحصيلات';

  @override
  String get shiftCompOwnerDeposits => 'إيداعات المالك';

  @override
  String get shiftCompTransfersIn => 'تحويلات وإيداعات واردة';

  @override
  String get shiftCompBankIn => 'إيداعات بنكية';

  @override
  String get shiftCompChequesCleared => 'شيكات محصّلة';

  @override
  String get shiftCompSupplierPayments => 'مدفوعات موردين';

  @override
  String get shiftCompExpenses => 'مصاريف';

  @override
  String get shiftCompOwnerDraws => 'مسحوبات المالك';

  @override
  String get shiftCompTransfersOut => 'تحويلات وسحوبات صادرة';

  @override
  String get shiftCompBankOut => 'سحب بنكي';

  @override
  String get shiftCompChequesPaid => 'شيكات مصروفة';

  @override
  String get shiftCompOther => 'بنود أخرى (صافٍ)';

  @override
  String get shiftPdfPreviewAction => 'معاينة تقرير PDF';

  @override
  String get shiftPrintTitle => 'تقرير الوردية';

  @override
  String get shiftPrintBox => 'الصندوق';

  @override
  String get shiftPrintUser => 'المستخدم';

  @override
  String get shiftPrintOpened => 'الفتح';

  @override
  String get shiftPrintClosed => 'الإقفال';

  @override
  String get shiftPrintItemCol => 'البند';

  @override
  String get shiftPrintDirectionCol => 'الاتجاه';

  @override
  String get shiftPrintValueCol => 'القيمة';

  @override
  String get shiftPrintDirIn => 'وارد (+)';

  @override
  String get shiftPrintDirOut => 'صادر (−)';

  @override
  String get shiftPrintTotalIn => 'إجمالي الوارد';

  @override
  String get shiftPrintTotalOut => 'إجمالي الصادر';

  @override
  String get shiftPrintNotesRow => 'ملاحظات الإقفال';

  @override
  String shiftPrintShareMessage(
    String box,
    String expected,
    String difference,
  ) {
    return 'تقرير وردية $box — المتوقع $expected والفرق $difference';
  }

  @override
  String get agingTitle => 'أعمار الديون';

  @override
  String get agingHubSubtitle =>
      'تصنيف مستحقات العملاء: ٠–٣٠ / ٣١–٦٠ / ٦١–٩٠ / +٩٠ يوماً (FIFO)';

  @override
  String agingAsOfLabel(String date) {
    return 'حتى $date';
  }

  @override
  String get agingCurrencyLabel => 'عملة التقرير';

  @override
  String get agingBucket0to30 => '٠–٣٠ يوماً';

  @override
  String get agingBucket31to60 => '٣١–٦٠ يوماً';

  @override
  String get agingBucket61to90 => '٦١–٩٠ يوماً';

  @override
  String get agingBucket90plus => 'أكثر من ٩٠ يوماً';

  @override
  String get agingTotalLabel => 'الإجمالي العام';

  @override
  String agingCustomersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عميل مدين',
      many: '$count عميلاً مديناً',
      few: '$count عملاء مدينون',
      two: 'عميلان مدينان',
      one: 'عميل مدين واحد',
      zero: 'لا مدينين',
    );
    return '$_temp0';
  }

  @override
  String get agingNotYetDueLabel => 'غير مستحق بعد:';

  @override
  String get agingNoDebtsTitle => 'لا ديون مستحقة';

  @override
  String get agingNoDebtsBody =>
      'لا توجد مبالغ آجلة غير محصّلة على أي عميل بهذه العملة — كل الآجال سُدّدت، وضع مالي ممتاز!';

  @override
  String agingInvoicesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فاتورة مفتوحة',
      many: '$count فاتورة مفتوحة',
      few: '$count فواتير مفتوحة',
      two: 'فاتورتان مفتوحتان',
      one: 'فاتورة مفتوحة',
    );
    return '$_temp0';
  }

  @override
  String get agingDueDateLabel => 'الاستحقاق';

  @override
  String agingDaysOverdue(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوماً',
      many: '$count يوماً',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return 'متأخر $_temp0';
  }

  @override
  String agingDueInDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوماً',
      many: '$count يوماً',
      few: '$count أيام',
      two: 'يومين',
      one: 'يوم واحد',
    );
    return 'يستحق خلال $_temp0';
  }

  @override
  String get agingDueToday => 'مستحق اليوم';

  @override
  String get agingRemindTooltip => 'إرسال تذكير واتساب';

  @override
  String get agingNoPhone =>
      'لا يوجد رقم واتساب أو هاتف لهذا العميل — حدِّث بياناته أولاً.';

  @override
  String get agingWhatsAppFailed =>
      'تعذّر فتح واتساب — تأكد من تثبيته على الجهاز.';

  @override
  String get agingStaleWarning => 'تعذّر التحديث — المعروض آخر تقرير ناجح.';

  @override
  String get agingReminderCompanyFallback => 'مؤسستنا';

  @override
  String agingReminderMessage(String name, String company, String total) {
    return 'مرحباً $name، نودّ تذكيركم بوجود مبلغ مستحق على حسابكم لدى $company بمجموع $total. شكراً لتفهمكم.';
  }

  @override
  String get monthSalesTitle => 'مبيعات الشهر';

  @override
  String monthChangeUp(String pct) {
    return 'ارتفاع $pct٪ عن الشهر السابق';
  }

  @override
  String monthChangeDown(String pct) {
    return 'انخفاض $pct٪ عن الشهر السابق';
  }

  @override
  String get monthChangeFlat => 'مطابق للشهر السابق';

  @override
  String get monthNew => 'جديد';

  @override
  String monthInvoices(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فاتورة',
      many: '$count فاتورة',
      few: '$count فواتير',
      two: 'فاتورتان',
      one: 'فاتورة واحدة',
      zero: 'لا فواتير بعد',
    );
    return '$_temp0';
  }

  @override
  String get topItemsTitle => 'أعلى الأصناف مبيعاً';

  @override
  String get topItemsScope => 'هذا الشهر';

  @override
  String get topItemsEmpty => 'لا مبيعات هذا الشهر بعد';

  @override
  String get topItemsEmptyBody =>
      'ستظهر الأصناف الأكثر مبيعاً هنا فور إتمام أول فاتورة بيع هذا الشهر.';

  @override
  String topItemsQtyCount(String qty) {
    return 'الكمية: $qty';
  }

  @override
  String get creditLimitTitle => 'تجاوز حد الائتمان';

  @override
  String get creditLimitExceeded =>
      'هذه الفاتورة ستجعل رصيد العميل يتجاوز حد الائتمان المسموح له.';

  @override
  String get creditLimitBlocked =>
      'لا يمكن إتمام هذا البيع الآجل: الرصيد المتوقع بعد الفاتورة يتجاوز حد الائتمان (وضع المنع مفعّل).';

  @override
  String get creditLimitLimitLabel => 'حد الائتمان';

  @override
  String get creditLimitCurrentLabel => 'الرصيد الحالي';

  @override
  String get creditLimitResultingLabel => 'الرصيد بعد الفاتورة';

  @override
  String get creditLimitContinue => 'متابعة على أي حال';

  @override
  String get creditLimitCancel => 'إلغاء';

  @override
  String get creditLimitBack => 'رجوع';

  @override
  String get stocktakeTitle => 'الجرد الفعلي';

  @override
  String get stocktakeHeroTitle => 'جرد المخزن ومطابقة الأرصدة';

  @override
  String get stocktakeHeroSubtitle =>
      'قارن الرصيد الدفتري بما عددته فعلاً؛ تُقيَّم الفروقات بتكلفة لقطة وقت الجرد، وبعد الاعتماد تُقفل الأرصدة على المقيس.';

  @override
  String get stocktakeWarehouseLabel => 'المخزن';

  @override
  String get stocktakeCountedAtLabel => 'تاريخ الجرد';

  @override
  String get stocktakeCountedByLabel => 'اسم الجانِد';

  @override
  String get stocktakeCountedByHint => 'يُوقَّع الجرد باسمه';

  @override
  String get stocktakeNotesLabel => 'ملاحظات (اختياري)';

  @override
  String get stocktakeSearchHint => 'ابحث عن صنف بالاسم…';

  @override
  String get stocktakeBookQty => 'دفتري';

  @override
  String get stocktakeCountedQty => 'الفعلي';

  @override
  String get stocktakeUnitCost => 'تكلفة الوحدة';

  @override
  String get stocktakeSetBook => 'نسخ الدفتري';

  @override
  String get stocktakeMatched => 'مطابق';

  @override
  String get stocktakeSurplus => 'زيادة';

  @override
  String get stocktakeShortage => 'عجز';

  @override
  String get stocktakeNetDiff => 'صافي الفرق';

  @override
  String stocktakeCountedProgress(int counted, int total) {
    return 'المعدود $counted من $total';
  }

  @override
  String get stocktakePost => 'اعتماد الجرد';

  @override
  String get stocktakeHistoryTitle => 'سجل عمليات الجرد';

  @override
  String get stocktakeHistoryEmpty =>
      'لم يُجرَد هذا المخزن بعد — أول جرد سيظهر هنا.';

  @override
  String stocktakeHistoryLines(int count) {
    return '$count بند';
  }

  @override
  String get stocktakeReviewTitle => 'مراجعة فروقات الجرد';

  @override
  String get stocktakeReviewNoDiffs => 'لا فروقات — كل المعدود مطابق لدفتره.';

  @override
  String get stocktakeReviewWarning =>
      'بعد الاعتماد تُقفل الأرصدة على المقيس وتُرحَّل الفروقات كحركات جرد بتكلفة اللقطة — لا يمكن التراجع.';

  @override
  String stocktakeReviewSkipNote(int count) {
    return '$count صنفاً غير معدود سيُتجاوز من هذا الجرد.';
  }

  @override
  String get stocktakeConfirmPost => 'تأكيد الاعتماد والترحيل';

  @override
  String get stocktakeSuccessTitle => 'تم اعتماد الجرد';

  @override
  String get stocktakeSuccessBody =>
      'قُفلت الأرصدة على المقيس ورُحّلت التسويات بحركات جرد موقَّعة.';

  @override
  String get stocktakeSuccessDiffs => 'أسطر الفروقات';

  @override
  String get stocktakeEmptyTitle => 'المخزن فارغ';

  @override
  String get stocktakeEmptyBody =>
      'لا أصناف مخزنية في هذا المخزن — أضف أصنافاً ثم ابدأ الجرد.';

  @override
  String get stocktakeNoWarehouseTitle => 'لا مخازن';

  @override
  String get stocktakeNoWarehouseBody => 'أنشئ مخزناً أولاً ثم ابدأ الجرد.';

  @override
  String get stocktakeSearchEmptyTitle => 'لا نتائج مطابقة';

  @override
  String get stocktakeSearchEmptyBody => 'جرّب اسماً آخر أو امسح البحث.';

  @override
  String get profitTitle => 'الأرباح والخسائر';

  @override
  String get profitSales => 'المبيعات';

  @override
  String get profitSalesReturns => 'مرتجع المبيعات';

  @override
  String get profitCogs => 'تكلفة المبيعات (COGS)';

  @override
  String get profitReturnCost => 'تكلفة المرتجع';

  @override
  String get profitStockSurplus => 'زيادات الجرد';

  @override
  String get profitStockShortage => 'عجز الجرد';

  @override
  String get profitExpenses => 'المصاريف';

  @override
  String get profitFx => 'فروق الصرف المحققة';

  @override
  String get profitOwnerDrawings => 'مسحوبات المالك';

  @override
  String get profitOwnerSection => 'مسحوبات المالك (خارج المصاريف)';

  @override
  String get profitNetSales => 'صافي المبيعات';

  @override
  String get profitNetCogs => 'صافي التكلفة';

  @override
  String get profitTotal => 'الربح';

  @override
  String get profitNetForOwner => 'صافي ما بقي للمالك';

  @override
  String get profitSectionRevenue => 'الإيراد';

  @override
  String get profitSectionCost => 'التكلفة';

  @override
  String get profitSectionAdjustments => 'التسويات (الجرد وفروق الصرف)';

  @override
  String get profitSectionExpenses => 'المصاريف';

  @override
  String get profitEmptyTitle => 'لا حركة في هذه الفترة';

  @override
  String get profitEmptyBody =>
      'لم تُسجَّل أي مبيعات أو مصاريف أو تسويات خلال الفترة المحددة — جرّب توسيعها أو أنشئ أول حركة.';

  @override
  String get profitBaseCurrencyNote => 'جميع المبالغ بالعملة الأساسية';

  @override
  String profitGeneratedAt(Object time) {
    return 'أُنشئ في $time';
  }

  @override
  String profitPeriodLabel(Object from, Object to) {
    return 'الفترة: من $from إلى $to';
  }

  @override
  String profitInvoicesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فاتورة',
      many: '$count فاتورة',
      few: '$count فواتير',
      two: 'فاتورتان',
      one: 'فاتورة واحدة',
      zero: 'بلا فواتير',
    );
    return '$_temp0';
  }

  @override
  String get profitStaleWarning => 'تعذّر التحديث — تُعرض آخر نسخة محمّلة';

  @override
  String get profitPdfButton => 'تقرير PDF';

  @override
  String get profitPdfTitle => 'تقرير الأرباح والخسائر';

  @override
  String get profitPrintItemCol => 'البند';

  @override
  String get profitPrintValueCol => 'القيمة';

  @override
  String get profitPrintFooterNote => 'مُشتق حصراً من خريطة الترحيل (ملحق و)';

  @override
  String profitPrintShareMessage(
    Object currency,
    Object from,
    Object profit,
    Object to,
  ) {
    return 'تقرير الأرباح والخسائر من $from إلى $to — الربح $profit $currency';
  }

  @override
  String get periodToday => 'اليوم';

  @override
  String get periodWeek => 'آخر ٧ أيام';

  @override
  String get periodMonth => 'هذا الشهر';

  @override
  String get periodQuarter => 'هذا الربع';

  @override
  String get periodYear => 'هذه السنة';

  @override
  String get periodCustom => 'فترة مخصصة';

  @override
  String get periodCustomHint => 'اختر تاريخ البداية والنهاية';

  @override
  String get periodFrom => 'من';

  @override
  String get periodTo => 'إلى';

  @override
  String periodCustomRange(Object from, Object to) {
    return 'من $from إلى $to';
  }

  @override
  String get invoiceProfitSectionTitle => 'ربح الفاتورة';

  @override
  String get invoiceProfitManagerHint => 'للمدير';

  @override
  String get invoiceCostLabel => 'التكلفة';

  @override
  String get invoiceProfitLabel => 'الربح';

  @override
  String get invoiceMarginLabel => 'هامش الربح';

  @override
  String get reportsTitle => 'التقارير';

  @override
  String get reportsHeroTitle => 'مركز التقارير والرقابة';

  @override
  String get reportsHeroSubtitle =>
      'أرقامك من مصدر حقيقة واحد — مشتقة حصراً من خريطة الترحيل';

  @override
  String get reportsSectionFinance => 'المالية والأرباح';

  @override
  String get reportsSectionDebts => 'الديون والتحصيل';

  @override
  String get reportsSectionInventory => 'المخزون والرقابة';

  @override
  String get reportsPnlDesc =>
      'الصيغة الملزمة عبر خريطة الترحيل مع صافي ما بقي للمالك';

  @override
  String get reportsStocktakeDesc =>
      'مقارنة الدفتري بالفعلي وتسوية الفروق بتكلفة اللقطة';

  @override
  String get itemMovementTitle => 'حركة صنف';

  @override
  String get itemMovementPickTitle => 'اختر صنفاً أولاً';

  @override
  String get itemMovementPickBody =>
      'اعرض كل حركات الصنف خلال الفترة مع الباقي التراكمي بعد كل حركة.';

  @override
  String get itemMovementPickButton => 'اختيار الصنف';

  @override
  String get itemMovementChangeProduct => 'تغيير الصنف';

  @override
  String get itemMovementPickerTitle => 'اختر الصنف';

  @override
  String get itemMovementPickerSearchHint => 'ابحث بالاسم أو الباركود';

  @override
  String get itemMovementPickerNoResults => 'لا نتائج مطابقة للبحث';

  @override
  String get itemMovementOpeningBalance => 'رصيد ما قبل الفترة';

  @override
  String get itemMovementTotalIn => 'إجمالي الوارد';

  @override
  String get itemMovementTotalOut => 'إجمالي الصادر';

  @override
  String get itemMovementWacNow => 'التكلفة الحالية للوحدة';

  @override
  String get itemMovementBalanceAfter => 'الباقي';

  @override
  String itemMovementMovementCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حركة',
      many: '$count حركة',
      few: '$count حركات',
      two: 'حركتان',
      one: 'حركة واحدة',
      zero: 'لا حركات',
    );
    return '$_temp0';
  }

  @override
  String get itemMovementUnitCost => 'تكلفة الوحدة';

  @override
  String itemMovementPeriodLabel(Object from, Object to) {
    return 'الفترة: من $from إلى $to';
  }

  @override
  String get itemMovementEmptyTitle => 'لا حركة في هذه الفترة';

  @override
  String get itemMovementEmptyBody =>
      'لم يتحرك هذا الصنف بين التاريخين المحددين — جرّب توسيع الفترة.';

  @override
  String get stockSummaryTitle => 'ملخص حركة المخزون';

  @override
  String stockSummaryTotalItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صنف متحرك',
      many: '$count صنفاً متحركاً',
      few: '$count أصناف متحركة',
      two: 'صنفان متحركان',
      one: 'صنف واحد متحرك',
      zero: 'لا أصناف متحركة',
    );
    return '$_temp0';
  }

  @override
  String get stockSummaryTotalValue => 'إجمالي قيمة المخزون بالتكلفة';

  @override
  String get stockSummaryQtyIn => 'وارد';

  @override
  String get stockSummaryQtyOut => 'صادر';

  @override
  String get stockSummaryQtyReturns => 'مرتجع';

  @override
  String get stockSummaryQtyAdjust => 'تسوية';

  @override
  String get stockSummaryEndBalance => 'الرصيد';

  @override
  String get stockSummaryValueAtCost => 'القيمة بالتكلفة';

  @override
  String stockSummaryPeriodLabel(Object from, Object to) {
    return 'الفترة: من $from إلى $to';
  }

  @override
  String get stockSummaryEmptyTitle => 'لا حركة مخزون في هذه الفترة';

  @override
  String get stockSummaryEmptyBody =>
      'لم تُسجَّل أي حركة مخزون بين التاريخين المحددين — جرّب توسيع الفترة.';

  @override
  String get salesByTitle => 'المبيعات حسب';

  @override
  String get salesByCustomer => 'العميل';

  @override
  String get salesByCategory => 'الفئة';

  @override
  String get salesByItem => 'الصنف';

  @override
  String get salesByDay => 'اليوم';

  @override
  String get salesByNoCustomer => 'عميل نقدي (بلا عميل)';

  @override
  String get salesByUncategorized => 'غير مصنّف';

  @override
  String salesByInvoicesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فاتورة',
      many: '$count فاتورة',
      few: '$count فواتير',
      two: 'فاتورتان',
      one: 'فاتورة واحدة',
      zero: 'بلا فواتير',
    );
    return '$_temp0';
  }

  @override
  String get salesByTotal => 'إجمالي المبيعات';

  @override
  String get salesByChangeNote =>
      'النسبة مقارنةً بفترة سابقة مساوية في الطول مباشرةً قبل المحددة.';

  @override
  String salesByPeriodLabel(Object from, Object to) {
    return 'الفترة: من $from إلى $to';
  }

  @override
  String get salesByEmptyTitle => 'لا مبيعات في هذه الفترة';

  @override
  String get salesByEmptyBody =>
      'لا فواتير بيع مكتملة بين التاريخين المحددين — جرّب توسيع الفترة.';

  @override
  String changeUp(Object pct) {
    return 'ارتفاع $pct٪';
  }

  @override
  String changeDown(Object pct) {
    return 'انخفاض $pct٪';
  }

  @override
  String get changeNew => 'جديد';

  @override
  String get movementTypePurchase => 'شراء';

  @override
  String get movementTypeSale => 'بيع';

  @override
  String get movementTypeSaleReturn => 'مرتجع بيع';

  @override
  String get movementTypePurchaseReturn => 'مرتجع شراء';

  @override
  String get movementTypeAdjust => 'تسوية جرد';

  @override
  String get movementTypeOpening => 'رصيد افتتاحي';

  @override
  String get movementTypeTransferIn => 'تحويل وارد';

  @override
  String get movementTypeTransferOut => 'تحويل صادر';

  @override
  String get reportsSectionFlows => 'حركة المخزون والمبيعات';

  @override
  String get reportsItemMovementDesc =>
      'بطاقة الصنف الكاملة بالباقي التراكمي لكل حركة';

  @override
  String get reportsStockSummaryDesc =>
      'وارد/صادر/مرتجع/تسوية لكل صنف مع قيمة المخزون';

  @override
  String get reportsSalesByDesc =>
      'العميل/الفئة/الصنف/اليوم مع نسب التغير عن الفترة السابقة';

  @override
  String get sellFixPrintInvoice => 'طباعة الفاتورة';

  @override
  String get sellFixShareInvoice => 'مشاركة / واتساب';

  @override
  String get sellFixPrintAndNewInvoice => 'طباعة + فاتورة جديدة';

  @override
  String get sellFixClose => 'إغلاق';

  @override
  String get sellFixPrintLoadFailed =>
      'تعذّر تحميل الفاتورة للطباعة — جرّب من قائمة الفواتير.';

  @override
  String get sellFixDetailReturnAction => 'مرتجع على هذه الفاتورة';

  @override
  String get sellFixNewCustomer => 'عميل جديد';

  @override
  String get sellFixNewCustomerTitle => 'عميل جديد سريع';

  @override
  String get sellFixNewCustomerNameLabel => 'اسم العميل';

  @override
  String get sellFixNewCustomerPhoneLabel => 'الهاتف (اختياري)';

  @override
  String get sellFixNewCustomerNameRequired => 'اسم العميل مطلوب.';

  @override
  String get sellFixNewCustomerSave => 'إضافة وتحديد';

  @override
  String get appFixUnsavedTitle => 'تغييرات غير محفوظة';

  @override
  String get appFixUnsavedBody =>
      'هناك تغييرات لم تُحفظ بعد — المغادرة الآن تضيعها. هل تريد المغادرة دون حفظ؟';

  @override
  String get appFixUnsavedLeave => 'مغادرة';

  @override
  String get appFixUnsavedStay => 'بقاء';

  @override
  String get appFixWipeBackupFailedTitle => 'تعذّر إنشاء نسخة الأمان';

  @override
  String get appFixWipeBackupFailedBody =>
      'فشل إنشاء النسخة الاحتياطية التلقائية قبل المسح، لذلك لم تُمسَح أي بيانات. أعد المحاولة، أو تابع المسح دون نسخة نهائية إن كنت متأكداً.';

  @override
  String get appFixWipeProceedNoBackup => 'متابعة بلا نسخة';

  @override
  String appFixWipeSafetyBackupAt(Object fileName) {
    return 'أُنشئت نسخة أمان تلقائية قبل المسح باسم: $fileName';
  }

  @override
  String pdfFixPageIndicator(int page, int total) {
    return 'صفحة $page من $total';
  }

  @override
  String get settings2CustomizationTitle => 'التخصيص';

  @override
  String get settings2CompanyTitle => 'بيانات المنشأة';

  @override
  String get settings2CompanySubtitle =>
      'الاسم والهاتف والواتساب والعنوان والشعار والتذييل';

  @override
  String get settings2CompanyNameLabel => 'اسم المنشأة';

  @override
  String get settings2CompanyPhoneLabel => 'الهاتف';

  @override
  String get settings2CompanyWhatsappLabel => 'واتساب';

  @override
  String get settings2CompanyAddressLabel => 'العنوان';

  @override
  String get settings2CompanyTaxNumberLabel => 'الرقم الضريبي';

  @override
  String get settings2CompanyTaxRateLabel => 'نسبة الضريبة ٪';

  @override
  String get settings2CompanyFooterLabel => 'نص تذييل الفاتورة';

  @override
  String get settings2CompanyFooterHint =>
      'يُطبع أسفل الفواتير — عبارة شكر أو بيانات التواصل';

  @override
  String get settings2CompanyLogoSection => 'الشعار';

  @override
  String get settings2CompanyLogoPick => 'اختيار شعار';

  @override
  String get settings2CompanyLogoChange => 'تغيير الشعار';

  @override
  String get settings2CompanyLogoRemove => 'إزالة الشعار';

  @override
  String get settings2CompanyLogoHint =>
      'صورة من المعرض تُخزَّن داخل قاعدة بياناتك وتنجو مع النسخة الاحتياطية';

  @override
  String get settings2CompanyLogoTooLarge =>
      'حجم الشعار كبير جداً — اختر صورة أصغر (الحد ميجابايت واحد).';

  @override
  String get settings2CompanySave => 'حفظ التعديلات';

  @override
  String get settings2CompanySaved => 'حُفظت بيانات المنشأة';

  @override
  String get settings2CompanyNameRequired => 'اسم المنشأة مطلوب.';

  @override
  String get settings2CompanyInvalidTaxRate =>
      'نسبة الضريبة يجب أن تكون رقماً بين 0 و100.';

  @override
  String get settings2CompanySaveFailed =>
      'تعذّر حفظ بيانات المنشأة — أعد المحاولة.';

  @override
  String settings2CompanyCurrencyNote(String code) {
    return 'العملة الأساسية: $code — تُثبَّت من التأسيس ولا تُغيَّر هنا.';
  }

  @override
  String get settings2SalePrefsTitle => 'تفضيلات البيع';

  @override
  String get settings2SalePrefsSubtitle =>
      'طريقة الدفع الافتراضية والخصومات وسياسات الحرس';

  @override
  String get settings2SalePrefsNote =>
      'كل تغيير يُطبَّق فوراً ويُحفَظ في قاعدتك المحلية.';

  @override
  String get settings2SaleDefaultPayment => 'طريقة الدفع الافتراضية';

  @override
  String get settings2SaleDefaultPaymentDesc =>
      'تُفتح نافذة الدفع على هذا الوضع';

  @override
  String get settings2SalePayCash => 'نقدي كامل';

  @override
  String get settings2SalePayCredit => 'آجل كامل';

  @override
  String get settings2SalePayMixed => 'مختلط';

  @override
  String get settings2SaleShowDiscounts => 'إظهار الخصومات في الكاشير';

  @override
  String get settings2SaleShowDiscountsDesc =>
      'إخفاؤها يبسّط شاشة البيع للمتاجر بلا خصومات';

  @override
  String get settings2SaleCreditLimitPolicy => 'سياسة حد الائتمان';

  @override
  String get settings2SaleCreditLimitPolicyDesc =>
      'سلوك التطبيق عند تجاوز عميلٍ حدَّه بالبيع الآجل';

  @override
  String get settings2SaleOverAvailPolicy => 'البيع فوق المتاح';

  @override
  String get settings2SaleOverAvailPolicyDesc =>
      '«منع» يوقف ترحيل أي فاتورة فيها كمية تتجاوز رصيد المخزون';

  @override
  String get settings2SaleBelowMarginPolicy => 'تحذير البيع تحت التكلفة';

  @override
  String get settings2SaleBelowMarginPolicyDesc =>
      'لافتة تحذير بالكاشير عند بيع صنف أدنى من تكلفته';

  @override
  String get settings2SalePolicyWarn => 'تحذير ومتابعة';

  @override
  String get settings2SalePolicyBlock => 'منع';

  @override
  String get settings2SaleWriteFailed =>
      'تعذّر حفظ التفضيل — القيمة الحالية بلا تغيير.';

  @override
  String get settings2AppearanceTitle => 'العرض والمظهر';

  @override
  String get settings2FontScale => 'حجم الخط';

  @override
  String get settings2FontScaleDesc =>
      'يُطبَّق على كامل التطبيق فوراً — عادي للرؤية المريحة وأكبر لضعاف البصر';

  @override
  String get settings2FontScaleNormal => 'عادي';

  @override
  String get settings2FontScaleLarge => 'كبير';

  @override
  String get settings2FontScaleXlarge => 'أكبر';

  @override
  String get settings2FontScaleSample => 'نص عيّنة';

  @override
  String get settings2HighContrast => 'التباين العالي';

  @override
  String get settings2HighContrastDesc =>
      'أسطح صافية ونصوص بأقصى تباين وحدود أوضح';

  @override
  String get settings2HighContrastNote =>
      'مخصص لضعاف البصر — يغلّف الألوان الناعمة بحدود قصوى.';

  @override
  String settings2BelowCostWarning(String names) {
    return 'تحذير: $names يُباع تحت التكلفة بعد الخصومات — راجع السعر.';
  }

  @override
  String settings2AboutVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get settings2AboutPhase => 'ما قبل v1.0.0 — الموجة 2';

  @override
  String get visFixItemsAddFab => 'تسجيل صنف';

  @override
  String get visFixItemsAddFabShort => 'صنف جديد';

  @override
  String get tmplSectionTitle => 'الطباعة والفواتير';

  @override
  String get tmplSectionSubtitle =>
      'قالب الفاتورة والألوان والعناصر — بمعاينة حية';

  @override
  String get tmplScreenTitle => 'الطباعة والفواتير';

  @override
  String get tmplTemplateSectionTitle => 'قالب الفاتورة';

  @override
  String get tmplClassicName => 'كلاسيكي A4 أفقي';

  @override
  String get tmplClassicDesc =>
      'محاكاة النموذج الحكومي: إطار خارجي وشعار بالوسط وخانات توقيع ثلاث ومكان ختم';

  @override
  String get tmplSimpleName => 'بسيط A4 عمودي';

  @override
  String get tmplSimpleDesc =>
      'قالب التطبيق الحالي — ترويسة ملونة وجدول أنيق وبطاقة إجماليات';

  @override
  String get tmplThermalName => 'حراري 80مم';

  @override
  String get tmplThermalDesc =>
      'إيصال رول للطابعات الحرارية بباركود رقم الفاتورة';

  @override
  String get tmplColorsTitle => 'ألوان الفاتورة';

  @override
  String get tmplColorTableHead => 'رأس الجدول';

  @override
  String get tmplColorBorders => 'الحدود';

  @override
  String get tmplColorAccentRed => 'التمييز الأحمر';

  @override
  String get tmplTogglesTitle => 'عناصر الفاتورة';

  @override
  String get tmplShowDiscountCol => 'عمود الخصم';

  @override
  String get tmplShowDiscountColDesc =>
      'إخفاؤه يبسّط جدول الأصناف للمتاجر بلا خصومات';

  @override
  String get tmplShowUnitCol => 'عمود الوحدة';

  @override
  String get tmplShowUnitColDesc =>
      'يعرض وحدة بيع كل صنف (كرتونة/علبة…) حيث تتوفر';

  @override
  String get tmplShowBarcode => 'باركود رقم الفاتورة';

  @override
  String get tmplShowBarcodeDesc =>
      'رمز Code128 قابل للمسح أسفل الفاتورة أو الإيصال';

  @override
  String get tmplShowTax => 'بيانات الضريبة';

  @override
  String get tmplShowTaxDesc => 'يطبع الرقم الضريبي للمنشأة إن وُجد ببياناتها';

  @override
  String get tmplShowSignatures => 'خانات التوقيع الثلاث';

  @override
  String get tmplShowSignaturesDesc =>
      'المستلم والمحصل والبائع بخانات أفقية (القالب الكلاسيكي)';

  @override
  String get tmplShowStamp => 'مكان الختم';

  @override
  String get tmplShowStampDesc =>
      'مساحة فارغة محجوزة بختم المنشأة (القالب الكلاسيكي)';

  @override
  String get tmplShowFooter => 'تذييل الفاتورة';

  @override
  String get tmplShowFooterDesc => 'نص المنشأة وعبارة الشكر أسفل المستند';

  @override
  String get tmplShowNotes => 'خانة الملاحظات';

  @override
  String get tmplShowNotesDesc => 'ملاحظات الفاتورة المطبوعة داخل إطار مخصص';

  @override
  String get tmplBadgeTitle => 'شارة النسخة';

  @override
  String get tmplBadgeNone => 'بلا شارة';

  @override
  String get tmplBadgeOriginal => 'أصل';

  @override
  String get tmplBadgeCopy => 'صورة';

  @override
  String get tmplPreviewButton => 'معاينة حية';

  @override
  String get tmplResetButton => 'استعادة الافتراضي';

  @override
  String get tmplWriteFailed =>
      'تعذّر حفظ إعداد القالب — القيمة الحالية بلا تغيير.';

  @override
  String get tmplNote =>
      'التغييرات تُطبَّق على الطباعة القادمة فوراً — بلا زر حفظ.';

  @override
  String get tmplTitleCash => 'فاتورة مبيعات نقد';

  @override
  String get tmplTitleCredit => 'فاتورة مبيعات آجل';

  @override
  String get tmplTitleMixed => 'فاتورة مبيعات نقد وآجل';

  @override
  String get tmplUnitCol => 'الوحدة';

  @override
  String get tmplNotesTitle => 'ملاحظات';

  @override
  String get tmplSignReceiver => 'المستلم';

  @override
  String get tmplSignCollector => 'المحصل';

  @override
  String get tmplSignSeller => 'البائع';

  @override
  String get tmplStampArea => 'مكان الختم';

  @override
  String get tmplTaxNumber => 'الرقم الضريبي';

  @override
  String get bonusQtyChipEmpty => 'بونص';

  @override
  String bonusQtyChipValue(Object n) {
    return '+$n مجاني';
  }

  @override
  String bonusDetailSuffix(Object n) {
    return '+$n مجاني';
  }

  @override
  String bonusPrintSuffix(Object n) {
    return '(+$n مجاني)';
  }

  @override
  String sellLineEditTitle(Object name) {
    return 'تعديل السطر: $name';
  }

  @override
  String get sellLineEditQtyLabel => 'الكمية المدفوعة';

  @override
  String get sellLineEditBonusLabel => 'الكمية المجانية (بونص)';

  @override
  String get sellLineEditPriceLabel => 'سعر الوحدة';

  @override
  String get sellLineEditDiscountLabel => 'خصم السطر';

  @override
  String get sellLineEditSave => 'حفظ التعديلات';

  @override
  String get sellLineEditQtyError => 'أدخل كمية أكبر من صفر';

  @override
  String get sellLineEditBonusError =>
      'أدخل كمية بونص سليمة (صفر فأكثر وبلا دقة أعلى من ثلاث منازل)';

  @override
  String get sellLineEditPriceError => 'أدخل سعراً سليماً لا يقل عن صفر';

  @override
  String purBonusEditTitle(Object name) {
    return 'الكمية المجانية (بونص): $name';
  }

  @override
  String sellQtyEditTitle(Object name) {
    return 'تعديل الكمية: $name';
  }

  @override
  String purchaseQtyEditTitle(Object name) {
    return 'تعديل الكمية: $name';
  }

  @override
  String get invoiceVoidBadge => 'ملغاة';

  @override
  String get invoiceVoidButton => 'إبطال الفاتورة';

  @override
  String get invoiceVoidConfirmTitle => 'إبطال هذه الفاتورة؟';

  @override
  String invoiceVoidConfirmBody(Object no) {
    return 'إبطال $no ينشئ حركات معاكسة كاملة (مخزون وصندوق وأرصدة) داخل معاملة واحدة — لا يُحذف شيء: تبقى الفاتورة ظاهرة بحالة «ملغاة» ورقمها لا يُعاد استخدامه أبداً.';
  }

  @override
  String get invoiceVoidConfirmContinue => 'متابعة';

  @override
  String get invoiceVoidFinalTitle => 'تأكيد نهائي — إبطال الفاتورة';

  @override
  String invoiceVoidFinalBody(Object no) {
    return 'هل أنت متأكد من إبطال $no نهائياً؟ لا يمكن التراجع بعد الإبطال.';
  }

  @override
  String get invoiceVoidReasonLabel => 'سبب الإبطال (اختياري)';

  @override
  String get invoiceVoidConfirmAction => 'إبطال نهائي';

  @override
  String invoiceVoidedSnackBar(Object no) {
    return 'أُبطلت الفاتورة $no وسُجِّلت الحركات المعاكسة كاملة.';
  }

  @override
  String get invoiceVoidedNote =>
      'فاتورة ملغاة — حركات مخزونها وصندوقها وأرصدتها عُكست بالكامل، ورقمها لا يُعاد استخدامه.';
}
