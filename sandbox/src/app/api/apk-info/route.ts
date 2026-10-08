import { createHash } from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";

import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

/* معلومات حزمة APK المُخدَّمة من public/downloads — مع تخزين مؤقت بالذاكرة
 * وإبطال تلقائي عند تغيّر mtime (إعادة بناء الحزمة تُحدّث البصمة). */

const APK_PATH = path.join(
  process.cwd(),
  "public",
  "downloads",
  "FinAcc-v0.7.0.apk",
);

type ApkInfo = {
  available: boolean;
  sizeBytes?: number;
  sha256?: string;
  builtAt?: string;
};

let cached: { mtimeMs: number; info: ApkInfo } | null = null;

export async function GET() {
  try {
    const stats = await stat(APK_PATH);
    if (!stats.isFile()) throw new Error("APK file missing");

    if (!cached || cached.mtimeMs !== stats.mtimeMs) {
      const bytes = await readFile(APK_PATH);
      cached = {
        mtimeMs: stats.mtimeMs,
        info: {
          available: true,
          sizeBytes: stats.size,
          sha256: createHash("sha256").update(bytes).digest("hex"),
          builtAt: stats.mtime.toISOString(),
        },
      };
    }

    return NextResponse.json(cached.info);
  } catch {
    return NextResponse.json({ available: false } satisfies ApkInfo);
  }
}
