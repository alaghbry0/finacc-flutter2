# إعادة تجميع بيئة التشغيل (Sandbox) من هذا المستودع

هذا المستودع يحمل **مشروعين متكاملين**:

1. **تطبيق FinAcc (Flutter)** — في جذر المستودع (`lib/`, `pubspec.yaml`, `android/`, `ios/`, `web/`, `AGENTS.md` …).
2. **عدة الـ sandbox** — في `sandbox/` + `docs/` — كل ما يحتاجه وكيل يعمل داخل sandbox مطابق
   (قالب Next.js على المنفذ 3000 خلف بوابة Caddy، ومجلد مشروع `/home/z/my-project`)
   لإعادة تهيئة بيئة التشغيل والتحقق كاملة من الصفر.

> **لماذا هذا المجلد؟** منهجية الجودة المعتمدة (AGENTS.md §4-7) هي «التحقق الحي من المتصفح حصراً»،
> وأدوات هذه المنهجية (بناء المعاينة + لمس CDP + OCR + VLM + حارس بيئة Flutter) تعيش خارج مجلد
> `mobile_app/` — فحُفظت هنا لضمان بقاء الجلسات القادمة قادرة على تشغيلها حتى في sandbox جديد.

## محتويات العدة

| المسار في المستودع | وجهته في الـ sandbox | وظيفته |
|---|---|---|
| `sandbox/scripts/build-flutter-web.sh` | `scripts/` | **بوابة البناء** — يجمع التطبيق إلى `public/mobile_app/` (الأمر الموثق في AGENTS.md §5)؛ يدعم `--debug` لبناء أسرع |
| `sandbox/scripts/build_web_preview.sh` | `scripts/` | نسخة بناء مرجعية أقدم (احتفظ بها للتوثيق) |
| `sandbox/scripts/cdp-touch.py` | `scripts/` | محاكاة لمس CDP داخل متصفح الوكيل (لإدخال PIN الرقمي) — يقرأ المنفذ من متغير البيئة `CDP_PORT` |
| `sandbox/scripts/ocr-boxes.py` | `scripts/` | OCR للقطة (tesseract ara+eng) بمربعات نص وثقة — لتحليل لقطات التحقق الحي |
| `sandbox/scripts/vlm-check.ts` | `scripts/` | سؤال VLM عن لقطة: `bun scripts/vlm-check.ts <image> <question>` |
| `sandbox/mini-services/flutter-env/` | `mini-services/flutter-env/` | **حارس البيئة**: `keeper.sh` يعيد بثقة (idempotent) تنزيل Flutter SDK 3.47.6 + toolchain لينكس (clang/cmake/ninja/GTK3) + Android SDK (platform 36) بعد كل reboot، ويضيف `source env.sh` إلى `~/.bashrc`، ويعيد المهارات المخصصة من `docs/skills/`. التشغيل: `bun run dev` (أو `bash keeper.sh` مباشرة) |
| `sandbox/src/` | `src/` | **صفحة التسليم Next.js** — المسار `/` الوحيد المرئي للمستخدم: لوحة توثيق + إطار هاتف يحمل التطبيق (`/mobile_app/index.html`) |
| `docs/finacc-srs-v1.5.md` | `docs/` | SRS المعتمد v1.5 — المتطلبات الوظيفية وقواعد العمل (المصدر الأول للحقيقة) |
| `docs/finacc-screens-guide-v1.5.md` | `docs/` | مواصفات الـ 61 شاشة تصميماً وسلوكاً |

## خطوات إعادة التجميع في sandbox جديد

بافتراض sandbox قياسي فيه قالب Next.js جاهز في `/home/z/my-project`
(مع `src/`, `package.json`, `public/`, `Caddyfile`, ومكونات shadcn/ui مثبتة مسبقاً):

```bash
# 0) الاستنساخ
git clone https://github.com/alaghbry0/finacc-flutter2 /tmp/finacc

# 1) مشروع Flutter → mobile_app/
mkdir -p /home/z/my-project/mobile_app
rsync -a --exclude '.git' --exclude 'sandbox' --exclude 'docs' \
  /tmp/finacc/ /home/z/my-project/mobile_app/

# 2) عدة التشغيل والتحقق → جذر الـ sandbox
mkdir -p /home/z/my-project/scripts
cp /tmp/finacc/sandbox/scripts/* /home/z/my-project/scripts/
mkdir -p /home/z/my-project/mini-services
cp -r /tmp/finacc/sandbox/mini-services/flutter-env /home/z/my-project/mini-services/
cp -r /tmp/finacc/sandbox/src/* /home/z/my-project/src/

# 3) الوثائق المرجعية (SRS + دليل الشاشات)
mkdir -p /home/z/my-project/docs
cp /tmp/finacc/docs/finacc-srs-v1.5.md /tmp/finacc/docs/finacc-screens-guide-v1.5.md \
  /home/z/my-project/docs/

# 4) (اختياري) استعادة حزمة المهارات والقواعد الموثقة
cp -r /tmp/finacc/.agents /home/z/my-project/

# 5) تهيئة بيئة Flutter — ينزّل SDK والأدوات idempotently
bash /home/z/my-project/mini-services/flutter-env/keeper.sh
source /home/z/my-project/mini-services/flutter-env/env.sh

# 6) بناء المعاينة ثم التحقق الحي من المتصفح (البوابة الوحيدة)
cd /home/z/my-project
(cd mobile_app && flutter pub get)
bash scripts/build-flutter-web.sh
```

## قواعد الحفظ

- **لا يُرفع أبداً**: `public/mobile_app/` (مخرجات البناء المولّدة)، اللقطات، السجلات المؤقتة، `node_modules`.
- أي سكربت جديد يُضاف إلى `scripts/` أو خدمة إلى `mini-services/` في الـ sandbox **يجب** نسخها إلى
  `sandbox/` هنا في نفس الإيداع — حتى تبقى العدة متزامنة مع كل جلسة.
- ملفات `public/logo.svg` و`public/robots.txt` تأتي مع قالب الـ sandbox القياسي ولا تحتاج استعادة.
- رقم إصدار Flutter مثبّت في `keeper.sh` (`FLUTTER_VERSION`) — حدّثه مع ترقية SDK بعد التحقق.
