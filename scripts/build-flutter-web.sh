#!/bin/bash
# =============================================================================
# Build & deploy the Flutter web preview.
# -----------------------------------------------------------------------------
# The sandbox exposes exactly one public port — static-preview owns :3000 behind
# the Caddy gateway. The Flutter app is compiled to a static web bundle and the
# user sees it AT THE GATEWAY ROOT (/) — R22. Previously it lived at
# /mobile_app/index.html inside the R21 phone-frame panel (old links redirect
# 301 to the new root).
#
# Usage:
#   bash scripts/build-flutter-web.sh          # release build
#   bash scripts/build-flutter-web.sh --debug  # faster debug build
#
# Dev loop contract (no hot reload in this sandbox):
#   edit Flutter code → run this script → hard-refresh the preview.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$PROJECT_DIR/mobile_app"
PUBLIC_DIR="$PROJECT_DIR/public/mobile_app"

# Ensure the Flutter environment is loaded (works when run by hand or at boot).
# shellcheck source=../mini-services/flutter-env/env.sh
source "$PROJECT_DIR/mini-services/flutter-env/env.sh"

BUILD_MODE="release"
if [ "${1:-}" = "--debug" ]; then
  BUILD_MODE="debug"
fi

# dart2js O4 gets SIGKILLed (OOM) on the 4GB sandbox — O2 is the sweet spot
# (full minification, a third of the peak memory). --debug builds ignore it.
# --no-wasm-dry-run (الشريحة 10): فحص wasm الجاف يضاعف دورة الترجمة
# ويقتل dart2js بـ OOM بعد نمو الشجرة — نحن نبني لـ CanvasKit حصراً.
D2JS_FLAG=""
if [ "$BUILD_MODE" = "release" ]; then
  D2JS_FLAG="--dart2js-optimization O2 --no-wasm-dry-run"
fi

# use_arabic=true — the `pdf` package ships Arabic glyph-shaping DISABLED by
# default (use_arabic = !use_bidi); without this flag PDF text renders with
# disconnected letters (verified live in the 2026-10-07 round).
ARABIC_FLAG="--dart-define=use_arabic=true"

echo "[build-flutter-web] building mobile_app for web ($BUILD_MODE)..."
cd "$APP_DIR"
# shellcheck disable=SC2086
flutter build web "--${BUILD_MODE}" --base-href / $D2JS_FLAG $ARABIC_FLAG

echo "[build-flutter-web] deploying to $PUBLIC_DIR..."
rm -rf "$PUBLIC_DIR"
mkdir -p "$PUBLIC_DIR"
cp -r build/web/* "$PUBLIC_DIR/"

# -----------------------------------------------------------------------------
# V5 — بصمة محتوى للخط المُقتطع (إصلاح جذري لعلّة «الأيقونات الجديدة لا
# تُرسم بعد البناء»): `MaterialIcons-Regular.otf` اسم ثابت لكن tree-shaking
# يجعل محتواه يتبدل مع كل بناء — فبقي المتصفح على خط قديم من كاش الساعة
# (المساحة تُحجز بالتخطيط والglyph لا يُرسم). الحل المعماري الصحيح — كما
# تفعل كل الحزم الحديثة: إعادة تسمية الملف ببصمة md5 وتحديث FontManifest
# فتصبح URL فريدة لكل بناء (كاش دائم صحيح بلا ساعة تقادم). الخطوط الثابتة
# (cairo/noto/almarai) محتواها مستقر فتبقى بأسمائها.
# -----------------------------------------------------------------------------
FINGERPRINT_FONT() {
  local font_dir="$PUBLIC_DIR/assets/fonts"
  local manifest="$PUBLIC_DIR/assets/FontManifest.json"
  [ -f "$font_dir/MaterialIcons-Regular.otf" ] || return 0
  local hash new_rel manifest_rel
  hash="$(md5sum "$font_dir/MaterialIcons-Regular.otf" | cut -c1-10)"
  # مسار الملف المنشور (نسبي لجذر البناء) — والمحرك يبني URL الطلب
  # بصيغة base + 'assets/' + <قيمة البيان>، فقيمة البيان يجب أن تكون
  # بلا بادئة 'assets/' (الأصل الذي يولّده فلاتر: 'fonts/…' فقط — لو
  # كُتبت بالبادئة صار الطلب assets/assets/… بـ404 وتتعطل كل الأيقونات).
  new_rel="assets/fonts/MaterialIcons-Regular.$hash.otf"
  manifest_rel="fonts/MaterialIcons-Regular.$hash.otf"
  mv "$font_dir/MaterialIcons-Regular.otf" "$PUBLIC_DIR/$new_rel"
  python3 - "$manifest" "$manifest_rel" << 'PYF'
import json, sys
manifest_path, manifest_rel = sys.argv[1], sys.argv[2]
with open(manifest_path, encoding="utf-8") as f:
    data = json.load(f)
for family in data:
    for font in family.get("fonts", []):
        if font.get("asset", "").endswith("MaterialIcons-Regular.otf"):
            font["asset"] = manifest_rel
with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
PYF
  echo "[build-flutter-web] fingerprinted icons font → $new_rel (manifest: $manifest_rel)"
}
FINGERPRINT_FONT

echo "[build-flutter-web] done — preview: http://127.0.0.1:3000/ (app at the gateway root — refresh the page)"
