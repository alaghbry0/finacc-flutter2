"use client";

import { useCallback, useState } from "react";
import {
  BadgeCheck,
  Boxes,
  CheckCircle2,
  ExternalLink,
  Eye,
  FileCode2,
  FolderTree,
  Layers,
  ListChecks,
  Loader2,
  RefreshCw,
  Rocket,
  Server,
  ShieldCheck,
  Smartphone,
  Sparkles,
  Terminal,
  TestTube2,
} from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";

/* ------------------------------------------------------------------ */
/* بيانات حالة البيئة — مُتحقَّق منها فعلياً عبر flutter doctor        */
/* ------------------------------------------------------------------ */

const doctorChecks = [
  { label: "إطار عمل Flutter", detail: "القناة المستقرة 3.47.6", ok: true },
  { label: "سلسلة أدوات Android", detail: "Android SDK 36.0.0", ok: true },
  { label: "الويب — Chrome", detail: "نسخة 153 للمعاينة", ok: true },
  { label: "سلسلة أدوات Linux", detail: "clang 19 · CMake 3.31 · ninja", ok: true },
  { label: "أجهزة متصلة", detail: "جهازان (Linux · Chrome)", ok: true },
  { label: "موارد الشبكة", detail: "pub.dev · dl.google.com", ok: true },
] as const;

const toolchain = [
  { name: "Flutter SDK", version: "3.47.6 stable", note: "Dart 3.13.5 · DevTools 2.60" },
  { name: "Android SDK", version: "API 36", note: "build-tools 36.0.0 · platform-tools" },
  { name: "Java", version: "OpenJDK 21", note: "لتشغيل Gradle وsdkmanager" },
  { name: "سلسلة Linux", version: "clang 19 + GTK3", note: "لبناء تطبيقات سطح المكتب" },
  { name: "Chrome", version: "153", note: "لتشغيل معاينة الويب" },
  { name: "المهارات الرسمية", version: "25 مهارة", note: "10 Flutter + 15 Dart" },
] as const;

const flutterSkills = [
  "flutter-apply-architecture-best-practices",
  "flutter-setup-declarative-routing",
  "flutter-setup-localization",
  "flutter-build-responsive-layout",
  "flutter-use-http-package",
  "flutter-implement-json-serialization",
  "flutter-add-widget-test",
  "flutter-add-integration-test",
  "flutter-add-widget-preview",
  "flutter-fix-layout-issues",
] as const;

const dartSkills = [
  "dart-add-unit-test",
  "dart-run-static-analysis",
  "dart-fix-runtime-errors",
  "dart-resolve-package-conflicts",
  "dart-generate-test-mocks",
  "dart-use-pattern-matching",
  "dart-use-primary-constructors",
  "dart-write-documentation",
  "dart-use-doc-examples",
  "dart-build-cli-app",
  "dart-collect-coverage",
  "dart-use-path-package",
  "dart-setup-ffi-assets",
  "dart-use-ffigen",
  "dart-migrate-to-checks-package",
] as const;

const verificationSteps = [
  { label: "flutter doctor", result: "No issues found!", type: "ok" },
  { label: "dart analyze", result: "صفر أخطاء وتحذيرات", type: "ok" },
  { label: "flutter test", result: "اجتازت 2/2 اختبارات", type: "ok" },
  { label: "flutter build web --release", result: "اكتمل البناء (40MB)", type: "ok" },
] as const;

const projectTree = `mobile_app/
├── lib/
│   ├── main.dart              ← نقطة الدخول + تسجيل ViewModels
│   ├── app.dart               ← MaterialApp.router + التوطين
│   ├── l10n/                  ← app_en.arb · app_ar.arb
│   ├── data/                  ← services · repositories · models
│   ├── domain/                ← use_cases · models
│   └── ui/
│       ├── core/              ← theme · router
│       └── features/home/     ← views · view_models
├── test/widget_test.dart      ← اختبارات Widgets
├── pubspec.yaml               ← go_router · provider · l10n
└── analysis_options.yaml      ← flutter_lints 6` as const;

