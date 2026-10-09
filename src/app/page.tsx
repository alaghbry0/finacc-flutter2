"use client";

import { useCallback, useEffect, useState } from "react";

import {
  BadgeCheck,
  Braces,
  CalendarClock,
  CheckCircle2,
  CreditCard,
  Database,
  Download,
  ExternalLink,
  Fingerprint,
  FlaskConical,
  Hash,
  History,
  Info,
  Package,
  PackageCheck,
  RefreshCw,
  ShieldCheck,
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

/** رابط حزمة أندرويد الأولى — تُخدَّم من مجلد public/downloads. */
const APK_URL = "/downloads/FinAcc-v0.7.0.apk";

type ApkInfo = {
  available: boolean;
  sizeBytes?: number;
  sha256?: string;
  builtAt?: string;
};

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
    <Mono>30</Mono> يوماً + لوحة تفاصيل التاريخ هجري/ميلادي
  </>,
  <>شريط تبويب سفلي بخمسة أقسام رئيسية للتطبيق</>,
  <>
    شاشة إعدادات كاملة: المنشأة والأمان والمظهر والبيانات وحول + تراخيص
    مفتوحة المصدر
  </>,
  <>
    تدفق تغيير رمز <Mono>PIN</Mono> ذرّي ثلاثي الخطوات مع قيد تدقيق
    (<Mono>pin_change</Mono>)
  </>,
  <>
    سجل تدقيق حي (<Mono>FR-12-04</Mono>) بتصفية بالتصنيف وعدّادات لكل قسم
    — محمي بـ <Mono>Triggers</Mono> داخل ملف القاعدة
  </>,
  <>
    نظام أرقام حي (<Mono>display.numerals</Mono>): غربي ↔ عربي شرقي ينعكس
    فوراً على كل المبالغ والتواريخ
  </>,
  <>
    قفل تلقائي قابل للضبط (<Mono>1–60</Mono> دقيقة) + وضع ثيم محفوظ عبر
    إعادة التشغيل
  </>,
];

