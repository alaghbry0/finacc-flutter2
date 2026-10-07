# FinAcc — المُحاسِب الشخصي 🇸🇦📲

تطبيق **Flutter عربي RTL أوفلاين-أولاً** للمحاسبة والمخزون للتجار الصغار: كاشير بيع كامل، مخزون بدفعات وتواريخ صلاحية (FEFO)، عملاء وموردون بعملات متعددة، مشتريات بتكلفة متوسط مرجّح (WAC)، مرتجعات مرتبطة، صندوق ومدفوعات — كل ذلك على SQLite محلي 100% بلا سيرفر ولا إنترنت.

> **دليل الوكلاء الذكيين (AI):** اقرأ [`AGENTS.md`](AGENTS.md) أولًا.

## الوحدات المنجزة (الشرائح 0–5)

| الوحدة | الحالة |
|---|---|
| الهوية والدخول: Onboarding + PIN بسياسة قفل + عبارة مرور + تدقيق | ✅ |
| الداشبورد + إعدادات كاملة + سجل تدقيق مصفّى | ✅ |
| الأصناف: قائمة/بحث/بطاقة + فئات ووحدات + باركود (توليد EAN-13/QR) | ✅ |
| الدفعات وتواريخ الصلاحية + FEFO + جرد | ✅ |
| استيراد Excel للأصناف | ✅ |
| العملاء/الموردون: أرصدة افتتاحية بعملاتها + كشف حساب + المستحقات | ✅ |
| أسعار الصرف اليومية + سياسة FR-08-09 | ✅ |
| الكاشير: سلة حية + خصومات سطر/فاتورة + نقدي/آجل/مختلط + بوابة صرف | ✅ |
| عروض الأسعار QTE + تحويل لفاتورة بضغطة | ✅ |
| المشتريات PUR + دفعات واردة + WAC بخصم موزّع | ✅ (محرك) |
| مرتجعات البيع SRN والشراء PRN المرتبطة | ✅ (محرك) |
| واجهات الشراء والمرتجعات | ⬜ التالية |
| النقدية والصناديق → PDF/طباعة → النسخ الاحتياطي → الديون → الجرد/الأرباح → الإطلاق | ⬜ وفق خطة SRS §9 |

**الجودة الحالية:** `dart analyze` 0/0 • **411 اختبارًا أخضر** • معاينة ويب حية.

## الحزمة التقنية

- Flutter (stable) + Dart 3 — Material 3 + خط **Almarai** + هوية `0xFF00695C`
- **SQLite**: `sqflite` (أندرويد/أجهزة) + `sqflite_common_ffi_web` (معاينة الويب) — WAL دائمًا + هجرات + ترقيم مستندات ذرّي
- `provider` (MVVM بـ ChangeNotifier) + `go_router` (StatefulShellRoute)
- `intl` + ARB (عربي/إنجليزي عبر `flutter gen-l10n`)
- `barcode`/`barcode_widget` (توليد) • `excel` + `file_picker` (استيراد)

## التشغيل

```bash
flutter pub get
flutter gen-l10n
flutter run            # جهاز أندرويد موصول (USB debugging مفعّل)
flutter run -d chrome  # معاينة ويب
```

## الاختبار وبوابات الجودة

```bash
dart format lib test
dart analyze           # يجب: 0 errors / 0 warnings
flutter test           # كل الاختبارات خضراء
```

## بناء APK

```bash
flutter build apk --release              # APK واحد (أبسط تثبيت)
flutter build apk --split-per-abi        # APK لكل معماريات CPU (أصغر حجمًا)
flutter build appbundle --release        # للنشر على Google Play
```

قبل أول إصدار خارجي راجع: معرّف التطبيق (`applicationId`)، أيقونة (`flutter_launcher_icons`)، توقيع الإصدار (keystore + `key.properties`)، وأذونات `AndroidManifest.xml` — التفاصيل في SRS §9 الشريحة 7.

## الوثائق الحية

| الملف | ما فيه |
|---|---|
| [`AGENTS.md`](AGENTS.md) | دليل تشغيل أي وكيل ذكي/مطوّر جديد على المشروع |
| [`docs/finacc-srs-v1.5.md`](docs/finacc-srs-v1.5.md) | وثيقة المتطلبات الكاملة (القواعد المحاسبية §5.4 + خطة الشرائح §9) |
| [`docs/finacc-screens-guide-v1.5.md`](docs/finacc-screens-guide-v1.5.md) | مواصفات 61 شاشة تصميمًا وسلوكًا |
| `.agents/skills/` | 32 مهارة AI جاهزة (Flutter/Dart/UI-UX) — انظر `skills-lock.json` |

## البنية

```
lib/
├── main.dart / app.dart          # الإقلاع والتمهيد
├── core/storage/                 # فتح القاعدة + WAL + الهجرات + doc_sequence
├── data/                         # schema (34 جدولًا) + repositories + services
├── domain/                       # models + منطق تسعير نقي قابل للاختبار
├── ui/
│   ├── core/                     # router + session(AppController) + theme
│   └── features/<feature>/       # views + view_models (feature-first)
└── l10n/                         # app_ar.arb / app_en.arb
```
