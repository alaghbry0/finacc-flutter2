#!/bin/bash
# =============================================================================
# Alias wrapper — اسم بوابات التسليم في المرحلة الأولى (build_web_preview).
# يستدعي السكربت المعتمد في SRS §0.2/0.4: scripts/build-flutter-web.sh
# (نفس البناء والنشر إلى public/mobile_app/ — لا ازدواج أبداً).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/build-flutter-web.sh" "$@"
