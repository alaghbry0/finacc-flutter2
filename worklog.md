# سجل العمل — مشروع تطبيق الهاتف المتكامل (Flutter)

> **اللغة المعتمدة في هذا السجل: العربية** — هذا المستند هو نقطة التسليم بين الجلسات.

---

Task ID: 1
Agent: Z.ai Code (المنسق الرئيسي)
Task: مرحلة التهيئة والتجهيز الكاملة لبيئة تطوير Flutter قبل مناقشة وثيقة المتطلبات (SRS)

Work Log:
- فحص البيئة: لا يوجد Flutter مثبّت مسبقاً، الشبكة متاحة (github / storage.googleapis.com / pub.dev / docs.flutter.dev / drive.google.com جميعها تستجيب).
- تنزيل Flutter SDK 3.47.6 stable (1.5GB) والتحقق من SHA256 ثم الفك إلى `/home/z/flutter` وإضافته إلى PATH عبر `~/.bashrc`.
- استنساخ المستودع الرسمي `flutter/agent-plugins` إلى `/home/z/flutter-agent-plugins` (19 مهارة: 10 Flutter + 9 Dart) وقراءة مهارات: architecture-best-practices، setup-localization، setup-declarative-routing.
- استنساخ `dart-lang/skills` إلى `/home/z/dart-lang-skills` (15 مهارة Dart).
- مراجعة الوثائق الرسمية (curl + استخراج المقالات): `docs.flutter.dev/ai/get-started`، `docs.flutter.dev/ai/tools`، `dart.dev/ai/package-skills` — المنظومة = مهارات + قواعد + خادم Dart MCP + مهارات الحزم + وكلاء متخصصون.
- تنزيل ملف Google Drive (sandbox-multi-stack-v1.1.zip) واستخراج مهارة `sandbox-multi-stack` وقراءتها بالكامل — قوانين حرجة: منفذ عام واحد (:3000)، الـ reaper يقتل العمليات، **كل ما هو خارج my-project يُمحى عند إعادة التشغيل**، mini-services = نمط البقاء، الذاكرة 4GB.
- تجهيز سلسلة أدوات Linux بدون root: `apt-get install --print-uris` لاستخراج روابط 53 حزمة .deb ثم تنزيلها وفكها بـ `dpkg -x` إلى `/home/z/opt/sysroot` (clang 19 + CMake 3.31 + ninja 1.12 + GTK3-dev) مع ضبط LD_LIBRARY_PATH وPKG_CONFIG_PATH.
- ربط Chrome المدمج في agent-browser (`/home/z/.agent-browser/browsers/chrome-153.../chrome`) كـ CHROME_EXECUTABLE لـ flutter web.
- تثبيت Android SDK بدون root: تنزيل cmdline-tools 13114758 وتثبيت platform-tools + platforms;android-36 + build-tools;36.0.0 (Java 21 موجود مسبقاً في النظام).
- **النتيجة: `flutter doctor` → "No issues found!"** (الفحوصات الست كلها ✓).
- إنشاء مشروع Flutter نظيف: `mobile_app/` داخل المستودع (android/ios/web) بنية طبقية: `lib/{data,domain,ui,ui/core,ui/features/home}` مع README توضيحية لكل طبقة.
- pubspec.yaml نظيف: flutter_localizations + intl + go_router 18 + provider 6 و`generate: true`.
- l10n كامل: `l10n.yaml` + `app_en.arb` + `app_ar.arb` (مع تصحيح تحذير ICU في صيغة الجمع العربية) والتوليد عبر `flutter gen-l10n` (المخرجات تذهب إلى `lib/l10n/` في 3.47 — تم تصحيح الاستيرادات إلى `package:mobile_app/l10n/app_localizations.dart`).
- كتابة: `main.dart` (MultiProvider) + `app.dart` (MaterialApp.router + المندوبون) + `app_theme.dart` (Material 3 بذرة Teal فاتح/داكن) + `app_router.dart` (GoRouter) + `HomeViewModel` (ChangeNotifier) + `HomeScreen` (ListenableBuilder + بطاقات الحالة/الطبقات/العداد).
- **`dart analyze` → "No issues found!"** و**`flutter test` → 2/2 نجحت**.
- بناء الويب: `flutter build web --release --base-href /mobile_app/` (73.8s) ونشر الناتج (40MB) إلى `public/mobile_app/` — التطبيق الفعلي يُخدَّم من منفذ Next.js الوحيد.
- بناء لوحة تحكم عربية RTL في `src/app/page.tsx`: ترويسة ثابتة، حالة doctor، **معاينة حية داخل إطار هاتف (iframe)** مع زر تحديث، سلسلة الأدوات، قائمة المهارات الـ25، هيكل المشروع، بوابة الخطوة التالية (SRS)، تذييل ثابت أسفل الشاشة. خط Cairo العربي عبر next/font.
- إنشاء `mini-services/flutter-env/`: keeper.sh (idempotent) يعيد توفير SDK+الأدوات+Android بعد كل إعادة تشغيل + env.sh (المصدر الوحيد للتصديرات مع اكتشاف ديناميكي لمسار Chrome) + package.json — يعمل تلقائياً عبر `.zscripts/dev.sh` → start_mini_services.
- تثبيت المهارات الرسمية في `.agents/skills/` (25 مهارة) + `.agents/rules/flutter-hot-reload.md` + نسخة مستدامة من مهارة sandbox في `docs/skills/sandbox-multi-stack/` مع خطوة استرجاع (Step 0) في الـ keeper.
- إنشاء `scripts/build-flutter-web.sh` (دورة التطوير: تعديل → بناء → تحديث المعاينة).
- إصلاح ESLint OOM بإضافة public/** وmobile_app/** وغيرها إلى ignores، ثم `bun run lint` نظيف.
- إصلاح تحذير allowedDevOrigins في next.config.ts (نطاق *.space-z.ai).

Stage Summary:
- **الحالة: مرحلة التهيئة والتجهيز مكتملة 100%** — البيئة جاهزة لاستلام SRS.
- Flutter 3.47.6 stable + Android SDK 36 + سلسلة Linux + Chrome: doctor نظيف تماماً.
- مشروع mobile_app: بنية MVVM/طبقية نظيفة، توطين عربي/إنجليزي، توجيه go_router، اختبارات خضراء، تحليل ساكن صفر أخطاء.
- المعاينة الحية تعمل: `/mobile_app/index.html` + لوحة `/` (اللغة حسب متصفح المستخدم — عربي RTL تلقائياً).
- الاستدامة: كل شيء خارج my-project يُمحى عند إعادة التشغيل → الـ keeper يعيد تفعيله تلقائياً (تنزيل ~2GB يستغرق ~3-5 دقائق بعد أول إقلاع).
- **ملاحظة مهمة للجلسات القادمة:** أولاً `source /home/z/my-project/mini-services/flutter-env/env.sh` ثم استخدم `flutter`/`dart`؛ وإن كانت الأدوات غائبة فانتظر الـ keeper أو شغّل `bash mini-services/flutter-env/keeper.sh`.
- غير محدد بعد: اسم التطبيق النهائي والهوية (بانتظار SRS)، لغة الواجهة الأساسية، منصات التسليم (APK مضمّن عبر Gradle + Java 21)، اسم حزمة Android (حالياً com.example).

Priorities للمرحلة التالية:
1. استلام ومناقشة وثيقة SRS من المستخدم.
2. تسمية التطبيق والهوية البصرية وتحديث pubspec/appTitle/الأيقونات.
3. ترجمة الميزات إلى ميزات first-class داخل البنية (features/*) مع اختبارات لكل ViewModel.
4. عند طلب APK: `flutter build apk --release` (Gradle سيُنزّل تبعياته في أول تشغيل — راقب الذاكرة 4GB والقرص).
