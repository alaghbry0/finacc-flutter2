# SETUP.md — إعادة تجميع بيئة التشغيل (Sandbox) من هذا المستودع

> **غرض هذا الملف**: أي وكيل (أو إنسان) يفتح sandbox جديدة يستطيع إعادة تهيئة بيئة
> FinAcc كاملة من هذا المستودع وحده — التطبيق + عدة البناء + خادم المعاينة + التحقق الحي.
> حدِّثه مع أي تغيير دائم في بنية العدة.
>
> **R21 (2026-10-19)**: أُخرج مشروع لوحة Next.js بالكامل. المعاينة الآن خادم bun
> ثابت في `mini-services/static-preview/` (صفر تبعيات، صفر خطوة بناء، ‎~56MB ذاكرة)
> يملك المنفذ 3000 خلف بوابة Caddy — ولا يوجد أي `bun run dev` أو Prisma بعد اليوم.

هذا المستودع يحمل **ثلاثة مكونات متكاملة**:

| المكوّن | المسار | الوظيفة |
|---|---|---|
| **تطبيق FinAcc (Flutter)** | `mobile_app/` | محاسبة نقاط بيع عربية RTL — عقده الموثق في `mobile_app/AGENTS.md` |
| **خادم المعاينة الثابت** | `mini-services/static-preview/` | خادم bun واحد (~200 سطر، بلا تبعيات): لوحة إطار الهاتف على `/` والتطبيق على `/mobile_app/` — يستيقظ مع الحاوية (auto-boot) ويملك المنفذ 3000 خلف بوابة Caddy |
| **عدة البناء والتحقق** | `scripts/`, `mini-services/flutter-env/`, `docs/`, `.agents/`, `worklog.md` | بوابة البناء + لمس CDP + OCR + VLM + حارس بيئة Flutter (يعيد بناء المعاينة تلقائياً إن فقدت) + SRS ودليل الشاشات + سجل الجولات |

## خطوات الإعداد اليدوية — هذا فقط ما تنفذه بيدك

بافتراض sandbox قياسية فيها قالب Next.js جاهز في `/home/z/my-project`:

```bash
# 0) الاستنساخ (استبدل <TOKEN> بتوكن GitHub بنطاق repo)
git clone https://<TOKEN>@github.com/alaghbry0/finacc-flutter2 /tmp/finacc
cd /tmp/finacc && git log --oneline -3   # تحقق من آخر إيداع

# 1) امسح بقايا قالب Next.js من مساحة العمل (لن يعاد استخدامها — R21)
rm -rf /home/z/my-project/src /home/z/my-project/prisma /home/z/my-project/db \
       /home/z/my-project/public/mobile_app /home/z/my-project/public/downloads \
       /home/z/my-project/next.config.ts /home/z/my-project/tsconfig.json \
       /home/z/my-project/package.json /home/z/my-project/bun.lock \
       /home/z/my-project/components.json /home/z/my-project/postcss.config.mjs \
       /home/z/my-project/eslint.config.mjs /home/z/my-project/tailwind.config.ts

# 2) مزامنة المستودع فوق مساحة العمل (لا تكتب فوق .git)
rsync -a --exclude '.git' /tmp/finacc/ /home/z/my-project/
cd /home/z/my-project && git remote set-url origin https://<TOKEN>@github.com/alaghbry0/finacc-flutter2.git
```

انتهى الإعداد. **كل ما عداهم يحدث تلقائياً عند أول إقلاع** — لا تنفّذ شيئاً من القسم التالي.

## ماذا يحدث تلقائياً عند الإقلاع (للمعرفة فقط — لا تفعل شيئاً)

- **`mini-services/flutter-env/keeper.sh`** (auto-boot): تنزيل Flutter SDK 3.47.6 + العدة + JDK + Android SDK + NDK stub، ثم — جديد في R21 — **إعادة بناء معاينة الويب تلقائياً إذا كانت مفقودة** (مخرجات `public/mobile_app/` غير متتبعة في git فتُمحى مع كل إقلاع). أول إقلاع بعد استنساخ جديد يستغرق دقائق؛ تابع السجل في `.zscripts/mini-service-flutter-env.log`.
- **`mini-services/static-preview/`** (auto-boot): خادم bun على المنفذ 3000 فوراً — يعرض لوحة «المعاينة غير مبنية بعد» حتى يكتمل بناء الحارس، ثم التطبيق حياً.
- **`bun install` في الجذر**: تبعية واحدة فقط (`z-ai-web-dev-sdk` لأداة `scripts/vlm-check.ts`).
- استعادة `skills/` من `docs/skills/` (خطوة 0 في الحارس).

## حلقة التطوير — التعليمات الوحيدة التي تحتاجها يومياً

```bash
cd mobile_app && dart analyze && flutter test    # البوابتان 1 و2 (AGENTS.md §5)
cd .. && bash scripts/build-flutter-web.sh       # البوابة 3: بناء المعاينة ثم حدِّث الصفحة
```

- المعاينة عبر البوابة: `http://localhost:81/` (لوحة الهاتف) أو `http://localhost:81/mobile_app/index.html` (التطبيق مباشرة) — **وليس المنفذ 3000 مباشرة**.
- الخادم الثابت يعمل دائماً (auto-boot) — لا تُشغّل أي خادم يدوياً. إن مات بمنتصف الجلسة: `cd mini-services/static-preview && bun server.ts &`
- بعد تعديل الخادم نفسه (`server.ts`): `pkill -f static-preview` ثم أعد تشغيله بالأمر أعلاه.

### وضع التطوير السريع (اختياري — «الخيار ب»)

