/**
 * static-preview/server.ts — خادم المعاينة الثابت (R21).
 * =============================================================================
 * بديل لوحة Next.js بالكامل: خادم bun واحد بلا تبعيات وبلا خطوة بناء.
 *
 *   /                 → لوحة إطار الهاتف (HTML خالص — يقرأ إصدار التطبيق من pubspec)
 *   /mobile_app/*     → مخرجات بناء Flutter Web من public/mobile_app
 *   /api/status       → {version, buildPresent} — فحص صحة/حالة للوكيل
 *
 * - يعمل كخدمة auto-boot عبر .zscripts/dev.sh → mini-services (يمتلك المنفذ 3000
 *   خلف بوابة Caddy :81).
 * - مخرجات public/mobile_app غير متتبعة في git (تُمحى مع كل إقلاع) — يعيد
 *   flutter-env/keeper.sh بناءها تلقائياً؛ حتى اكتمال البناء تُقدَّم لوحة
 *   «المعاينة غير مبنية بعد» بدل الـ404.
 * - ووضع التطوير السريع (الخيار ب — flutter run -d web-server): أوقف هذه
 *   الخدمة أولاً (pkill -f static-preview) لأن كليهما يملك المنفذ 3000.
 * =============================================================================
 */
const fs = require("fs");
const pathMod = require("path");

const PROJECT_ROOT = pathMod.resolve(import.meta.dir, "..", "..");
const PUBLIC_DIR = pathMod.join(PROJECT_ROOT, "public");
const APP_INDEX = pathMod.join(PUBLIC_DIR, "mobile_app", "index.html");
const PUBSPEC = pathMod.join(PROJECT_ROOT, "mobile_app", "pubspec.yaml");

const MIME: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".json": "application/json",
  ".webmanifest": "application/manifest+json",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".css": "text/css; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
  ".frag": "text/plain; charset=utf-8",
  ".bin": "application/octet-stream",
};

/** إصدار التطبيق من pubspec.yaml (مثل 0.11.2+12). */
function appVersion(): string {
  try {
    const m = fs.readFileSync(PUBSPEC, "utf8").match(/^version:\s*(\S+)$/m);
    return m ? m[1] : "؟";
  } catch {
    return "؟";
  }
}

function buildExists(): boolean {
  return fs.existsSync(APP_INDEX);
}

/** قراءة الملفات مع تخزين مؤقت في الذاكرة (~48MB كحد أقصى — أبخس من Next.js). */
const fileCache = new Map<string, Buffer>();
function readCached(full: string): Buffer {
  let buf = fileCache.get(full);
  if (!buf) {
    buf = fs.readFileSync(full);
    fileCache.set(full, buf);
  }
  return buf;
}

/* ================================================================== */
/* لوحة المعاينة                                                       */
/* ================================================================== */

const REPO_URL = "https://github.com/alaghbry0/finacc-flutter2";
const APK_URL = `${REPO_URL}/releases/latest/download/app-release.apk`;