const slices2toPre1Items: React.ReactNode[] = [
  <>
    <b>الشريحة 2–3</b> — المخزون الكامل: الأصناف والباركود (EAN-13/Code128
    بمعاينة حية) والدفعات <Mono>FEFO</Mono> واستيراد Excel/CSV + الأطراف
    (عملاء/موردون بحد ائتمان وأرصدة متعددة العملات) وأسعار الصرف اليومية
    مع بوابة <Mono>FR-08-09</Mono>
  </>,
  <>
    <b>الشريحة 4</b> — الكاشير الكامل: سلة بجلسة تنجو من القفل، خصومات سطر
    وفاتورة <Mono>pro-rata</Mono>، دفع نقدي/آجل/مختلط، وعروض أسعار قابلة
    للتحويل — محرك ترحيل ذري (<Mono>INV/QTE</Mono> + <Mono>WAC</Mono> لحظة البيع)
  </>,
  <>
    <b>الشريحة 5</b> — المشتريات والمرتجعات: فواتير <Mono>PUR</Mono> بدفعات
    واردة برقم مورد وصلاحية + مرتجعات <Mono>SRN/PRN</Mono> المرتبطة
    بالفواتير الأصلية
  </>,
  <>
    <b>الشريحة 6</b> — النقدية والصناديق: أرصدة حية لكل صندوق وعملة، سندات
    <Mono>RVT/PMT</Mono> بتخصيص <Mono>FIFO</Mono> أو على الحساب، مصروف بفئات،
    مسحوبات وإيداع مالك، تحويل بعملتين، وإبطال بحركة معاكسة
  </>,
  <>
    <b>الشريحة 7 — كاملة</b> — وحدة <Mono>PDF/الطباعة</Mono>: فاتورة المبيعات
    <Mono>A4</Mono> وسندات القبض/الصرف <Mono>A5</Mono> وكشف حساب الطرف
    <Mono>A4</Mono> — بعربية مصيّرة كاملة (خط Almarai داخل المستند) + معاينة
    حية بدقة <Mono>150dpi</Mono> بشريط حجم الملف + طباعة/مشاركة/واتساب دفاعية
    — وتتوّج بأول حزمة <Mono>APK</Mono> لأندرويد
  </>,
  <>
    <b>الشريحة 8 — كاملة ✅ معلم MVP</b> — النسخ الاحتياطي والاستعادة
    (FR-11): محرك نسخ بأرشيف <Mono>.finbak</Mono> (ZIP: manifest + قاعدة)
    بتدقيق بصمة، جدولة يومية/أسبوعية، احتفاظ تلقائي (3/7/14/30)، سجل نسخ
    كامل، استعادة من ملف مع حماية المخطط الأحدث، مشاركة عبر النظام
    (<Mono>share_plus</Mono>)، وتذكير ذكي في اللوحة الرئيسية — 64 اختباراً
    جديداً ترفع الحزمة إلى 478
  </>,
  <>
    <b>الشريحة 9 — كاملة</b> — الديون والرقابة اليومية (الأسابيع 9–10):
    <b>الوردية بالمعادلة الشاملة</b> (FR-04-04) — فتح/إقفال بعدّ فعلي، تفكيك
    كامل لكل بنود الوارد والصادر بتلوين زيادة/عجز، وتقرير وردية PDF عربي
    قابل للمشاركة — و<b>أعمار الديون FIFO</b> (FR-09-05) بدلاء 0–30/31–60/
    61–90/+90 بعملة محددة وتذكيرات واتساب بنص جاهز لكل عميل — و<b>إنفاذ
    حد الائتمان</b> (FR-03-05) بإعداد <Mono>warn/block</Mono> في ورقة الدفع
    — و<b>إكمال الداشبورد</b> (FR-09-01) ببطاقة مبيعات الشهر بمقارنة
    نسبية وأعلى الأصناف مبيعاً بمراتب ذهبية — 30 اختباراً جديداً ترفع
    الحزمة إلى 508
  </>,
  <>
    <b>الشريحة 10 — كاملة</b> — الرقابة والحقيقة (الأسابيع 11–12): الجرد
    الفعلي بتكلفة اللقطة + الأرباح عبر <Mono>Posting Map</Mono> حصراً +
    تقارير حركة صنف وملخص المخزون والمبيعات حسب + ربح الفاتورة + مركز
    التقارير + اختبار أداء AC-22 على 50 ألف فاتورة/20 ألف صنف/100 ألف
    حركة (الداشبورد 8–16ms &lt; 3s، البحث 19–27ms &lt; 100ms، تقرير
    الشهر 29ms &lt; 3s) — 95 اختباراً جديداً ترفع الحزمة إلى 603
  </>,
  <>
    <b>ما قبل v1.0.0 — كاملة</b> — مرحلة التخصيص والقوالب والبونص (خمس
    موجات بعد مراجعة UI/UX شاملة): <b>الإصلاحات الساخنة</b> — شفاء عرض
    العربية بمستندات <Mono>PDF</Mono> وانهيار الأسماء + <Mono>pdf.js</Mono>{" "}
    محلي + معاينة متعددة الصفحات + جلسة الجرد واستعادة موقع القفل + طباعة
    فورية من الإيصال + حماية المسح والنماذج + عميل سريع وزر مرتجع + 12
    تحسيناً — و<b>التخصيص الشامل</b>: مركز أقسام بإعدادات (محرر منشأة
    بشعار + تفضيلات بيع: ائتمان <Mono>warn/block</Mono>، فوق المتاح{" "}
    <Mono>block</Mono>، تحت التكلفة، دفع افتراضي + عرض: حجم خط 3 مستويات
    وتباين عالٍ) + أرقام جدولية <Mono>tnum</Mono> بخط Noto — و<b>قوالب
    الفواتير القابلة للتخصيص</b>: كلاسيكي <Mono>A4</Mono> أفقي بنموذج
    المالك حرفياً (إطار/شعار وسط/شارة زرقاء/رقم أحمر/جدول سميك برأس
    مظلل/إجماليات كريمية وباقٍ أحمر/تواقيع ثلاث/ختم) + بسيط + شاشة
    تخصيص بألوان ومعاينة حية — و<b>الكميات المجانية/بونص</b> ديناميكية
    بلا أي إعدادات: لاحقة <span dir="ltr">(+N مجاني)</span> تظهر حصراً
    عند وجود بونص بالبيع والشراء، تحاسب سليم (<Mono>COGS</Mono> على
    الكلي، الإيراد المدفوع فقط، <Mono>WAC</Mono> على المستلم الكلي) —
    ثم <b>جولة R16</b>: شفاء معاينة الطباعة جذرياً (تحميل{" "}
    <Mono>pdf.js</Mono> قبل الإقلاع)، محرر سطر موحد (كمية/مجانية/سعر/
    خصم)، حذف القالب الحراري بقرار المالك، زر عودة لشاشة التقارير،
    نموذج صنف قابل للتمرير، و<b>CI يبني APK آلياً مع كل إصدار</b> —
    هجرات <Mono>v3→v6</Mono> و165 اختباراً جديداً ترفع الحزمة إلى 768
  </>,
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
    result: "768/768 اختباراً خضراء (+16 بجولة R16 — مجموع +165 منذ v0.10.0)",
  },
  {
    icon: Braces,
    name: "dart format",
    result: "تنسيق قياسي نظيف",
  },
  {
    icon: Smartphone,
    name: "المعاينة الحية",
    result: "تعمل داخل إطار الهاتف",
  },
  {
    icon: PackageCheck,
    name: "flutter build apk",
    result: "release v0.7.0+7 — موقّعة ومنشورة على GitHub",
  },
  {
    icon: BadgeCheck,
    name: "التحقق الحي من المتصفح",
    result: "البوابة الملزمة للجودة",
  },
] as const;