لدورة تعديل أسرع بكثير داخل جلسة مكثفة واحدة: أوقف الخادم الثابت مؤقتاً وشغّل خادم
تطوير Flutter على نفس المنفذ:

```bash
pkill -f static-preview                  # حرِّر المنفذ 3000 (كلاهما يملكه)
source mini-services/flutter-env/env.sh
cd mobile_app && flutter run -d web-server --web-port 3000 --dart-define=use_arabic=true
```

- التطبيق يُقدَّم عند جذر البوابة (`/`) خلال هذه الجلسة، ويتطلب إعادة التشغيل عند كل
  تعديل (`flutter run` من جديد) — أسرع من dart2js الكامل بمرتين إلى ثلاث.
- **قيود**: يموت مع نهاية جلسة الأداة (الحاصد)؛ ذاكرته أعلى بكثير (VM دارت)؛ سلوك
  debug قد يختلف عن release. **غير مُتحقق حياً بعد عبر البوابة** — جرّبه أول مرة
  وسجّل النتيجة في worklog (ثقافة الوصفات المتحققة).
- عند الانتهاء: أعد تشغيل الخادم الثابت (`cd mini-services/static-preview && bun server.ts &`) — أو انتظر الإقلاع القادم.

## التحقق الحي (البوابة النهائية للحقيقة — AGENTS.md §4-7)

- **وصفة النقر الموثوقة** داخل iframe التطبيق (Flutter يبتلع الأحدات التركيبية):
  `agent-browser eval "(() => { const doc = document.querySelector('iframe').contentDocument; const b = [...doc.querySelectorAll('[role=button]')].find(b => (b.textContent||'').includes('النص')); if (b) { b.click(); return 'clicked'; } return 'not found'; })()"`
- **وصفة إدخال النص الموثوقة**: انقر موضع الحقل بأوامر الفأرة التدريجية (move → down → up)
  ثم `press Control+a` ثم `keyboard type` — الإدخال العادي يتكرر/يُلحق.
- أدوات مساندة: `scripts/vlm-check.ts` (سؤال VLM عن لقطة)، `scripts/ocr-boxes.py` (OCR عربي/إنجليزي)،
  `scripts/cdp-touch.py` (لمس CDP) — كلها تعمل مع الخادم الثابت كما كانت مع Next.js
  لأنها تستهدف الصفحة لا الغلاف.
- فحص حالة سريع: `curl -s localhost:3000/api/status` → `{version, buildPresent}`.

## قواعد الحفظ (ملزمة — محدثة R21)

- **يُرفع**: كل مصادر التطبيق والعدة والوثائق (`mobile_app/`, `scripts/`,
  `mini-services/`, `docs/`, `.agents/`, `.zscripts/` بلا `dev.pid`, `.github/`,
  `Caddyfile`, `public/{logo.svg,robots.txt}`, `package.json` (تبعية sdk وحدها),
  `worklog.md`) — «كل ما يحتاجه وكيل في جلسة جديدة داخل المستودع».
- **لا يُرفع أبداً** (انظر `.gitignore`):
  - `public/mobile_app/` — مخرجات بناء الويب: تُبنى عند الإقلاع تلقائياً (الحارس) أو يدوياً بالسكربت.
  - `public/downloads/` — APK: مكانه GitHub Releases (يرفقه CI مع كل tag `v*`).
  - `skills/` (يُستعاد من `docs/skills/`)، `db/`، اللقطات المؤقتة، السجلات، `node_modules`.
- القرص في الـ sandbox محدود (~10GB قابل للتحرير): راقب `df -h` دائماً؛
  امتلأ مرتين تاريخياً. ملاحظة overlayfs: حذف ملفات صورة المنصة لا يحرر مساحة فعلياً.
- رقم إصدار Flutter مثبّت في `mini-services/flutter-env/keeper.sh` (`FLUTTER_VERSION`) —
  حدّثه مع أي ترقية SDK بعد التحقق.

## CI (GitHub Actions)

| سير العمل | المشغّل | المخرجات |
|---|---|---|
| `build-apk.yml` | tag `v*` | analyze + الجناح الكامل + APK release (موقّع debug) → إصدار GitHub Release |
| `build-web-pages.yml` | tag `v*` + يدوي | بناء ويب بـ base-href `/finacc-flutter2/` → فرع gh-pages → معاينة عامة على GitHub Pages |

رابط المعاينة العامة (بعد تفعيل Pages على فرع gh-pages من إعدادات المستودع مرة واحدة):
`https://alaghbry0.github.io/finacc-flutter2/`

## ملاحظة تاريخ المستودع (R21 — 2026-10-19)

نُظّف تاريخ git بـ `git filter-repo` (قرار المالك): أُزيلت نهائياً مسارات مخرجات
البناء والثنائيات والمهارات الميتة (`public/mobile_app`, `public/downloads`,
`skills`, `docs/screenshots`, تاريخ `worklog.md` الكامل, `.env`, بقايا `lib`/`android`
العلوية, `db`) — هبط المستودع من ‎~104MB إلى أقل من الثلث. نسخة احتياطية كاملة
قبل التنظيف محفوظة خارج git لدى المالك (`finacc-backup-pre-r21.bundle`).

## نقاط البدء بعد التجميع

1. `worklog.md` (ذيله) — آخر جولة وحالة المشروع وما يليها.
2. `mobile_app/AGENTS.md` — عقد التطبيق: البوابات والمنهجية وخريطة الكود.
3. `docs/finacc-srs-v1.5.md` + `docs/finacc-screens-guide-v1.5.md` — المتطلبات والمواصفات.
4. `docs/nav-audit-r16.md` — مواصفة إعادة هيكلة التنقل (الشريحة 11).
