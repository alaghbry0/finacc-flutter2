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
  String get settingsAboutPhase1 => 'المرحلة الأولى مكتملة';

  @override
  String get settingsAboutVersion => 'الإصدار 1.0.0 — الشريحة 0 + الشريحة 1';

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
}
