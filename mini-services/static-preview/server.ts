/**
 * static-preview/server.ts — خادم المعاينة الثابت (R21 → R22: التطبيق في الجذر).
 * =============================================================================
 * بديل لوحة Next.js بالكامل: خادم bun واحد بلا تبعيات وبلا خطوة بناء.
 *
 *   /                 → تطبيق Flutter Web مباشرة في جذر البوابة (R22 — كان لوحة
 *                        إطار الهاتف في R21) — مخرجات public/mobile_app بلا بادئة
 *   /mobile_app(/…)   → توجيه 301 إلى / (توافق روابط R21 القديمة)
 *   /api/status       → {version, buildPresent} — فحص صحة/حالة للوكيل
 *   /logo.svg, /robots.txt → من جذر public/
 *
 * - مخرجات public/mobile_app غير متتبعة في git (تُمحى مع كل إقلاع) — يعيد
 *   flutter-env/keeper.sh بناءها تلقائياً؛ حتى اكتمال البناء تُقدَّم بطاقة
 *   «المعاينة غير مبنية بعد» بدل الـ404.
 * - الكاش في الذاكرة يتحقق من mtime/size لكل ملف قبل تقديمه — إعادة البناء
 *   في منتصف الجلسة تظهر فوراً بعد تحديث الصفحة بلا إعادة تشغيل الخادم (R22).
 * - مسارات بلا امتداد تُسقط على index.html (SPA fallback) للروابط العميقة.
 * - يعمل كخدمة auto-boot عبر .zscripts/dev.sh → mini-services (يمتلك المنفذ
 *   3000 خلف بوابة Caddy :81) — ووضع التطوير السريع (flutter run -d
 *   web-server): أوقف هذه الخدمة أولاً (pkill -f static-preview) لأن كليهما
 *   يملك المنفذ 3000.
 * =============================================================================
 */
const fs = require("fs");
const pathMod = require("path");

const PROJECT_ROOT = pathMod.resolve(import.meta.dir, "..", "..");
const PUBLIC_DIR = pathMod.join(PROJECT_ROOT, "public");
const APP_DIR = pathMod.join(PUBLIC_DIR, "mobile_app");
const APP_INDEX = pathMod.join(APP_DIR, "index.html");
const PUBSPEC = pathMod.join(PROJECT_ROOT, "mobile_app", "pubspec.yaml");
const LEGACY_PREFIX = "/mobile_app";

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
  ".woff": "font/woff",
  ".woff2": "font/woff2",
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

/**
 * كاش الذاكرة مع تحقق mtime/size لكل ملف (R22): إعادة بناء في منتصف الجلسة
 * تُقدَّم فوراً بعد تحديث الصفحة — لا حاجة لإعادة تشغيل الخادم بعد كل بناء.
 */
const fileCache = new Map<string, { mtime: number; size: number; buf: Buffer }>();
function readCached(full: string): Buffer {
  const st = fs.statSync(full);
  const hit = fileCache.get(full);
  if (hit && hit.mtime === st.mtimeMs && hit.size === st.size) return hit.buf;
  const buf = fs.readFileSync(full);
  fileCache.set(full, { mtime: st.mtimeMs, size: st.size, buf });
  return buf;
}

/* ================================================================== */
/* بطاقة «المعاينة غير مبنية بعد» (حتى يكتمل بناء الحارس)                */
/* ================================================================== */

const REPO_URL = "https://github.com/alaghbry0/finacc-flutter2";
const APK_URL = `${REPO_URL}/releases/latest/download/app-release.apk`;

