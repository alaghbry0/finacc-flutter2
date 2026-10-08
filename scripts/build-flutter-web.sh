#!/bin/bash
# =============================================================================
# Build & deploy the Flutter web preview.
# -----------------------------------------------------------------------------
# The sandbox exposes exactly one public port (the Next.js app on :3000), so
# the Flutter app is compiled to a static web bundle and served from the main
# app's public/ folder. The user sees it at /mobile_app/index.html and inside
# the phone-frame preview embedded in the dashboard (/).
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
flutter build web "--${BUILD_MODE}" --base-href /mobile_app/ $D2JS_FLAG $ARABIC_FLAG

echo "[build-flutter-web] deploying to $PUBLIC_DIR..."
rm -rf "$PUBLIC_DIR"
mkdir -p "$PUBLIC_DIR"
cp -r build/web/* "$PUBLIC_DIR/"

echo "[build-flutter-web] done — preview: http://127.0.0.1:3000/mobile_app/index.html"
