import type { Metadata } from "next";
import { Almarai, Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { Toaster } from "@/components/ui/toaster";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

// Almarai — الخط العربي الرسمي لهوية FinAcc (الأوزان المتاحة على Google Fonts:
// 300 / 400 / 700 / 800 — لا يوجد وزن 500 لهذا الخط).
const almarai = Almarai({
  variable: "--font-almarai",
  subsets: ["arabic", "latin"],
  weight: ["300", "400", "700", "800"],
});

export const metadata: Metadata = {
  title: "FinAcc — المُحاسِب الشخصي | لوحة التسليم v0.11.0",
  description:
    "لوحة تسليم FinAcc v0.11.0: معاينة حية للتطبيق داخل إطار هاتف، الشرائح 0–10 كاملة ثم مرحلة ما قبل الإطلاق — التخصيص والقوالب والبونص: مركز إعدادات بأقسام مع محرر منشأة برفع شعار وتفضيلات بيع حارسة وشاشة عرض بحجم خط وتباين عالٍ وأرقام جدولية، قوالب فواتير قابلة للتخصيص (كلاسيكي A4 بنموذج المالك + بسيط + حراري 80mm بباركود Code128) بمعاينة حية، والكميات المجانية/بونص بتحاسب سليم — 752 اختباراً خضراء.",
  keywords: [
    "FinAcc",
    "المحاسب الشخصي",
    "محاسبة",
    "مخزون",
    "Flutter",
    "تسليم",
    "SRS v1.5",
    "APK",
    "الوردية",
    "أعمار الديون",
  ],
  icons: {
    icon: "https://z-cdn.chatglm.cn/z-ai/static/logo.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ar" dir="rtl" suppressHydrationWarning>
      <body
        className={`${geistSans.variable} ${geistMono.variable} ${almarai.variable} font-[family-name:var(--font-almarai)] antialiased bg-background text-foreground`}
      >
        {children}
        <Toaster />
      </body>
    </html>
  );
}
