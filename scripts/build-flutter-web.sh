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

echo "[build-flutter-web] building mobile_app for web ($BUILD_MODE)..."
cd "$APP_DIR"
flutter build web "--${BUILD_MODE}" --base-href /mobile_app/

echo "[build-flutter-web] deploying to $PUBLIC_DIR..."
rm -rf "$PUBLIC_DIR"
mkdir -p "$PUBLIC_DIR"
cp -r build/web/* "$PUBLIC_DIR/"

echo "[build-flutter-web] done — preview: http://127.0.0.1:3000/mobile_app/index.html"
