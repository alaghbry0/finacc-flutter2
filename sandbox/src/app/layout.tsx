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
  title: "FinAcc — المُحاسِب الشخصي | لوحة التسليم v0.8.0 (MVP)",
  description:
    "لوحة تسليم FinAcc v0.8.0: معاينة حية للتطبيق داخل إطار هاتف، إنجازات الشرائح 0–8 كاملة (من محرك التخزين والهوية حتى الكاشير والمشتريات والنقدية والطباعة PDF والنسخ الاحتياطي) — معلم MVP محقق، أول حزمة APK على GitHub، و478 اختباراً أخضر.",
  keywords: [
    "FinAcc",
    "المحاسب الشخصي",
    "محاسبة",
    "مخزون",
    "Flutter",
    "تسليم",
    "SRS v1.5",
    "APK",
    "MVP",
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