function pageChrome(bodyInner: string, buildPresent: boolean): string {
  const buildChip = buildPresent
    ? `<span class="chip ok">المعاينة مبنية ✓</span>`
    : `<span class="chip warn">المعاينة غير مبنية بعد</span>`;
  return `<!doctype html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>FinAcc — المُحاسِب الشخصي</title>
<link rel="icon" href="/logo.svg" type="image/svg+xml">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: #0B1512; color: #E8F0EC;
    font-family: system-ui, "Segoe UI", Tahoma, sans-serif;
    min-height: 100vh; display: flex; flex-direction: column;
    align-items: center; gap: 22px; padding: 28px 16px 44px;
  }
  header { text-align: center; max-width: 640px; }
  .brand { display: flex; align-items: center; justify-content: center; gap: 12px; }
  .brand img { width: 40px; height: 40px; }
  header h1 { font-size: 24px; color: #C9A96A; font-weight: 800; }
  header p.sub { font-size: 13px; color: #7d938a; margin-top: 8px; line-height: 1.7; }
  .chips { display: flex; gap: 10px; justify-content: center; margin-top: 12px; flex-wrap: wrap; }
  .chip {
    display: inline-block; padding: 4px 14px; border-radius: 999px;
    font-size: 12px; border: 1px solid #23423a; color: #9db8ad;
  }
  .chip.ok { border-color: #00695C; color: #35b8a0; }
  .chip.warn { border-color: #C9A96A; color: #C9A96A; }
  .phone {
    width: 390px; max-width: 96vw; height: 780px; max-height: 76vh;
    border: 10px solid #1a2c26; border-radius: 44px;
    overflow: hidden; box-shadow: 0 24px 80px rgba(0,0,0,.55);
    background: #000;
  }
  .phone iframe { width: 100%; height: 100%; border: 0; }
  nav.links { display: flex; gap: 14px; flex-wrap: wrap; justify-content: center; }
  nav.links a {
    color: #C9A96A; text-decoration: none; font-size: 14px;
    border: 1px solid #2a463c; border-radius: 10px; padding: 8px 16px;
    transition: background .15s;
  }
  nav.links a:hover { background: #12211c; }
  footer { font-size: 12px; color: #56706a; text-align: center; max-width: 620px; line-height: 1.8; }
  .card {
    width: 560px; max-width: 94vw; background: #0F1D19; border: 1px solid #23423a;
    border-radius: 16px; padding: 26px; line-height: 2;
  }
  .card h2 { color: #C9A96A; font-size: 17px; margin-bottom: 10px; }
  .card code {
    direction: ltr; display: inline-block; background: #0B1512;
    border: 1px solid #23423a; border-radius: 6px; padding: 2px 10px;
    font-size: 13px; color: #35b8a0;
  }
  @media (max-width: 480px) { .phone { height: 80vh; border-width: 8px; } }
</style>
</head>
<body>
  <header>
    <div class="brand">
      <img src="/logo.svg" alt="FinAcc">
      <h1>FinAcc — المُحاسِب الشخصي</h1>
    </div>
    <p class="sub">نظام محاسبة ومخزون عربي RTL أوفلاين-أولاً — معاينة حية لـ Flutter Web
    تُخدَّم بخادم bun ثابت واحد (بلا Next.js، بلا node_modules، بلا خطوة بناء).</p>
    <div class="chips">
      <span class="chip">الإصدار ${appVersion()}</span>
      ${buildChip}
    </div>
  </header>
  ${bodyInner}
  <nav class="links">
    <a href="/mobile_app/index.html">فتح التطبيق بملء الشاشة ↗</a>
    <a href="${APK_URL}" rel="noopener">تنزيل آخر APK (GitHub Releases)</a>
    <a href="${REPO_URL}" rel="noopener">المستودع</a>
  </nav>
  <footer>
    البوابات قبل أي إيداع: dart analyze 0/0 · flutter test كلها خضراء · بناء المعاينة · التحقق الحي من المتصفح
  </footer>
</body>
</html>`;
}

function panelBody(): string {
  return `<div class="phone"><iframe src="/mobile_app/index.html" allow="fullscreen"></iframe></div>`;
}

function notBuiltBody(): string {
  return `<div class="card">
    <h2>المعاينة غير مبنية بعد في هذه الجلسة</h2>
    مخرجات بناء الويب (<code>public/mobile_app/</code>) غير متتبعة في git — تُمحى مع كل
    إعادة تشغيل ويعيد حارس البيئة بناءها تلقائياً عند الإقلاع. لبنائها فوراً يدوياً:
    <br><code>bash scripts/build-flutter-web.sh</code>
    <br>ثم حدِّث هذه الصفحة. (أول إقلاع بعد استنساخ جديد يستغرق دقائق —
    تابع السجل في <code>.zscripts/mini-service-flutter-env.log</code>)
  </div>`;
}

/* ================================================================== */
/* الخدمة                                                              */
/* ================================================================== */

const html = (body: string) =>
  new Response(body, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-cache" } });

Bun.serve({
  port: 3000,
  fetch: (req) => {
    const url = new URL(req.url);
    let p = decodeURIComponent(url.pathname);

    if (p === "/") {
      const present = buildExists();
      return html(pageChrome(present ? panelBody() : notBuiltBody(), present));
    }

    if (p === "/api/status") {
      return Response.json(
        { app: "finacc-static-preview", version: appVersion(), buildPresent: buildExists() },
        { headers: { "cache-control": "no-cache" } },
      );
    }

    // /mobile_app (بلا شرطة) → توجيه للجذر الفرعي
    if (p === "/mobile_app") {
      return new Response(null, { status: 301, headers: { location: "/mobile_app/" } });
    }

    if (p.endsWith("/")) p += "index.html";

    // امنع الخروج خارج الجذر (path traversal)
    const full = pathMod.join(PUBLIC_DIR, p);
    if (
      !full.startsWith(PUBLIC_DIR + pathMod.sep) ||
      !fs.existsSync(full) ||
      !fs.statSync(full).isFile()
    ) {
      return new Response("404 — غير موجود", {
        status: 404,
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    const ext = full.slice(full.lastIndexOf("."));
    // no-cache لما يتغير مع كل بناء (الاسم ثابت والملفات غير مُلبدة): html
    // وسكربت الخدمة وversion.json — والبقية تُخزَّن ساعة.
    const noCache = ext === ".html" || p.endsWith("flutter_service_worker.js") || p.endsWith("version.json");
    return new Response(readCached(full), {
      headers: {
        "content-type": MIME[ext] ?? "application/octet-stream",
        "cache-control": noCache ? "no-cache" : "public, max-age=3600",
      },
    });
  },
});

console.log(
  `[static-preview] :3000 — اللوحة / · التطبيق /mobile_app/ · الإصدار ${appVersion()} · ` +
    (buildExists() ? "البناء موجود" : "البناء غير موجود (بانتظار keeper)"),
);