/* ------------------------------------------------------------------ */
/* عناصر واجهة مساعدة                                                 */
/* ------------------------------------------------------------------ */

function FlutterMark({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 48 60" aria-hidden="true" className={className} fill="none">
      <path d="M31 2 47 18 19 46H3l12-12L3 22 15 10l16 16 8-8-16-16z" clipRule="evenodd" />
      <path d="M31 2 15 18l12 12-8 8 12 8 16-16L31 2z" fillOpacity="0.55" clipRule="evenodd" />
    </svg>
  );
}

function SectionTitle({
  icon: Icon,
  title,
  subtitle,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  subtitle: string;
}) {
  return (
    <div className="mb-4 flex items-start gap-3">
      <div className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-teal-600/10 text-teal-700 dark:bg-teal-400/10 dark:text-teal-300">
        <Icon className="h-5 w-5" />
      </div>
      <div>
        <h2 className="text-lg font-bold tracking-tight">{title}</h2>
        <p className="text-sm text-muted-foreground">{subtitle}</p>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* الصفحة                                                             */
/* ------------------------------------------------------------------ */

export default function FlutterEnvDashboard() {
  const [iframeKey, setIframeKey] = useState(0);
  const [reloading, setReloading] = useState(false);

  const refreshPreview = useCallback(() => {
    setReloading(true);
    setIframeKey((k) => k + 1);
    window.setTimeout(() => setReloading(false), 900);
  }, []);

  return (
    <div
      dir="rtl"
      lang="ar"
      className="flex min-h-screen flex-col bg-gradient-to-b from-teal-50/60 via-background to-background dark:from-teal-950/20"
    >
      {/* ============================ الترويسة ============================ */}
      <header className="sticky top-0 z-40 border-b bg-background/80 backdrop-blur-md">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3 sm:px-6">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-teal-600 to-emerald-700 text-white shadow-md shadow-teal-600/20">
              <FlutterMark className="h-6 w-6 fill-current" />
            </div>
            <div>
              <p className="text-sm font-bold leading-tight">مشروع تطبيق الهاتف المتكامل</p>
              <p className="text-xs text-muted-foreground">Flutter · Clean Architecture</p>
            </div>
          </div>
          <div className="hidden items-center gap-2 sm:flex">
            <Badge variant="secondary" className="gap-1.5 font-mono text-xs">
              <Terminal className="h-3 w-3" /> Flutter 3.47.6
            </Badge>
            <Badge variant="secondary" className="gap-1.5 font-mono text-xs">
              Dart 3.13.5
            </Badge>
            <Badge className="gap-1.5 bg-teal-600 hover:bg-teal-600">
              <BadgeCheck className="h-3 w-3" /> البيئة جاهزة
            </Badge>
          </div>
        </div>
      </header>

      <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-8 sm:px-6">
        {/* ============================ البطل ============================ */}
        <section className="mb-10 text-center sm:mb-12">
          <div className="mx-auto mb-4 inline-flex items-center gap-2 rounded-full border border-teal-600/20 bg-teal-600/5 px-4 py-1.5 text-xs font-semibold text-teal-700 dark:border-teal-400/20 dark:bg-teal-400/10 dark:text-teal-300">
            <Sparkles className="h-3.5 w-3.5" />
            اكتملت مرحلة التهيئة والتجهيز بنجاح
          </div>
          <h1 className="mx-auto max-w-2xl text-3xl font-extrabold leading-tight tracking-tight sm:text-4xl">
            بيئة تطوير Flutter{" "}
            <span className="bg-gradient-to-l from-teal-600 to-emerald-500 bg-clip-text text-transparent dark:from-teal-400 dark:to-emerald-300">
              جاهزة بالكامل
            </span>
          </h1>
          <p className="mx-auto mt-3 max-w-xl text-sm leading-relaxed text-muted-foreground sm:text-base">
            حزمة المهارات الرسمية مثبتة، ووثائق Flutter للعمل مع الذكاء الاصطناعي روجعت، والهيكل
            المعماري النظيف أُنشئ واجتاز التحليل الساكن والاختبارات — بانتظار وثيقة المتطلبات
            لنبدأ البناء.
          </p>
          <div className="mt-6 flex flex-wrap items-center justify-center gap-3">
            <Button
              asChild
              size="lg"
              className="gap-2 bg-teal-600 hover:bg-teal-700 dark:bg-teal-500 dark:hover:bg-teal-600"
            >
              <a href="#preview" id="preview-btn">
                <Eye className="h-4 w-4" />
                شاهد التطبيق مباشرة
              </a>
            </Button>
            <Button asChild size="lg" variant="outline" className="gap-2">
              <a href="/mobile_app/index.html" target="_blank" rel="noopener noreferrer">
                <ExternalLink className="h-4 w-4" />
                فتح بملء الشاشة
              </a>
            </Button>
          </div>
        </section>

        {/* ================== حالة flutter doctor ================== */}
        <section className="mb-10">
          <SectionTitle
            icon={ShieldCheck}
            title="نتيجة flutter doctor — لا مشاكل"
            subtitle="جميع الفحوصات الست ناجحة في هذه البيئة المعزولة"
          />
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {doctorChecks.map((check) => (
              <Card key={check.label} className="border-emerald-600/20 bg-emerald-500/[0.04]">
                <CardContent className="flex items-center gap-3 p-4">
                  <CheckCircle2 className="h-5 w-5 shrink-0 text-emerald-600 dark:text-emerald-400" />
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold">{check.label}</p>
                    <p className="truncate font-mono text-xs text-muted-foreground">
                      {check.detail}
                    </p>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </section>

        {/* ================ المعاينة الحية داخل هاتف ================ */}
        <section id="preview" className="mb-10 scroll-mt-24">
          <SectionTitle
            icon={Smartphone}
            title="معاينة حية — التطبيق يعمل الآن"
            subtitle="بناء ويب حقيقي لنفس الكود المترجم لـ Android/iOS، يعرضه متصفحك حسب لغته (عربي RTL أو إنجليزي)"
          />
          <div className="grid grid-cols-1 items-start gap-6 lg:grid-cols-[minmax(0,320px)_minmax(0,1fr)]">
            {/* إطار الهاتف */}
            <div className="mx-auto w-full max-w-[320px]">
              <div className="relative rounded-[2.75rem] border-[10px] border-neutral-900 bg-neutral-900 shadow-2xl shadow-neutral-900/30 dark:border-neutral-800">
                <div className="absolute inset-x-0 top-0 z-10 flex h-7 items-center justify-center">
                  <div className="h-4 w-24 rounded-b-2xl bg-neutral-900 dark:bg-neutral-800" />
                </div>
                <div className="relative aspect-[9/19.2] overflow-hidden rounded-[2rem] bg-white">
                  {reloading && (
                    <div className="absolute inset-0 z-20 flex items-center justify-center bg-white/85 backdrop-blur-sm dark:bg-neutral-900/85">
                      <Loader2 className="h-8 w-8 animate-spin text-teal-600" />
                    </div>
                  )}
                  <iframe
                    key={iframeKey}
                    src="/mobile_app/index.html"
                    title="معاينة تطبيق Flutter"
                    className="h-full w-full border-0"
                    loading="lazy"
                  />
                </div>
              </div>
              <div className="mt-4 flex items-center justify-center gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={refreshPreview}
                  className="gap-2"
                  aria-label="تحديث المعاينة"
                >
                  <RefreshCw className={`h-3.5 w-3.5 ${reloading ? "animate-spin" : ""}`} />
                  تحديث
                </Button>
                <Button asChild variant="ghost" size="sm" className="gap-2">
                  <a href="/mobile_app/index.html" target="_blank" rel="noopener noreferrer">
                    <ExternalLink className="h-3.5 w-3.5" />
                    تبويب جديد
                  </a>
                </Button>
              </div>
            </div>

            {/* لوحة التحقق */}
            <div className="space-y-4">
              <Card>
                <CardHeader className="pb-3">
                  <CardTitle className="flex items-center gap-2 text-base">
                    <ListChecks className="h-4 w-4 text-teal-600 dark:text-teal-400" />
                    بوابات الجودة المكتملة
                  </CardTitle>
                  <CardDescription>
                    كل أمر تم تشغيله فعلياً داخل البيئة قبل عرض هذه اللوحة
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-2">
                  {verificationSteps.map((step) => (
                    <div
                      key={step.label}
                      className="flex flex-wrap items-center justify-between gap-2 rounded-lg border bg-muted/40 px-3 py-2"
                    >
                      <code className="font-mono text-xs font-semibold">{step.label}</code>
                      <Badge
                        variant="secondary"
                        className="gap-1 border-emerald-600/20 bg-emerald-500/10 text-emerald-700 dark:text-emerald-300"
                      >
                        <CheckCircle2 className="h-3 w-3" />
                        {step.result}
                      </Badge>
                    </div>
                  ))}
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-3">
                  <CardTitle className="flex items-center gap-2 text-base">
                    <Rocket className="h-4 w-4 text-teal-600 dark:text-teal-400" />
                    دورة التطوير داخل البيئة
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-2 text-sm text-muted-foreground">
                  <p className="flex items-start gap-2">
                    <FileCode2 className="mt-0.5 h-4 w-4 shrink-0 text-teal-600/70" />
                    كتابة كود Dart في <code className="font-mono text-xs">mobile_app/lib</code> ثم
                    تنفيذ{" "}
                    <code className="font-mono text-xs">scripts/build-flutter-web.sh</code>{" "}
                    وتحديث المعاينة — بدون إعادة تشغيل خادم.
                  </p>
                  <p className="flex items-start gap-2">
                    <Boxes className="mt-0.5 h-4 w-4 shrink-0 text-teal-600/70" />
                    حزمة Android (APK) تُبنى مباشرة عبر Gradle المدمج عند الحاجة للتسليم.
                  </p>
                  <p className="flex items-start gap-2">
                    <Server className="mt-0.5 h-4 w-4 shrink-0 text-teal-600/70" />
                    الـ keeper يعيد تفعيل SDK تلقائياً بعد أي إعادة تشغيل للحاوية.
                  </p>
                </CardContent>
              </Card>
            </div>
          </div>
        </section>

        {/* ==================== سلسلة الأدوات ==================== */}
        <section className="mb-10">
          <SectionTitle
            icon={Layers}
            title="مكونات سلسلة الأدوات"
            subtitle="كل ما يلزم للبناء إلى Android وiOS والويب وسطح المكتب"
          />
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
            {toolchain.map((tool) => (
              <Card key={tool.name} className="text-center">
                <CardContent className="p-4">
                  <p className="text-xs text-muted-foreground">{tool.name}</p>
                  <p className="mt-1 text-sm font-bold text-teal-700 dark:text-teal-300">
                    {tool.version}
                  </p>
                  <p className="mt-1 text-[11px] leading-snug text-muted-foreground">
                    {tool.note}
                  </p>
                </CardContent>
              </Card>
            ))}
          </div>
        </section>

        {/* ==================== المهارات الرسمية ==================== */}
        <section className="mb-10 grid grid-cols-1 gap-6 lg:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base">
                <Sparkles className="h-4 w-4 text-teal-600 dark:text-teal-400" />
                مهارات Flutter الرسمية
                <Badge variant="secondary" className="ml-auto font-mono">
                  {flutterSkills.length}
                </Badge>
              </CardTitle>
              <CardDescription>
                من مستودع <code className="font-mono text-xs">flutter/agent-plugins</code> — مراجع
                إجرائية معتمدة للتوجيه أثناء التطوير
              </CardDescription>
            </CardHeader>
            <CardContent>
              <ul className="max-h-72 space-y-1.5 overflow-y-auto pl-1 [scrollbar-width:thin] [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-teal-600/30 [&::-webkit-scrollbar]:w-1.5">
                {flutterSkills.map((skill) => (
                  <li
                    key={skill}
                    className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs transition-colors hover:bg-muted"
                  >
                    <CheckCircle2 className="h-3.5 w-3.5 shrink-0 text-emerald-600 dark:text-emerald-400" />
                    <code className="font-mono">{skill}</code>
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base">
                <TestTube2 className="h-4 w-4 text-teal-600 dark:text-teal-400" />
                مهارات Dart الرسمية
                <Badge variant="secondary" className="ml-auto font-mono">
                  {dartSkills.length}
                </Badge>
              </CardTitle>
              <CardDescription>
                من مستودع <code className="font-mono text-xs">dart-lang/skills</code> — جودة
                الاختبارات والتحليل الساكن وحل التعارضات
              </CardDescription>
            </CardHeader>
            <CardContent>
              <ul className="max-h-72 space-y-1.5 overflow-y-auto pl-1 [scrollbar-width:thin] [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-teal-600/30 [&::-webkit-scrollbar]:w-1.5">
                {dartSkills.map((skill) => (
                  <li
                    key={skill}
                    className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs transition-colors hover:bg-muted"
                  >
                    <CheckCircle2 className="h-3.5 w-3.5 shrink-0 text-emerald-600 dark:text-emerald-400" />
                    <code className="font-mono">{skill}</code>
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>
        </section>

        {/* ==================== هيكل المشروع ==================== */}
        <section className="mb-10">
          <SectionTitle
            icon={FolderTree}
            title="الهيكل المعماري النظيف"
            subtitle="طبقات UI / Domain / Data وفق مهارة البنية المعمارية الرسمية — جاهز لاستقبال ميزات SRS"
          />
          <Card className="overflow-hidden">
            <CardContent className="p-0">
              <div
                dir="ltr"
                className="max-h-96 overflow-auto bg-neutral-950 p-5 font-mono text-xs leading-relaxed text-neutral-200 [scrollbar-width:thin] [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-neutral-700 [&::-webkit-scrollbar]:w-2 [&::-webkit-scrollbar]:h-2"
              >
                <pre className="whitespace-pre">{projectTree}</pre>
              </div>
            </CardContent>
          </Card>
        </section>

        {/* ==================== الخطوة التالية ==================== */}
        <section className="mb-4">
          <SectionTitle
            icon={Sparkles}
            title="الخطوة التالية — وثيقة المتطلبات (SRS)"
            subtitle="شاركني المواصفات: الفكرة، الجمهور، الميزات الأساسية، واللغات المستهدفة"
          />
          <Card className="border-teal-600/25 bg-gradient-to-l from-teal-600/[0.06] to-transparent">
            <CardContent className="grid grid-cols-1 gap-3 p-5 sm:grid-cols-3">
              {[
                { n: "1", t: "أرسل وثيقة SRS", d: "الميزات، التدفقات، والمعايير غير الوظيفية" },
                { n: "2", t: "نفاوض على النطاق", d: "MVP أولاً ثم خارطة طريق للتكرارات" },
                { n: "3", t: "نبدأ البناء فوراً", d: "ميزة-بميزة مع اختبارات وتحليل نظيف" },
              ].map((step) => (
                <div key={step.n} className="flex items-start gap-3 rounded-xl border bg-background/60 p-4">
                  <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-teal-600 text-xs font-bold text-white dark:bg-teal-500">
                    {step.n}
                  </span>
                  <div>
                    <p className="text-sm font-bold">{step.t}</p>
                    <p className="mt-0.5 text-xs text-muted-foreground">{step.d}</p>
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>
        </section>
      </main>

      {/* ============================ التذييل ============================ */}
      <footer className="mt-auto border-t bg-background/80">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-2 px-4 py-5 text-center text-xs text-muted-foreground sm:flex-row sm:px-6 sm:text-start">
          <p>
            بيئة Flutter مُدارة بواسطة{" "}
            <code className="font-mono text-teal-700 dark:text-teal-300">
              mini-services/flutter-env
            </code>{" "}
            — تعيد تفعيل ذاتياً بعد كل إعادة تشغيل
          </p>
          <Separator className="hidden h-4 w-px sm:block" orientation="vertical" />
          <p className="shrink-0">جاهز لاستلام وثيقة المتطلبات والبدء 🚀</p>
        </div>
      </footer>
    </div>
  );
}
