#!/bin/bash
# =============================================================================
# Flutter Environment Keeper
# -----------------------------------------------------------------------------
# Everything installed OUTSIDE /home/z/my-project is wiped at every container
# reboot (writable layer). This script re-provisions, idempotently:
#   1. PATH/env exports in ~/.bashrc
#   2. Flutter SDK 3.47.6 (stable)
#   3. Linux desktop toolchain (clang / cmake / ninja / GTK3 dev)
#   4. Android SDK (cmdline-tools + platform 36 + build-tools 36)
#
# It runs automatically at every boot via .zscripts/dev.sh → mini-services/.
# Safe to re-run manually at any time.
# =============================================================================
set -uo pipefail

KEEPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_ROOT="/home/z/flutter"
FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter"
SYSROOT="/home/z/opt/sysroot"
ANDROID_SDK="/home/z/android-sdk"
FLUTTER_VERSION="3.47.6"
CMDTOOLS_VERSION="13114758"
ANDROID_PLATFORM="android-36"
ANDROID_BUILD_TOOLS="36.0.0"
JAVA_HOME_DIR="/usr/lib/jvm/java-21-openjdk-amd64"
say() { echo "[flutter-env] $*"; }

say "keeper started at $(date '+%Y-%m-%d %H:%M:%S')"

# --- 0. Restore custom skills (skills/ is wiped at boot, docs/skills persists) -
if [ -d "$KEEPER_DIR/../docs/skills" ]; then
  mkdir -p "$KEEPER_DIR/../skills"
  for skill_dir in "$KEEPER_DIR/../docs/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    if [ ! -d "$KEEPER_DIR/../skills/$skill_name" ]; then
      cp -r "$skill_dir" "$KEEPER_DIR/../skills/$skill_name"
      say "restored custom skill: $skill_name"
    fi
  done
fi

# --- 1. Make every future shell source env.sh -------------------------------
if ! grep -q "mini-services/flutter-env/env.sh" /home/z/.bashrc 2>/dev/null; then
  echo "source $KEEPER_DIR/env.sh" >> /home/z/.bashrc
  say "added env.sh source to ~/.bashrc"
fi

# --- 2. Flutter SDK -----------------------------------------------------------
if [ ! -x "$FLUTTER_BIN" ]; then
  say "Flutter SDK missing — downloading ${FLUTTER_VERSION}-stable..."
  cd /home/z || exit 1
  if curl -sfL -o flutter_sdk.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"; then
    tar -xf flutter_sdk.tar.xz && rm -f flutter_sdk.tar.xz
    say "Flutter SDK installed."
  else
    say "ERROR: Flutter SDK download failed."
    exit 1
  fi
else
  say "Flutter SDK present."
fi

# --- 3. Linux desktop toolchain ------------------------------------------------
if [ ! -x "$SYSROOT/usr/bin/clang++" ]; then
  say "Linux toolchain missing — downloading .deb set..."
  mkdir -p /home/z/debs "$SYSROOT"
  cd /home/z/debs || exit 1
  apt-get install --print-uris -y --no-install-recommends \
    libgtk-3-dev clang cmake ninja-build 2>/dev/null \
    | grep -oE "'[^']+\.deb'" | tr -d "'" > uris.txt
  if [ -s uris.txt ]; then
    wget -q -i uris.txt -P .
    for f in *.deb; do dpkg -x "$f" "$SYSROOT" 2>/dev/null; done
    say "Linux toolchain installed."
  else
    say "ERROR: could not resolve toolchain packages."
  fi
  cd /home/z && rm -rf /home/z/debs
else
  say "Linux toolchain present."
fi

# --- 4. Android SDK ------------------------------------------------------------
if [ ! -d "$ANDROID_SDK/platforms/$ANDROID_PLATFORM" ]; then
  say "Android SDK missing — provisioning..."
  mkdir -p "$ANDROID_SDK/cmdline-tools"
  cd /home/z || exit 1
  if curl -sfL -o cmdtools.zip \
    "https://dl.google.com/android/repository/commandlinetools-linux-${CMDTOOLS_VERSION}_latest.zip"; then
    rm -rf /tmp/cmdtools && unzip -q cmdtools.zip -d /tmp/cmdtools
    rm -rf "$ANDROID_SDK/cmdline-tools/latest"
    mv /tmp/cmdtools/cmdline-tools "$ANDROID_SDK/cmdline-tools/latest"
    rm -f cmdtools.zip
    export JAVA_HOME="$JAVA_HOME_DIR"
    yes | "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1
    "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" \
      "platform-tools" "platforms;${ANDROID_PLATFORM}" "build-tools;${ANDROID_BUILD_TOOLS}" \
      >/dev/null 2>&1
    say "Android SDK installed."
  else
    say "ERROR: cmdline-tools download failed."
    exit 1
  fi
else
  say "Android SDK present."
fi

# --- 5. Flutter configuration ---------------------------------------------------
# Source the full env (PATH, LD_LIBRARY_PATH, PKG_CONFIG_PATH, CHROME, ...) so
# that `flutter doctor` and subsequent builds see the complete toolchain.
# shellcheck source=env.sh
source "$KEEPER_DIR/env.sh"
export JAVA_HOME="$JAVA_HOME_DIR"
export ANDROID_HOME="$ANDROID_SDK"

"$FLUTTER_BIN" config --android-sdk "$ANDROID_SDK" >/dev/null 2>&1
"$FLUTTER_BIN" --disable-analytics >/dev/null 2>&1 || true

say "environment ready — flutter doctor summary:"
"$FLUTTER_BIN" doctor 2>&1 | sed 's/^/    /'
say "keeper finished."