/* ================================================================== */
/* الصفحة                                                               */
/* ================================================================== */

export default function FinAccStage1DeliveryPanel() {
  const [iframeKey, setIframeKey] = useState(0);
  const [loading, setLoading] = useState(true);
  const [apkInfo, setApkInfo] = useState<ApkInfo | null>(null);
  const [shaCopied, setShaCopied] = useState(false);

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

  /* جلب معلومات حزمة APK (الحجم/البصمة/تاريخ البناء) من مسار API. */
  useEffect(() => {
    let cancelled = false;
    fetch("/api/apk-info")
      .then((res) => (res.ok ? res.json() : null))
      .then((data: ApkInfo | null) => {
        if (!cancelled && data) setApkInfo(data);
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, []);

  const copySha = useCallback(() => {
    if (!apkInfo?.sha256) return;
    navigator.clipboard
      ?.writeText(apkInfo.sha256)
      .then(() => {
        setShaCopied(true);
        window.setTimeout(() => setShaCopied(false), 1600);
      })
      .catch(() => undefined);
  }, [apkInfo]);

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
              <p className="truncate text-[11px] text-[#9DB5AC]">لوحة تسليم FinAcc — تتبع الجولات حياً</p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <div className="hidden items-center gap-2 md:flex">
              <Badge className="gap-1.5 border-transparent bg-[#00695C]/30 px-3 py-1 text-[11px] font-bold text-[#8FD9C6]">
                <Sparkles className="h-3 w-3" aria-hidden="true" />
                v0.11.1 — علاج شامل وCI للإصدارات
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
            v0.11.1 — علاج شامل وCI للإصدارات
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
              {/* جديد هذا البناء — علاج شكاوى المالك الست */}
              <Card className="gap-4 border-[#C9A96A]/30 bg-gradient-to-l from-[#C9A96A]/[0.08] via-[#0F1D19]/95 to-[#0F1D19]/95 py-5 text-[#E8F0EC] shadow-[0_24px_60px_-30px_rgba(0,0,0,0.7)] ring-1 ring-inset ring-[#E8F0EC]/[0.04]">
                <CardHeader className="px-5">
                  <CardTitle className="flex flex-wrap items-center gap-2.5 text-sm font-extrabold">
                    <span className="relative flex h-2.5 w-2.5">
                      <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-[#E3C88F] opacity-60" />
                      <span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-[#E3C88F]" />
                    </span>
                    جديد هذا البناء — علاج شكاوى المالك الست
                    <Badge className="gap-1 border-transparent bg-[#00695C]/30 text-[10px] font-bold text-[#8FD9C6]">
                      v0.11.1
                    </Badge>
                  </CardTitle>
                  <CardDescription className="text-xs text-[#9DB5AC]">
                    جرّبها الآن داخل الإطار — كلها في هذه المعاينة الحية
                  </CardDescription>
                </CardHeader>
                <CardContent className="px-5">
                  <ul className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
                    {[
                      {
                        icon: Sparkles,
                        title: "قوالب الفواتير القابلة للتخصيص",
                        desc: "كلاسيكي A4 أفقي بنموذج المالك حرفياً (إطار/شعار وسط/شارة زرقاء/رقم أحمر/جدول سميك برأس مظلل/إجماليات كريمية وباقٍ أحمر/تواقيع ثلاث/ختم) + بسيط + حراري 80mm بباركود Code128 — بألوان ومفاتيح إظهار ومعاينة حية",
                        path: "المسار: المزيد ← الطباعة والفواتير",
                        gold: true,
                      },
                      {
                        icon: PackageCheck,
                        title: "الكميات المجانية (بونص)",
                        desc: "تُفعّل وتُخفى من تفضيلات البيع — لاحقة (\u200E+N مجاني) بجوار الكمية بالفاتورة والقوالب الثلاثة، وتحاسب سليم: COGS على المنصرف الكلي والإيراد المدفوع حصراً",
                        path: "المسار: المزيد ← تفضيلات البيع ← فعّل الكميات المجانية ثم أضف \u200E+N بسطر بالسلة",
                        gold: true,
                      },
                      {
                        icon: Fingerprint,
                        title: "محرر بيانات المنشأة برفع شعار",
                        desc: "الاسم/الهاتف/واتساب/العنوان/الضريبة/تذييل الفاتورة + رفع شعار يُخزّن BLOB داخل القاعدة ويظهر وسط القالب الكلاسيكي",
                        path: "المسار: المزيد ← بيانات المنشأة",
                        gold: false,
                      },
                      {
                        icon: CreditCard,
                        title: "تفضيلات البيع الحارسة",
                        desc: "ائتمان warn/block، وفوق المتاح block يمنع ترحيل سلة زائدة، وتحذير البيع تحت التكلفة بعملة الأساس، وطريقة الدفع الافتراضية",
                        path: "المسار: المزيد ← تفضيلات البيع",
                        gold: false,
                      },
                      {
                        icon: Smartphone,
                        title: "العرض والأرقام الجدولية",
                        desc: "حجم خط بثلاثة مستويات + تباين عالٍ فوري + أرقام جدولية tnum بخط Noto مرافق — أعمدة المبالغ تستقيم على الشاشة والورق",
                        path: "المسار: المزيد ← المظهر",
                        gold: false,
                      },
                      {
                        icon: Package,
                        title: "عربية سليمة في مستندات PDF",
                        desc: "rtl على القيم بالبناة الأربعة يشفي التفكيك وانهيار الأسماء معاً + pdf.js محلي بلا شبكة + معاينة متعددة الصفحات بمؤشر ترقيم معرّب",
                        path: "المسار: أي فاتورة/سند/كشف ← معاينة أو مشاركة PDF",
                        gold: false,
                      },
                      {
                        icon: History,
                        title: "تدفقات أسرع ومحمية",
                        desc: "طباعة فورية من إيصال النجاح + عميل سريع داخل منتقي الكاشير + زر مرتجع من تفاصيل الفاتورة + جلسة جرد تنجو من التنقل والقفل مع استعادة موقعك بعد الفتح",
                        path: "المسار: البيع ← الكاشير / المخزون ← الجرد الفعلي",
                        gold: false,
                      },
                      {
                        icon: ShieldCheck,
                        title: "حماية المسح والنماذج",
                        desc: "المسح الكامل بكلمة تأكيد مكتوبة ونسخة أمان إجبارية قبل أي مسح + حماية مغادرة النماذج غير المحفوظة (صنف/طرف/سند)",
                        path: "المسار: الإعدادات ← البيانات",
                        gold: false,
                      },
                    ].map((feature) => (
                      <li
                        key={feature.title}
                        className={`flex items-start gap-2.5 rounded-xl border p-3 transition-colors ${
                          feature.gold
                            ? "border-[#C9A96A]/40 bg-[#C9A96A]/[0.05] hover:border-[#C9A96A]/55"
                            : "border-[#1E332D] bg-[#0B1512]/70 hover:border-[#C9A96A]/35"
                        }`}
                      >
                        <span
                          className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border ${
                            feature.gold
                              ? "border-[#C9A96A]/45 bg-[#C9A96A]/15 text-[#E3C88F]"
                              : "border-[#C9A96A]/25 bg-[#00695C]/15 text-[#4DBFA8]"
                          }`}
                        >
                          <feature.icon className="h-3.5 w-3.5" aria-hidden="true" />
                        </span>
                        <div className="min-w-0">
                          <p className="text-xs font-bold leading-tight text-[#E8F0EC]">
                            {feature.title}
                          </p>
                          <p className="mt-1 text-[11px] leading-snug text-[#9DB5AC]">
                            {feature.desc}
                          </p>
                          <p className="mt-1 text-[11px] font-bold leading-snug text-[#E3C88F]">
                            {feature.path}
                          </p>
                        </div>
                      </li>
                    ))}
                  </ul>
                </CardContent>
              </Card>

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

        {/* ================== التطبيق على أندرويد — أول APK ================== */}
        <section className="mb-12">
          <SectionHeading
            icon={PackageCheck}
            kicker="جاهز للتثبيت"
            title="التطبيق على أندرويد — أول حزمة APK"
            subtitle="نفس الكود الذي جرّبته في المعاينة أعلاه، مُترجم ترجمة أصلية (AOT) في حزمة تثبيت واحدة تعمل على كل الأجهزة"
          />

          <Card className="gap-0 border-[#1E332D] bg-[#0F1D19]/90 text-[#E8F0EC] shadow-[0_24px_60px_-30px_rgba(0,0,0,0.7)] ring-1 ring-inset ring-[#E8F0EC]/[0.04]">
            <CardContent className="grid grid-cols-1 gap-6 px-6 py-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,340px)]">
              {/* ------------------ التفاصيل ------------------ */}
              <div className="space-y-4">
                <div className="flex flex-wrap items-center gap-2">
                  <Badge className="gap-1.5 border-transparent bg-[#00695C]/30 px-3 py-1 text-[11px] font-bold text-[#8FD9C6]">
                    <PackageCheck className="h-3 w-3" aria-hidden="true" />
                    الإصدار 0.7.0 (بناء 7)
                  </Badge>
                  <Badge className="gap-1.5 border-[#2A4A42] bg-[#0B1512]/70 px-3 py-1 text-[11px] font-bold text-[#9DB5AC]">
                    <Smartphone className="h-3 w-3" aria-hidden="true" />
                    أندرويد 7.0 أو أحدث
                  </Badge>
                  <Badge
                    dir="ltr"
                    className="gap-1.5 border-[#2A4A42] bg-[#0B1512]/70 px-3 py-1 font-mono text-[11px] font-bold text-[#9DB5AC]"
                  >
                    app.finacc.mobile
                  </Badge>
                </div>

                <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
                  <div className="rounded-xl border border-[#1E332D] bg-[#0B1512]/70 p-3.5">
                    <p className="flex items-center gap-1.5 text-[11px] font-bold text-[#C9A96A]">
                      <Download className="h-3.5 w-3.5" aria-hidden="true" />
                      حجم الحزمة
                    </p>
                    <p dir="ltr" className="mt-1 font-mono text-sm font-bold text-[#E8F0EC]">
                      {apkInfo?.available && apkInfo.sizeBytes
                        ? `${(apkInfo.sizeBytes / 1024 / 1024).toFixed(1)} MB`
                        : "—"}
                    </p>
                  </div>
                  <div className="rounded-xl border border-[#1E332D] bg-[#0B1512]/70 p-3.5">
                    <p className="flex items-center gap-1.5 text-[11px] font-bold text-[#C9A96A]">
                      <CalendarClock className="h-3.5 w-3.5" aria-hidden="true" />
                      تاريخ البناء
                    </p>
                    <p dir="ltr" className="mt-1 font-mono text-sm font-bold text-[#E8F0EC]">
                      {apkInfo?.available && apkInfo.builtAt
                        ? new Date(apkInfo.builtAt).toLocaleString("ar", {
                            dateStyle: "medium",
                            timeStyle: "short",
                          })
                        : "—"}
                    </p>
                  </div>
                </div>

                {/* بصمة التحقق SHA-256 */}
                <div className="rounded-xl border border-[#1E332D] bg-[#0B1512]/70 p-3.5">
                  <div className="flex items-center justify-between gap-2">
                    <p className="flex items-center gap-1.5 text-[11px] font-bold text-[#C9A96A]">
                      <Hash className="h-3.5 w-3.5" aria-hidden="true" />
                      بصمة التحقق SHA-256
                    </p>
                    {apkInfo?.sha256 && (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={copySha}
                        className="h-8 gap-1.5 border-[#2A4A42] bg-transparent px-2.5 text-[10px] font-bold text-[#8FD9C6] hover:border-[#4DBFA8]/50 hover:bg-[#4DBFA8]/10 focus-visible:ring-[#4DBFA8]/40"
                      >
                        {shaCopied ? "تم النسخ ✓" : "نسخ"}
                      </Button>
                    )}
                  </div>
                  <p dir="ltr" className="mt-1 break-all font-mono text-[11px] leading-5 text-[#9DB5AC]">
                    {apkInfo?.sha256 ?? "—"}
                  </p>
                </div>

                <div className="flex items-start gap-2.5 rounded-xl border border-[#C9A96A]/25 bg-[#C9A96A]/[0.06] p-3.5">
                  <Info className="mt-0.5 h-4 w-4 shrink-0 text-[#C9A96A]" aria-hidden="true" />
                  <p className="text-xs leading-relaxed text-[#D7E4DE]">
                    موقّعة بمفاتيح التجربة (debug) لأغراض الاختبار — قبل أي نشر رسمي
                    سننشئ مفتاح توقيع إنتاجياً باسمك. عند التثبيت فعّل «التثبيت من
                    مصادر غير معروفة» من إعدادات أندرويد.
                  </p>
                </div>
              </div>

              {/* ------------------ زر التنزيل ------------------ */}
              <div className="flex flex-col justify-center gap-4 rounded-2xl border border-[#C9A96A]/20 bg-gradient-to-b from-[#00695C]/[0.12] via-[#0B1512]/60 to-[#0B1512]/60 p-5">
                {apkInfo?.available ? (
                  <Button
                    asChild
                    className="h-14 gap-3 border-transparent bg-gradient-to-l from-[#C9A96A] to-[#E3C88F] text-base font-extrabold text-[#0B1512] shadow-lg shadow-[#C9A96A]/25 hover:from-[#D8B878] hover:to-[#EDD6A6] focus-visible:ring-[#C9A96A]/40"
                  >
                    <a href={APK_URL} download="FinAcc-v0.7.0.apk">
                      <Download className="h-5 w-5" aria-hidden="true" />
                      تنزيل حزمة APK
                    </a>
                  </Button>
                ) : (
                  <div className="flex h-14 items-center justify-center gap-3 rounded-xl border border-dashed border-[#2A4A42] bg-[#0B1512]/70 text-sm font-bold text-[#9DB5AC]">
                    <RefreshCw className="h-4 w-4 animate-spin" aria-hidden="true" />
                    الحزمة قيد الإعداد…
                  </div>
                )}

                <div className="space-y-2 text-[11px] leading-relaxed text-[#9DB5AC]">
                  <p className="flex items-start gap-2">
                    <ShieldCheck className="mt-0.5 h-3.5 w-3.5 shrink-0 text-[#4DBFA8]" aria-hidden="true" />
                    تحقّق من البصمة بعد التنزيل:{" "}
                    <span dir="ltr" className="font-mono">sha256sum FinAcc-v0.7.0.apk</span>
                  </p>
                  <p className="flex items-start gap-2">
                    <Smartphone className="mt-0.5 h-3.5 w-3.5 shrink-0 text-[#4DBFA8]" aria-hidden="true" />
                    حزمة موحّدة (arm64 + arm + x86_64) تعمل على أي جهاز أندرويد 7.0+
                  </p>
                  <p className="flex items-start gap-2">
                    <Package className="mt-0.5 h-3.5 w-3.5 shrink-0 text-[#4DBFA8]" aria-hidden="true" />
                    بياناتك لا تغادر جهازك — قاعدة بيانات محلية بالكامل
                  </p>
                  <p className="flex items-start gap-2">
                    <ExternalLink className="mt-0.5 h-3.5 w-3.5 shrink-0 text-[#4DBFA8]" aria-hidden="true" />
                    نسخة دائمة وموثّقة على GitHub:{" "}
                    <a
                      href="https://github.com/alaghbry0/finacc-flutter2/releases/tag/v0.7.0"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="font-bold text-[#8FD9C6] underline decoration-[#4DBFA8]/40 underline-offset-2 hover:decoration-[#4DBFA8]"
                    >
                      Releases/v0.7.0
                    </a>
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </section>

        {/* ================= ما تم إنجازه — حتى ما قبل 1.0 ================= */}
        <section className="mb-12">
          <SectionHeading
            icon={Database}
            kicker="حصاد الجولات"
            title="ما تم إنجازه — حتى ما قبل 1.0"
            subtitle="عشر شريحات مكتملة ثم مرحلة ما قبل الإطلاق بموجاتها الخمس: من محرك التخزين الذري حتى الكاشير والمشتريات والنقدية والطباعة والنسخ الاحتياطي — ثم الوردية وأعمار الديون والجرد الفعلي والأرباح ومركز التقارير — وختاماً الإصلاحات الساخنة والتخصيص الشامل وقوالب الفواتير والكميات المجانية"
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

            {/* ---------- الشرائح 2–7 ---------- */}
            <Card className="gap-5 border-[#1E332D] bg-[#0F1D19]/90 py-6 text-[#E8F0EC] shadow-[0_24px_60px_-30px_rgba(0,0,0,0.7)] ring-1 ring-inset ring-[#E8F0EC]/[0.04] lg:col-span-2">
              <CardHeader className="px-6">
                <CardTitle className="flex flex-wrap items-center gap-2.5 text-base font-extrabold">
                  <span className="flex h-8 w-8 items-center justify-center rounded-lg border border-[#C9A96A]/25 bg-[#00695C]/15 text-[#4DBFA8]">
                    <Sparkles className="h-4 w-4" aria-hidden="true" />
                  </span>
                  الشرائح 2–10 وما قبل 1.0 — النواة التشغيلية والتخصيص والقوالب والبونص
                  <Badge className="ml-auto gap-1 border-[#C9A96A]/30 bg-[#C9A96A]/10 text-[10px] font-bold text-[#E3C88F]">
                    <BadgeCheck className="h-3 w-3" aria-hidden="true" />
                    v0.4.0 → v0.11.1
                  </Badge>
                </CardTitle>
                <CardDescription className="text-sm text-[#9DB5AC]">
                  المخزون والدفعات والأطراف والكاشير والمشتريات والنقدية والسندات والطباعة والنسخ — ثم الوردية وأعمار الديون، فالجرد الفعلي والأرباح والتقارير — ثم موجات ما قبل الإطلاق: الإصلاحات الساخنة والتخصيص والقوالب والبونص
                </CardDescription>
              </CardHeader>
              <CardContent className="px-6">
                <ul className="space-y-2.5">
                  {slices2toPre1Items.map((item, i) => (
                    <DoneItem key={i}>{item}</DoneItem>
                  ))}
                </ul>
              </CardContent>
            </Card>
          </div>

          {/* شريط خارطة الطريق — تتبّع الشرائح 0–11 */}
          <div className="mt-6 overflow-x-auto pb-1">
            <ol className="flex min-w-max items-stretch gap-1.5" aria-label="خارطة طريق الشرائح">
              {[
                { label: "0", title: "التخزين", done: true },
                { label: "1", title: "الهوية", done: true },
                { label: "2–3", title: "المخزون والأطراف", done: true },
                { label: "4", title: "الكاشير", done: true },
                { label: "5", title: "المشتريات", done: true },
                { label: "6", title: "النقدية", done: true },
                { label: "7", title: "الطباعة", done: true },
                { label: "8", title: "النسخ MVP", done: true },
                { label: "9", title: "الديون والوردية", done: true },
                { label: "10", title: "الجرد والأرباح", done: true },
                { label: "11", title: "التصلب والإطلاق 1.0", done: false, current: true },
              ].map((stage) => (
                <li
                  key={stage.label}
                  className={`flex min-w-[86px] flex-col items-center gap-1.5 rounded-xl border px-2.5 py-2.5 text-center transition-colors ${
                    stage.current
                      ? "border-[#C9A96A]/50 bg-[#C9A96A]/[0.09] shadow-[0_0_24px_-8px_rgba(201,169,106,0.45)]"
                      : stage.done
                        ? "border-[#1E332D] bg-[#0F1D19]/80 hover:border-[#2A4A42]"
                        : "border-dashed border-[#1E332D] bg-transparent opacity-70"
                  }`}
                >
                  <span
                    className={`flex h-6 w-6 items-center justify-center rounded-full text-[10px] font-extrabold ${
                      stage.done
                        ? "bg-[#00695C]/40 text-[#8FD9C6] ring-1 ring-[#4DBFA8]/40"
                        : "bg-[#16302A]/60 text-[#9DB5AC]"
                    }`}
                  >
                    {stage.done ? (
                      <CheckCircle2 className="h-3.5 w-3.5" aria-hidden="true" />
                    ) : (
                      stage.label
                    )}
                  </span>
                  <span
                    className={`text-[10px] font-bold leading-none ${
                      stage.current
                        ? "text-[#E3C88F]"
                        : stage.done
                          ? "text-[#D7E4DE]"
                          : "text-[#9DB5AC]"
                    }`}
                  >
                    {stage.title}
                  </span>
                  <span className="text-[9px] leading-none text-[#9DB5AC]/70">
                    {stage.current ? "الجولة الحالية" : stage.done ? "مكتملة" : "قادمة"}
                  </span>
                </li>
              ))}
            </ol>
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

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
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
            icon={CreditCard}
            kicker="ما بعد التخصيص والقوالب والبونص"
            title="الخطوة التالية — الشريحة 11: التصلب والإطلاق"
            subtitle="اختبارات E2E لكل معايير القبول على الجهاز المرجعي + تجربة حية مع محلات حقيقية — نحو إصدار 1.0.0 وحزمة APK"
          />

          <Card className="gap-4 border-[#C9A96A]/25 bg-gradient-to-l from-[#C9A96A]/[0.07] via-[#0F1D19]/95 to-[#0F1D19]/95 py-6 text-[#E8F0EC] shadow-[0_24px_60px_-30px_rgba(0,0,0,0.7)]">
            <CardContent className="flex flex-col gap-5 px-6 sm:flex-row sm:items-center">
              <div className="flex-1">
                <p className="text-sm leading-relaxed text-[#D7E4DE] sm:text-base">
                  اكتملت مرحلة ما قبل الإطلاق — <b>التخصيص الشامل</b> بمركز
                  الأقسام و<b>قوالب الفواتير</b> بنموذج المالك و<b>الكميات
                  المجانية/بونص</b> بتحاسبها السليم — فالجولة القادمة هي
                  الختام:{" "}
                  <span className="font-extrabold text-[#E3C88F]">
                    الشريحة 11 — التصلب والإطلاق
                  </span>{" "}
                  (الأسابيع 13–14): اختبارات <b>E2E</b> لكل معايير القبول
                  على الجهاز المرجعي، ثم <b>تجربة حية مع محلات حقيقية</b> —
                  وصولاً إلى{" "}
                  <span className="font-extrabold text-[#8FD9C6]">إصدار 1.0.0 مع حزمة APK</span>.
                </p>
                <div className="mt-3 flex flex-wrap items-center gap-2">
                  <Badge className="gap-1.5 border-[#2A4A42] bg-[#0B1512]/70 px-3 py-1 text-[11px] font-bold text-[#8FD9C6]">
                    <Terminal className="h-3.5 w-3.5" aria-hidden="true" />
                    E2E لكل معايير القبول
                  </Badge>
                  <Badge className="gap-1.5 border-[#2A4A42] bg-[#0B1512]/70 px-3 py-1 text-[11px] font-bold text-[#8FD9C6]">
                    <Smartphone className="h-3.5 w-3.5" aria-hidden="true" />
                    تجربة حية مع محلات حقيقية
                  </Badge>
                  <Badge className="gap-1.5 border-[#2A4A42] bg-[#0B1512]/70 px-3 py-1 text-[11px] font-bold text-[#8FD9C6]">
                    <PackageCheck className="h-3.5 w-3.5" aria-hidden="true" />
                    إصدار 1.0.0 وAPK
                  </Badge>
                </div>
              </div>

              <div className="flex items-start gap-2.5 rounded-xl border border-[#C9A96A]/25 bg-[#C9A96A]/[0.06] p-3.5 sm:max-w-[280px]">
                <Info className="mt-0.5 h-4 w-4 shrink-0 text-[#C9A96A]" aria-hidden="true" />
                <p className="text-xs leading-relaxed text-[#D7E4DE]">
                  جرّب التخصيص في المعاينة الحية بالأعلى:{" "}
                  <span className="font-bold text-[#E3C88F]">الطباعة والفواتير</span>{" "}
                  من المزيد (اختر القالب الكلاسيكي وبدّل الألوان وأظهر
                  الباركود ثم شاهد المعاينة الحية)، ثم{" "}
                  <span className="font-bold text-[#E3C88F]">تفضيلات البيع</span>{" "}
                  (فعّل البونص وأضف <span dir="ltr">+N</span> مجاني بسطر
                  بالسلة)، ثم{" "}
                  <span className="font-bold text-[#E3C88F]">بيانات المنشأة</span>{" "}
                  (ارفع شعارك).
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
