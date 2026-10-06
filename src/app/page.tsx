"use client";

import { useCallback, useEffect, useState } from "react";

import {
  BadgeCheck,
  Braces,
  CheckCircle2,
  CreditCard,
  Database,
  ExternalLink,
  Fingerprint,
  FlaskConical,
  Info,
  Package,
  RefreshCw,
  Smartphone,
  Sparkles,
  Terminal,
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
import { Skeleton } from "@/components/ui/skeleton";

/* ================================================================== */
/* الثوابت                                                              */
/* ================================================================== */

const PREVIEW_URL = "/mobile_app/index.html";

/* لوحة الألوان — Premium Fintech داكن (أخضر مالي + ذهبي):             */
/* خلفيات #0B1512 / #0F1D19 · بذرة #00695C · ذهبي #C9A96A · نص #E8F0EC */

/* ================================================================== */
/* عناصر مساعدة                                                         */
/* ================================================================== */

/** شعار FinAcc — دفتر حسابات وقطعة نقد داخل دائرة بلمسة ذهبية. */
function FinAccMark({
  idSuffix,
  className,
}: {
  idSuffix: string;
  className?: string;
}) {
  const emeraldId = `fa-emerald-${idSuffix}`;
  const goldId = `fa-gold-${idSuffix}`;
  return (
    <svg
      viewBox="0 0 48 48"
      aria-hidden="true"
      className={className}
      fill="none"
      role="presentation"
    >
      <defs>
        <linearGradient id={emeraldId} x1="4" y1="4" x2="44" y2="44" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#0E4A40" />
          <stop offset="1" stopColor="#00695C" />
        </linearGradient>
        <linearGradient id={goldId} x1="14" y1="9" x2="34" y2="29" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#E3C88F" />
          <stop offset="1" stopColor="#C9A96A" />
        </linearGradient>
      </defs>
      {/* الإطار الدائري بحلقة ذهبية */}
      <circle cx="24" cy="24" r="21.5" fill={`url(#${emeraldId})`} stroke={`url(#${goldId})`} strokeWidth="1.5" />
      {/* قطعة نقد ذهبية أعلى الدفتر */}
      <circle cx="24" cy="16.5" r="5.5" stroke={`url(#${goldId})`} strokeWidth="2" />
      <path d="M20.5 16.5h7" stroke={`url(#${goldId})`} strokeWidth="1.25" strokeLinecap="round" />
      {/* سطور دفتر الحسابات */}
      <path d="M14 27.5h20" stroke="#E8F0EC" strokeWidth="2" strokeLinecap="round" opacity="0.95" />
      <path d="M14 33h20" stroke="#E8F0EC" strokeWidth="2" strokeLinecap="round" opacity="0.7" />
      <path d="M14 38.5h12" stroke="#E8F0EC" strokeWidth="2" strokeLinecap="round" opacity="0.45" />
    </svg>
  );
}

/** مقطع رمزي (أسماء جداول وأوامر) باتجاه LTR داخل النص العربي. */
function Mono({ children }: { children: React.ReactNode }) {
  return (
    <code
      dir="ltr"
      className="mx-1 inline-block rounded-md bg-[#16302A] px-1.5 py-0.5 font-mono text-[11px] leading-5 text-[#8FD9C6] ring-1 ring-inset ring-[#1E332D]"
    >
      {children}
    </code>
  );
}

/** عنوان قسم موحّد. */
function SectionHeading({
  icon: Icon,
  kicker,
  title,
  subtitle,
}: {
  icon: React.ComponentType<{ className?: string }>;
  kicker?: string;
  title: string;
  subtitle?: string;
}) {
  return (
    <div className="mb-5 flex items-start gap-3">
      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-[#C9A96A]/25 bg-[#00695C]/15 text-[#4DBFA8] shadow-inner shadow-black/30">
        <Icon className="h-5 w-5" />
      </div>
      <div className="min-w-0">
        {kicker && (
          <p className="text-[11px] font-bold tracking-wide text-[#C9A96A]">{kicker}</p>
        )}
        <h2 className="text-lg font-extrabold leading-snug text-[#E8F0EC] sm:text-xl">
          {title}
        </h2>
        {subtitle && (
          <p className="mt-0.5 text-xs leading-relaxed text-[#9DB5AC] sm:text-sm">{subtitle}</p>
        )}
      </div>
    </div>
  );
}

/** بند إنجاز بعلامة إتمام. */
function DoneItem({ children }: { children: React.ReactNode }) {
  return (
    <li className="flex items-start gap-2.5 rounded-xl border border-[#1E332D]/70 bg-[#0B1512]/70 px-3.5 py-3">
      <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-[#4DBFA8]" aria-hidden="true" />
      <p className="text-sm leading-relaxed text-[#D7E4DE]">{children}</p>
    </li>
  );
}

/* ================================================================== */
/* بيانات الأقسام                                                       */
/* ================================================================== */

const slice0Items: React.ReactNode[] = [
  <>
    تعريف <Mono>34</Mono> جدولاً عبر DDL وفق <Mono>SRS §5.3</Mono> — المخطط
    البياني الكامل للنظام
  </>,
  <>
    وضع <Mono>WAL</Mono> مفعّل لتحسين أداء الكتابة والقراءة المتزامنة
  </>,
  <>
    جدول الترقيم الذري <Mono>doc_sequence</Mono> بعملية <Mono>UPSERT</Mono> ذرّية
    لضمان تسلسل المستندات دون تصادم
  </>,
  <>
    مشغّلات حماية سجل التدقيق <Mono>audit_log</Mono> — منع <Mono>UPDATE</Mono> و
    <Mono>DELETE</Mono> نهائياً
  </>,
  <>
    هجرات مُدارة عبر جدول <Mono>_migrations</Mono> قابلة لإعادة التشغيل بأمان
  </>,
  <>
    بذور العملات (<Mono>YER/SAR/USD/AED</Mono>) والإعدادات الافتراضية جاهزة
    منذ أول إقلاع
  </>,
];

const slice1Items: React.ReactNode[] = [
  <>
    هوية <Mono>Almarai</Mono> الطباعية مع بذرة اللون <Mono>0xFF00695C</Mono> بوضعين
    فاتح وداكن
  </>,
  <>
    شاشة <Mono>Onboarding</Mono> لإنشاء المنشأة مع توليد المخزن والصندوق
    الافتراضيين تلقائياً
  </>,
  <>
    إعداد وقفل رمز <Mono>PIN</Mono> بسياسة القفل: <Mono>5</Mono> محاولات ← تأخير
    متصاعد، و<Mono>10</Mono> ← عبارة مرور
  </>,
  <>
    لوحة التحكم الرئيسية (Dashboard) ببلاطات الإحصاء ورسم بياني لآخر
    <Mono>30</Mono> يوماً
  </>,
  <>شريط تبويب سفلي بخمسة أقسام رئيسية للتطبيق</>,
];

const qualityGates = [
  {
    icon: Terminal,
    name: "dart analyze",
    result: "صفر أخطاء وصفر تحذيرات",
  },
  {
    icon: FlaskConical,
    name: "flutter test",
    result: "كافة الاختبارات خضراء",
  },
  {
    icon: Braces,
    name: "dart format",
    result: "تنسيق قياسي",
  },
  {
    icon: Smartphone,
    name: "المعاينة الحية",
    result: "تعمل داخل إطار الهاتف",
  },
] as const;

/* ================================================================== */
/* الصفحة                                                               */
/* ================================================================== */

export default function FinAccStage1DeliveryPanel() {
  const [iframeKey, setIframeKey] = useState(0);
  const [loading, setLoading] = useState(true);

  /**
   * منطق التحديث: رفع key الـ iframe يجعل React يفكّ العنصر القديم ويركّب
   * عنصراً جديداً بنفس src → المتصفح يحمّل المستند من جديد بالكامل، ثم
   * يُطلق onLoad فتُخفى الهيكل (skeleton). شبكة أمان زمنية تخفي الهيكل
   * بعد 15 ثانية كحد أقصى حتى لو تأخر الحدث لأي سبب.
   */
  const handleFrameLoad = useCallback(() => {
    setLoading(false);
  }, []);

  const refreshPreview = useCallback(() => {
    setLoading(true);
    setIframeKey((k) => k + 1);
  }, []);

  useEffect(() => {
    if (!loading) return;
    const timer = window.setTimeout(() => setLoading(false), 15_000);
    return () => window.clearTimeout(timer);
  }, [loading]);

  return (
    <div
      dir="rtl"
      lang="ar"
      className="relative flex min-h-screen flex-col bg-[#0B1512] text-[#E8F0EC]"
    >
      {/* ======================= زخرفة الخلفية ======================= */}
      <div aria-hidden="true" className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="absolute -top-36 right-[-12%] h-[460px] w-[560px] rounded-full bg-[#00695C]/[0.14] blur-[130px]" />
        <div className="absolute bottom-[-14%] left-[-10%] h-[400px] w-[440px] rounded-full bg-[#C9A96A]/[0.05] blur-[120px]" />
        <div className="absolute left-1/2 top-0 h-px w-full max-w-3xl -translate-x-1/2 bg-gradient-to-r from-transparent via-[#C9A96A]/30 to-transparent" />
      </div>

      {/* =========================== الترويسة =========================== */}
      <header className="sticky top-0 z-40 border-b border-[#C9A96A]/15 bg-[#0B1512]/85 backdrop-blur-md">
        <div className="mx-auto flex max-w-6xl items-center gap-3 px-4 py-3 sm:px-6">
          <div className="flex min-w-0 flex-1 items-center gap-3">
            <FinAccMark idSuffix="header" className="h-10 w-10 shrink-0 drop-shadow-[0_4px_12px_rgba(0,105,92,0.45)]" />
            <div className="min-w-0">
              <p className="truncate text-sm font-extrabold leading-tight text-[#E8F0EC] sm:text-base">
                FinAcc — المُحاسِب الشخصي
              </p>
              <p className="truncate text-[11px] text-[#9DB5AC]">لوحة تسليم المرحلة الأولى</p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <div className="hidden items-center gap-2 md:flex">
              <Badge className="gap-1.5 border-transparent bg-[#00695C]/30 px-3 py-1 text-[11px] font-bold text-[#8FD9C6]">
                <Sparkles className="h-3 w-3" aria-hidden="true" />
                المرحلة الأولى — الشريحة 0 + الشريحة 1
              </Badge>
              <Badge className="gap-1.5 border-[#C9A96A]/30 bg-[#C9A96A]/10 px-3 py-1 text-[11px] font-bold text-[#E3C88F]">
                <BadgeCheck className="h-3 w-3" aria-hidden="true" />
                SRS v1.5 مُعتمدة
              </Badge>
            </div>

            <Button
              variant="outline"
              onClick={refreshPreview}
              aria-label="تحديث المعاينة الحية"
              className="h-11 gap-2 border-[#2A4A42] bg-[#0F1D19]/70 px-4 text-[#E3C88F] hover:border-[#C9A96A]/50 hover:bg-[#C9A96A]/10 hover:text-[#E3C88F] focus-visible:ring-[#4DBFA8]/40"
            >
              <RefreshCw
                className={`h-4 w-4 ${loading ? "animate-spin" : ""}`}
                aria-hidden="true"
              />
              <span className="hidden sm:inline">تحديث المعاينة</span>
            </Button>
          </div>
        </div>

        {/* شارتا المرحلة على الشاشات الصغيرة */}
        <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-2 px-4 pb-2.5 md:hidden sm:px-6">
          <Badge className="border-transparent bg-[#00695C]/30 px-2.5 py-0.5 text-[10px] font-bold text-[#8FD9C6]">
            المرحلة الأولى — الشريحة 0 + الشريحة 1
          </Badge>
          <Badge className="border-[#C9A96A]/30 bg-[#C9A96A]/10 px-2.5 py-0.5 text-[10px] font-bold text-[#E3C88F]">
            <BadgeCheck className="h-3 w-3" aria-hidden="true" />
            SRS v1.5 مُعتمدة
          </Badge>
        </div>
      </header>

      <main className="relative z-10 mx-auto w-full max-w-6xl flex-1 px-4 py-8 sm:px-6 sm:py-10">
        {/* ==================== المعاينة الحية (الأبرز) ==================== */}
        <section id="preview" className="mb-12 scroll-mt-28">
          <SectionHeading
            icon={Smartphone}
            kicker="تفاعل مباشر"
            title="المعاينة الحية — التطبيق يعمل الآن"
            subtitle="بناء ويب حقيقي لنفس الكود المُترجم إلى أندرويد، يُعرض داخل إطار هاتف ويمكن التفاعل معه فوراً"
          />

          <div className="grid grid-cols-1 items-start gap-8 lg:grid-cols-[minmax(0,420px)_minmax(0,1fr)]">
            {/* ------------------ إطار الهاتف ------------------ */}
            <div className="mx-auto w-full max-w-[390px]">
              <div className="relative rounded-[48px] bg-[#050B09] p-[10px] shadow-[0_40px_80px_-30px_rgba(0,0,0,0.75)] ring-1 ring-[#C9A96A]/20">
                {/* أزرار الحواف */}
                <span aria-hidden="true" className="absolute -left-[3px] top-[120px] h-11 w-[3px] rounded-full bg-[#24382F]" />
                <span aria-hidden="true" className="absolute -left-[3px] top-[168px] h-8 w-[3px] rounded-full bg-[#24382F]" />
                <span aria-hidden="true" className="absolute -right-[3px] top-[140px] h-16 w-[3px] rounded-full bg-[#24382F]" />

                {/* الشاشة */}
                <div
                  aria-busy={loading}
                  className="relative h-[800px] max-h-[75vh] overflow-hidden rounded-[38px] bg-[#0B1512] sm:max-h-none"
                >
                  {/* الجزيرة الديناميكية */}
                  <div
                    aria-hidden="true"
                    className="pointer-events-none absolute left-1/2 top-[10px] z-20 flex h-[24px] w-[96px] -translate-x-1/2 items-center justify-end rounded-full bg-[#050B09] pr-3.5"
                  >
                    <span className="h-2 w-2 rounded-full bg-[#16302A] ring-1 ring-[#2A4A42]/70" />
                  </div>

                  {/* مؤشر الصفحة الرئيسية */}
                  <div
                    aria-hidden="true"
                    className="pointer-events-none absolute bottom-[6px] left-1/2 z-20 h-[4px] w-[120px] -translate-x-1/2 rounded-full bg-[#E8F0EC]/20"
                  />

                  {/* هيكل التحميل */}
                  {loading && (
                    <div className="absolute inset-0 z-30 flex flex-col items-center justify-center gap-5 bg-[#0B1512]/95 px-10">
                      <FinAccMark idSuffix="loader" className="h-14 w-14 animate-pulse" />
                      <p className="text-xs font-bold text-[#9DB5AC]">جارٍ تحميل التطبيق…</p>
                      <div className="w-full max-w-[240px] space-y-3">
                        <Skeleton className="h-3 w-3/4 rounded-full bg-[#16302A]" />
                        <Skeleton className="h-3 w-full rounded-full bg-[#16302A]" />
                        <Skeleton className="h-3 w-2/3 rounded-full bg-[#16302A]" />
                        <Skeleton className="mt-5 h-20 w-full rounded-2xl bg-[#16302A]" />
                      </div>
                    </div>
                  )}

                  {/* التطبيق الفعلي */}
                  <iframe
                    key={iframeKey}
                    id="flutter-view"
                    src={PREVIEW_URL}
                    title="FinAcc Live Preview"
                    loading="eager"
                    onLoad={handleFrameLoad}
                    className="absolute inset-0 h-full w-full border-0 bg-[#0B1512]"
                  />
                </div>
              </div>
              <p className="mt-3 text-center text-[11px] text-[#9DB5AC]">
                إطار مرجعي بعرض <span dir="ltr" className="font-mono">390px</span> — يتوسّط
                الشاشات الصغيرة تلقائياً
              </p>
            </div>

            {/* ------------------ بطاقة حالة المعاينة ------------------ */}
            <div className="space-y-4">
              <Card className="gap-5 border-[#1E332D] bg-[#0F1D19]/90 py-6 text-[#E8F0EC] shadow-[0_24px_60px_-30px_rgba(0,0,0,0.7)] ring-1 ring-inset ring-[#E8F0EC]/[0.04]">
                <CardHeader className="px-6">
                  <CardTitle className="flex items-center gap-2.5 text-base font-extrabold">
                    <span className="flex h-8 w-8 items-center justify-center rounded-lg border border-[#C9A96A]/25 bg-[#00695C]/15 text-[#4DBFA8]">
                      <Smartphone className="h-4 w-4" aria-hidden="true" />
                    </span>
                    حالة المعاينة
                  </CardTitle>
                  <CardDescription className="text-sm text-[#9DB5AC]">
                    تُخدَّم حزمة الويب مباشرة من خادم Next.js نفسه
                  </CardDescription>
                </CardHeader>

                <CardContent className="space-y-3.5 px-6">
                  {/* مؤشر الجاهزية */}
                  <div className="flex items-center gap-3 rounded-xl border border-[#1E332D] bg-[#0B1512]/70 p-3.5">
                    <span className="relative flex h-3 w-3 shrink-0">
                      <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-[#4DBFA8] opacity-50" />
                      <span className="relative inline-flex h-3 w-3 rounded-full bg-[#4DBFA8]" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-extrabold text-[#E8F0EC]">جاهز</p>
                      <p className="text-xs text-[#9DB5AC]">
                        المعاينة متاحة ويمكن التفاعل معها الآن
                      </p>
                    </div>
                    <Badge className="border-transparent bg-[#00695C]/30 text-[10px] font-bold text-[#8FD9C6]">
                      مباشر
                    </Badge>
                  </div>

                  {/* الرابط */}
                  <div className="flex flex-wrap items-center justify-between gap-x-3 gap-y-1.5 rounded-xl border border-[#1E332D] bg-[#0B1512]/70 p-3.5">
                    <p className="text-xs text-[#9DB5AC]">رابط المعاينة</p>
                    <a
                      href={PREVIEW_URL}
                      target="_blank"
                      rel="noopener noreferrer"
                      dir="ltr"
                      className="font-mono text-xs text-[#8FD9C6] underline decoration-[#4DBFA8]/40 underline-offset-4 transition-colors hover:decoration-[#4DBFA8]"
                    >
                      /mobile_app/index.html
                    </a>
                  </div>

                  {/* ملاحظة الأداء */}
                  <div className="flex items-start gap-2.5 rounded-xl border border-[#C9A96A]/25 bg-[#C9A96A]/[0.06] p-3.5">
                    <Info className="mt-0.5 h-4 w-4 shrink-0 text-[#C9A96A]" aria-hidden="true" />
                    <p className="text-xs leading-relaxed text-[#D7E4DE]">
                      تطبيق ويب تجريبي — الأداء الكامل على أندرويد
                    </p>
                  </div>

                  <Separator className="bg-[#1E332D]" />

                  {/* أزرار التحكم */}
                  <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
                    <Button
                      variant="outline"
                      onClick={refreshPreview}
                      className="h-11 gap-2 border-[#2A4A42] bg-transparent text-[#E8F0EC] hover:border-[#4DBFA8]/50 hover:bg-[#4DBFA8]/10 hover:text-[#8FD9C6] focus-visible:ring-[#4DBFA8]/40"
                    >
                      <RefreshCw
                        className={`h-4 w-4 ${loading ? "animate-spin" : ""}`}
                        aria-hidden="true"
                      />
                      تحديث المعاينة
                    </Button>
                    <Button
                      asChild
                      className="h-11 gap-2 border-transparent bg-[#00695C] text-[#E8F0EC] shadow-lg shadow-[#00695C]/25 hover:bg-[#007A6A] focus-visible:ring-[#4DBFA8]/40"
                    >
                      <a href={PREVIEW_URL} target="_blank" rel="noopener noreferrer">
                        <ExternalLink className="h-4 w-4" aria-hidden="true" />
                        فتح في تبويب جديد
                      </a>
                    </Button>
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        </section>

        {/* ================= ما تم إنجازه — المرحلة الأولى ================= */}
        <section className="mb-12">
          <SectionHeading
            icon={Database}
            kicker="حصاد المرحلة"
            title="ما تم إنجازه — المرحلة الأولى"
            subtitle="شريحتان مكتملتان: أساس التخزين الذرّي، ثم تجربة الهوية والدخول حتى لوحة التحكم"
          />

          <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
            {/* ---------- الشريحة 0 ---------- */}
            <Card className="gap-5 border-[#1E332D] bg-[#0F1D19]/90 py-6 text-[#E8F0EC] shadow-[0_24px_60px_-30px_rgba(0,0,0,0.7)] ring-1 ring-inset ring-[#E8F0EC]/[0.04]">
              <CardHeader className="px-6">
                <CardTitle className="flex flex-wrap items-center gap-2.5 text-base font-extrabold">
                  <span className="flex h-8 w-8 items-center justify-center rounded-lg border border-[#C9A96A]/25 bg-[#00695C]/15 text-[#4DBFA8]">
                    <Database className="h-4 w-4" aria-hidden="true" />
                  </span>
                  الشريحة 0 — محرك التخزين
                  <Badge className="ml-auto gap-1 border-transparent bg-[#00695C]/30 text-[10px] font-bold text-[#8FD9C6]">
                    <CheckCircle2 className="h-3 w-3" aria-hidden="true" />
                    مكتملة
                  </Badge>
                </CardTitle>
                <CardDescription className="text-sm text-[#9DB5AC]">
                  قاعدة البيانات المحلية بمعايير الإنتاج: ذرّية، مُدقَّقة، ومحمية من التعديل
                </CardDescription>
              </CardHeader>
              <CardContent className="px-6">
                <ul className="space-y-2.5">
                  {slice0Items.map((item, i) => (
                    <DoneItem key={i}>{item}</DoneItem>
                  ))}
                </ul>
              </CardContent>
            </Card>

            {/* ---------- الشريحة 1 ---------- */}
            <Card className="gap-5 border-[#1E332D] bg-[#0F1D19]/90 py-6 text-[#E8F0EC] shadow-[0_24px_60px_-30px_rgba(0,0,0,0.7)] ring-1 ring-inset ring-[#E8F0EC]/[0.04]">
              <CardHeader className="px-6">
                <CardTitle className="flex flex-wrap items-center gap-2.5 text-base font-extrabold">
                  <span className="flex h-8 w-8 items-center justify-center rounded-lg border border-[#C9A96A]/25 bg-[#00695C]/15 text-[#4DBFA8]">
                    <Fingerprint className="h-4 w-4" aria-hidden="true" />
                  </span>
                  الشريحة 1 — الهوية والدخول
                  <Badge className="ml-auto gap-1 border-transparent bg-[#00695C]/30 text-[10px] font-bold text-[#8FD9C6]">
                    <CheckCircle2 className="h-3 w-3" aria-hidden="true" />
                    مكتملة
                  </Badge>
                </CardTitle>
                <CardDescription className="text-sm text-[#9DB5AC]">
                  من أول إقلاع حتى لوحة التحكم: هوية بصرية موحّدة ودخول محمي برمز PIN
                </CardDescription>
              </CardHeader>
              <CardContent className="px-6">
                <ul className="space-y-2.5">
                  {slice1Items.map((item, i) => (
                    <DoneItem key={i}>{item}</DoneItem>
                  ))}
                </ul>
              </CardContent>
            </Card>
          </div>
        </section>

        {/* ======================= بوابات الجودة ======================= */}
        <section className="mb-12">
          <SectionHeading
            icon={BadgeCheck}
            kicker="جودة التسليم"
            title="بوابات الجودة"
            subtitle="كل بوابة اجتازها المشروع قبل عرض هذه اللوحة"
          />

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {qualityGates.map((gate) => (
              <Card
                key={gate.name}
                className="gap-0 border-[#1E332D] bg-[#0F1D19]/90 py-5 text-[#E8F0EC] shadow-[0_18px_45px_-30px_rgba(0,0,0,0.65)] ring-1 ring-inset ring-[#E8F0EC]/[0.04]"
              >
                <CardContent className="flex flex-col gap-3 px-5">
                  <div className="flex items-center justify-between gap-2">
                    <span className="flex h-9 w-9 items-center justify-center rounded-lg border border-[#C9A96A]/25 bg-[#00695C]/15 text-[#4DBFA8]">
                      <gate.icon className="h-4 w-4" aria-hidden="true" />
                    </span>
                    <span className="flex h-5 w-5 items-center justify-center rounded-full bg-[#4DBFA8]/15 text-[#4DBFA8]">
                      <CheckCircle2 className="h-3.5 w-3.5" aria-hidden="true" />
                    </span>
                  </div>
                  <p dir="ltr" className="text-start font-mono text-sm font-bold text-[#E8F0EC]">
                    {gate.name}
                  </p>
                  <p className="text-xs leading-relaxed text-[#9DB5AC]">{gate.result}</p>
                </CardContent>
              </Card>
            ))}
          </div>
        </section>

        {/* ======================= الخطوة التالية ======================= */}
        <section className="mb-4">
          <SectionHeading
            icon={Sparkles}
            kicker="ما بعد الاعتماد"
            title="الخطوة التالية"
            subtitle="قرار واحد يفصلنا عن مواصلة البناء"
          />

          <Card className="gap-4 border-[#C9A96A]/25 bg-gradient-to-l from-[#C9A96A]/[0.07] via-[#0F1D19]/95 to-[#0F1D19]/95 py-6 text-[#E8F0EC] shadow-[0_24px_60px_-30px_rgba(0,0,0,0.7)]">
            <CardContent className="flex flex-col gap-5 px-6 sm:flex-row sm:items-center">
              <div className="flex-1">
                <p className="text-sm leading-relaxed text-[#D7E4DE] sm:text-base">
                  بانتظار مراجعتك واعتمادك للمرحلة الأولى — ثم نبدأ{" "}
                  <span className="font-extrabold text-[#E3C88F]">
                    الشريحة 2 (الأصناف والدفعات)
                  </span>
                  .
                </p>
                <div className="mt-3 flex flex-wrap items-center gap-2">
                  <Badge className="gap-1.5 border-[#2A4A42] bg-[#0B1512]/70 px-3 py-1 text-[11px] font-bold text-[#8FD9C6]">
                    <Package className="h-3.5 w-3.5" aria-hidden="true" />
                    الأصناف
                  </Badge>
                  <Badge className="gap-1.5 border-[#2A4A42] bg-[#0B1512]/70 px-3 py-1 text-[11px] font-bold text-[#8FD9C6]">
                    <CreditCard className="h-3.5 w-3.5" aria-hidden="true" />
                    الدفعات
                  </Badge>
                </div>
              </div>

              <div className="flex items-start gap-2.5 rounded-xl border border-[#C9A96A]/25 bg-[#C9A96A]/[0.06] p-3.5 sm:max-w-[280px]">
                <Info className="mt-0.5 h-4 w-4 shrink-0 text-[#C9A96A]" aria-hidden="true" />
                <p className="text-xs leading-relaxed text-[#D7E4DE]">
                  لتجربة التطبيق بكامل الشاشة، استخدم زر{" "}
                  <span className="font-bold text-[#E3C88F]">«فتح في تبويب جديد»</span> من{" "}
                  <a
                    href="#preview"
                    className="font-bold text-[#8FD9C6] underline decoration-[#4DBFA8]/40 underline-offset-4 hover:decoration-[#4DBFA8]"
                  >
                    لوحة المعاينة الجانبية
                  </a>{" "}
                  بالأعلى.
                </p>
              </div>
            </CardContent>
          </Card>
        </section>
      </main>

      {/* =========================== التذييل =========================== */}
      <footer className="relative z-10 mt-auto border-t border-[#C9A96A]/15 bg-[#0B1512]/85 backdrop-blur-md">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-1.5 px-4 pb-[calc(1rem+env(safe-area-inset-bottom))] pt-4 text-center text-xs text-[#9DB5AC] sm:flex-row sm:px-6 sm:text-start">
          <p>
            <span className="font-extrabold text-[#E8F0EC]">FinAcc</span> — نظام محاسبي ومخزون
            متكامل
          </p>
          <Separator
            orientation="vertical"
            className="hidden h-4 w-px bg-[#1E332D] sm:block"
          />
          <p>
            تم التطوير داخل بيئة <span className="text-[#C9A96A]">Z.ai</span> •{" "}
            <span dir="ltr" className="font-mono">SRS v1.5</span>
          </p>
        </div>
      </footer>
    </div>
  );
}
