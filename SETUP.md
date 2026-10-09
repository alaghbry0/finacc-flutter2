# SETUP.md — إعادة تجميع بيئة التشغيل (Sandbox) من هذا المستودع

> **غرض هذا الملف**: أي وكيل (أو إنسان) يفتح sandbox جديدة يستطيع إعادة تهيئة بيئة
> FinAcc كاملة من هذا المستودع وحده — التطبيق + عدة البناء + التحقق الحي + لوحة التسليم.
> حدِّثه مع أي تغيير دائم في بنية العدة.

هذا المستودع يحمل **ثلاثة مكونات متكاملة**:

| المكوّن | المسار | الوظيفة |
|---|---|---|
| **تطبيق FinAcc (Flutter)** | `mobile_app/` | محاسبة نقاط بيع عربية RTL — عقده الموثق في `mobile_app/AGENTS.md` |
| **لوحة التسليم (Next.js 16)** | `src/`, `package.json`, `Caddyfile` | المسار `/` الوحيد المرئي للمستخدم: لوحة توثيق + إطار هاتف يحمل التطبيق (`/mobile_app/index.html`) خلف بوابة Caddy |
| **عدة البناء والتحقق** | `scripts/`, `mini-services/`, `docs/`, `worklog.md` | بوابة البناء + لمس CDP + OCR + VLM + حارس بيئة Flutter + SRS ودليل الشاشات + سجل الجولات |

## خطوات إعادة التجميع في sandbox جديدة

بافتراض sandbox قياسية فيها قالب Next.js جاهز في `/home/z/my-project`
(مع `src/`, `package.json`, `public/`, `Caddyfile`, ومكونات shadcn/ui مثبتة):

```bash
# 0) الاستنساخ (استبدل <TOKEN> بتوكن GitHub بنطاق repo)
git clone https://<TOKEN>@github.com/alaghbry0/finacc-flutter2 /tmp/finacc
cd /tmp/finacc && git log --oneline -3   # تحقق من آخر إيداع

# 1) مزامنة المستودع فوق القالب (نمط rsync الموصى به — لا تكتب فوق .git)
rsync -a --exclude '.git' /tmp/finacc/ /home/z/my-project/
cd /home/z/my-project && git remote set-url origin https://<TOKEN>@github.com/alaghbry0/finacc-flutter2.git

# 2) تبعيات لوحة التسليم + حارس بيئة Flutter (ينزّل SDK والأدوات idempotently)
bun install
bash mini-services/flutter-env/keeper.sh        # Flutter 3.47.6 + toolchain + Android SDK
source mini-services/flutter-env/env.sh         # أو أعد تشغيل bash ليقرأ ~/.bashrc

# 3) تبعيات التطبيق وبوابة البناء (AGENTS.md §5)
cd /home/z/my-project/mobile_app && flutter pub get
cd /home/z/my-project && bash scripts/build-flutter-web.sh

# 4) لوحة التسليم (المنفذ 3000 — لا تستخدم bun run build أبداً)
bun run dev &

# 5) البوابات الملزمة قبل أي إيداع
cd mobile_app && flutter analyze                 # يجب: 0/0
flutter test                                    # يجب: كلها خضراء (راجع آخر worklog للعدد)
```

## التحقق الحي (البوابة الوحيدة للحقيقة — AGENTS.md §4-7)

- التطبيق يُعاين عبر البوابة `http://localhost:81/mobile_app/index.html` (وليس المنفذ 3000 مباشرة).
- **وصفة النقر الموثوقة** داخل iframe التطبيق (Flutter يبتلع الأحداث التركيبية):
  `agent-browser eval "(() => { const doc = document.querySelector('iframe').contentDocument; const b = [...doc.querySelectorAll('[role=button]')].find(b => (b.textContent||'').includes('النص')); if (b) { b.click(); return 'clicked'; } return 'not found'; })()"`
- **وصفة إدخال النص الموثوقة**: انقر موضع الحقل بأوامر الفأرة التدريجية (move → down → up)
  ثم `press Control+a` ثم `keyboard type` — الإدخال العادي يتكرر/يُلحق.
- أدوات مساندة: `scripts/vlm-check.ts` (سؤال VLM عن لقطة)، `scripts/ocr-boxes.py` (OCR عربي/إنجليزي)،
  `scripts/cdp-touch.py` (لمس CDP).

## قواعد الحفظ (ملزمة)

- **يُرفع**: كل مصادر التطبيق واللوحة والعدة والوثائق (`mobile_app/lib`, `mobile_app/test`,
  `src/`, `scripts/`, `mini-services/`, `docs/`، `worklog.md`، `.github/`) —
  «كل ما يحتاجه وكيل في جلسة جديدة داخل المستودع».
- **لا يُرفع أبداً**: اللقطات المؤقتة، السجلات، `node_modules`، caches —
  (استثناء وحيد: `public/mobile_app/` مخرجات بناء الويب **متتبعة بالبنية** لخدمة المعاينة،
  و`docs/screenshots/` لقطات التوثيق).
- **APK لا يمر عبر git إطلاقاً**: يبنى على GitHub Actions (`.github/workflows/build-apk.yml`)
  مع كل tag `v*` ويُرفق بإصدار Release تلقائياً.
- القرص في الـ sandbox محدود (~10GB قابل للتحرير): راقب `df -h` دائماً؛
  امتلأ مرتين تاريخياً. ملاحظة overlayfs: حذف ملفات صورة المنصة لا يحرر مساحة فعلياً.
- رقم إصدار Flutter مثبّت في `mini-services/flutter-env/keeper.sh` (`FLUTTER_VERSION`) —
  حدّثه مع أي ترقية SDK بعد التحقق.

## نقاط البدء بعد التجميع

1. `worklog.md` (ذيله) — آخر جولة وحالة المشروع وما يليها.
2. `mobile_app/AGENTS.md` — عقد التطبيق: البوابات والمنهجية وخريطة الكود.
3. `docs/finacc-srs-v1.5.md` + `docs/finacc-screens-guide-v1.5.md` — المتطلبات والمواصفات.
4. `docs/nav-audit-r16.md` — مواصفة إعادة هيكلة التنقل (الشريحة 11).