function notBuiltPage(): string {
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
  .chip { display: inline-block; padding: 4px 14px; border-radius: 999px; font-size: 12px; border: 1px solid #23423a; color: #9db8ad; }
  .chip.warn { border-color: #C9A96A; color: #C9A96A; }
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
  nav.links { display: flex; gap: 14px; flex-wrap: wrap; justify-content: center; }
  nav.links a {
    color: #C9A96A; text-decoration: none; font-size: 14px;
    border: 1px solid #2a463c; border-radius: 10px; padding: 8px 16px;
    transition: background .15s;
  }
  nav.links a:hover { background: #12211c; }
  footer { font-size: 12px; color: #56706a; text-align: center; max-width: 620px; line-height: 1.8; }
</style>
</head>
<body>
  <header>
    <div class="brand">
      <img src="/logo.svg" alt="FinAcc">
      <h1>FinAcc — المُحاسِب الشخصي</h1>
    </div>
    <p class="sub">نظام محاسبة ومخزون عربي RTL أوفلاين-أولاً — تطبيق Flutter Web
    يُقدَّم في جذر البوابة مباشرة (R22) بخادم bun ثابت واحد بلا Next.js.</p>
    <div class="chips">
      <span class="chip">الإصدار ${appVersion()}</span>
      <span class="chip warn">المعاينة غير مبنية بعد</span>
    </div>
  </header>
  <div class="card">
    <h2>المعاينة غير مبنية بعد في هذه الجلسة</h2>
    مخرجات بناء الويب (<code>public/mobile_app/</code>) غير متتبعة في git — تُمحى مع كل
    إعادة تشغيل ويعيد حارس البيئة بناءها تلقائياً عند الإقلاع. لبنائها فوراً يدوياً:
    <br><code>bash scripts/build-flutter-web.sh</code>
    <br>ثم حدِّث هذه الصفحة. (أول إقلاع بعد استنساخ جديد يستغرق دقائق —
    تابع السجل في <code>.zscripts/mini-service-flutter-env.log</code>)
  </div>
  <nav class="links">
    <a href="${APK_URL}" rel="noopener">تنزيل آخر APK (GitHub Releases)</a>
    <a href="${REPO_URL}" rel="noopener">المستودع</a>
  </nav>
  <footer>
    البوابات قبل أي إيداع: dart analyze 0/0 · flutter test كلها خضراء · بناء المعاينة · التحقق الحي من المتصفح
  </footer>
</body>
</html>`;
}

/* ================================================================== */
/* الخدمة                                                              */
/* ================================================================== */

/**
 * استراتيجية الكاش (R25 — إصلاح «البوابة تعرض الإصدار القديم»):
 *
 * المشكلة كانت: ملفات الدخول بأسماء ثابتة تختلف محتوياتها مع كل بناء
 * (main.dart.js / flutter_bootstrap.js / flutter.js / manifests …) كانت
 * تُقدَّم بـ `max-age=3600` فيحتفظ متصفح المستخدم بالنسخة القديمة حتى
 * ساعة كاملة بعد كل إيداع جديد — فيرى «الإصدار القديم» رغم أن الخادم
 * يقدّم الجديد. (لا علاقة للـ Service Worker بالعلة: SW فلاتر 3.47
 * الحديث kill-pill يسجّل نفسه ثم يحذفه ويعيد تحميل الصفحات — لا يخزّن
 * شيئاً.)
 *
 * الحل: كل ملف اسمه ثابت ومحتواه متغير مع البناء = `no-cache` (إعادة
 * تحقق دائمة) + **ETag** مشتق من mtime+size مع دعم If-None-Match → 304.
 * هكذا التحديث يظهر فور أول إعادة تحميل، وإعادة التحقق شبه مجانية
 * (304 بلا جسم) عندما لم يتغير شيء. الملفات الضخمة المستقرة فعلاً
 * (canvaskit/الخطوط/pdfjs/الأيقونات) تبقى بـ max-age=3600.
 */
const NO_CACHE_BASENAMES = new Set([
  "flutter_bootstrap.js",
  "flutter.js",
  "main.dart.js",
  "manifest.json",
  "flutter_service_worker.js",
  "version.json",
  "sqflite_sw.js",
  "assetmanifest.bin",
  "assetmanifest.bin.json",
  "fontmanifest.json",
]);

const html = (body: string) =>
  new Response(body, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-cache" } });

function serveFile(full: string, req?: Request): Response {
  const ext = full.slice(full.lastIndexOf("."));
  const base = pathMod.basename(full).toLowerCase();
  // no-cache لكل ما يتغير مع كل بناء رغم ثبات اسمه؛ والبقية تُخزّن ساعة.
  const noCache =
    ext === ".html" ||
    NO_CACHE_BASENAMES.has(base) ||
    full.endsWith("flutter_service_worker.js") ||
    full.endsWith("version.json");
  const st = fs.statSync(full);
  const etag = `"${st.mtimeMs.toString(36)}-${st.size.toString(36)}"`;
  const headers: Record<string, string> = {
    "content-type": MIME[ext] ?? "application/octet-stream",
    "cache-control": noCache ? "no-cache" : "public, max-age=3600",
    etag,
  };
  // إعادة تحقق رخيصة: المتصفح أرسل If-None-Match مطابقاً → 304 بلا جسم.
  if (req && req.headers.get("if-none-match") === etag) {
    return new Response(null, { status: 304, headers });
  }
  return new Response(readCached(full), { headers });
}

/** حل مسار آمن داخل قاعدة معينة (يمنع path traversal) ويعيد null إن لم يكن ملفاً. */
function safeFile(base: string, rel: string): string | null {
  const full = pathMod.join(base, rel);
  if (!full.startsWith(base + pathMod.sep)) return null;
  try {
    if (!fs.statSync(full).isFile()) return null;
  } catch {
    return null;
  }
  return full;
}

Bun.serve({
  port: 3000,
  fetch: (req) => {
    const url = new URL(req.url);
    let p = decodeURIComponent(url.pathname);

    if (p === "/api/status") {
      return Response.json(
        { app: "finacc-static-preview", version: appVersion(), buildPresent: buildExists(), appAtRoot: true },
        { headers: { "cache-control": "no-cache" } },
      );
    }

    // توافق روابط R21 القديمة: /mobile_app(/…) → /(…)
    if (p === LEGACY_PREFIX) {
      return new Response(null, { status: 301, headers: { location: "/" } });
    }
    if (p.startsWith(LEGACY_PREFIX + "/")) {
      const rest = p.slice(LEGACY_PREFIX.length + 1);
      return new Response(null, {
        status: 301,
        headers: { location: rest === "" || rest === "index.html" ? "/" : `/${rest}` },
      });
    }

    // ملفات جذر public (الشعار وrobots)
    if (p === "/logo.svg" || p === "/robots.txt") {
      const full = safeFile(PUBLIC_DIR, p);
      if (full) return serveFile(full, req);
    }

    // الجذر: التطبيق مباشرة (R22)، أو بطاقة «غير مبنية» بانتظار الحارس
    if (p === "/") {
      if (buildExists()) return serveFile(APP_INDEX, req);
      return html(notBuiltPage());
    }
    if (p.endsWith("/")) p += "index.html";

    // ملفات التطبيق (main.dart.js / assets / canvaskit / wasm / خطوط ...)
    const appFile = safeFile(APP_DIR, p);
    if (appFile) return serveFile(appFile, req);

    // مسار بلا امتداد = مسار SPA → index.html (للروابط العميقة المستقبلية)
    if (buildExists() && pathMod.extname(p) === "") return serveFile(APP_INDEX, req);

    return new Response("404 — غير موجود", {
      status: 404,
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  },
});

console.log(
  `[static-preview] :3000 — التطبيق في الجذر / (R22) · الإصدار ${appVersion()} · ` +
    (buildExists() ? "البناء موجود" : "البناء غير موجود (بانتظار keeper)"),
);
