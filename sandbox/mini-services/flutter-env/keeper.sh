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
#   4b. Temurin JDK 21 (النظام يوفر JRE فقط — بلا javac)
#   4c. علامة NDK الوهمية (تمنع flutter-gradle-plugin من تنزيل NDK بـ4GB
#       على قرص 10GB — التطبيق بلا كود أصلي بعد تثبيت path_provider_android 2.2.17)
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
JDK_DIR="/home/z/opt/jdk21"
FLUTTER_VERSION="3.47.6"
CMDTOOLS_VERSION="13114758"
ANDROID_PLATFORM="android-36"
ANDROID_BUILD_TOOLS="36.0.0"
NDK_STUB_VERSION="28.2.13676358"
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

# --- 4b. Temurin JDK 21 (javac) ------------------------------------------------
if [ ! -x "$JDK_DIR/bin/javac" ]; then
  say "Temurin JDK 21 missing — downloading..."
  mkdir -p "$JDK_DIR"
  if curl -sfL -o /tmp/temurin21.tar.gz \
    "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse"; then
    tar -xzf /tmp/temurin21.tar.gz -C "$JDK_DIR" --strip-components=1
    rm -f /tmp/temurin21.tar.gz
    say "Temurin JDK 21 installed at $JDK_DIR"
  else
    say "ERROR: Temurin JDK download failed — builds will fall back to system JRE (no javac!)."
  fi
else
  say "Temurin JDK 21 present."
fi

# --- 4d. binutils-multiarch (تجريد .so عبر المعماريات) ---------------------------
# llvm-strip/llvm-objcopy يُستدعيان من مسار NDK أعلاه، وstrip النظام أحادي الهدف
# (x86 فقط) — فنثبّت binutils-multiarch ونغلفهما إليه.
MULTIARCH_DIR="/home/z/opt/binutils-multiarch"
if [ ! -x "$MULTIARCH_DIR/usr/bin/x86_64-linux-gnu-strip" ]; then
  say "binutils-multiarch missing — downloading..."
  mkdir -p "$MULTIARCH_DIR" /tmp/multiarch-dl
  if (cd /tmp/multiarch-dl && apt-get download binutils-multiarch >/dev/null 2>&1); then
    dpkg -x /tmp/multiarch-dl/binutils-multiarch_*.deb "$MULTIARCH_DIR"
    rm -rf /tmp/multiarch-dl
    say "binutils-multiarch installed at $MULTIARCH_DIR"
  else
    say "ERROR: binutils-multiarch download failed — release strip will fail."
  fi
else
  say "binutils-multiarch present."
fi

# --- 4c. NDK stub marker (يمنع تنزيل NDK ~4GB) ---------------------------------
# flutter-gradle-plugin يفرض تنزيل NDK ما لم يجد الإصدار "مثبتاً" في
# ANDROID_HOME/ndk — والتطبيق بلا كود أصلي (تثبيت path_provider_android 2.2.17
# عبر dependency_overrides في pubspec). العلامة تكفي لتحقق forceNdkDownload،
# ومهمة stripReleaseDebugSymbols تستدعي llvm-strip من نفس المسار — نوفر غلافاً
# يحوّل إلى GNU strip المتوافق (يجرد ELF لأي معمارية).
NDK_STUB_DIR="$ANDROID_SDK/ndk/$NDK_STUB_VERSION"
if [ ! -f "$NDK_STUB_DIR/source.properties" ]; then
  mkdir -p "$NDK_STUB_DIR"
  printf 'Pkg.Desc = Android NDK (sandbox stub — app has no native code)\nPkg.Revision = %s\n' \
    "$NDK_STUB_VERSION" > "$NDK_STUB_DIR/source.properties"
  say "NDK stub marker created ($NDK_STUB_VERSION)."
else
  say "NDK stub marker present."
fi
NDK_STRIP_DIR="$NDK_STUB_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin"
mkdir -p "$NDK_STRIP_DIR"
MULTIARCH_LIB="$MULTIARCH_DIR/usr/lib/x86_64-linux-gnu"
for tool in strip objcopy; do
  if [ ! -x "$NDK_STRIP_DIR/llvm-$tool" ] && [ -x "$MULTIARCH_DIR/usr/bin/x86_64-linux-gnu-$tool" ]; then
    printf '#!/bin/bash\nexport LD_LIBRARY_PATH="%s${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\nexec %s/usr/bin/x86_64-linux-gnu-%s "$@"\n' \
      "$MULTIARCH_LIB" "$MULTIARCH_DIR" "$tool" > "$NDK_STRIP_DIR/llvm-$tool"
    chmod +x "$NDK_STRIP_DIR/llvm-$tool"
    say "llvm-$tool wrapper (→ binutils-multiarch) created."
  fi
done

# --- 5. Flutter configuration ---------------------------------------------------
# Source the full env (PATH, LD_LIBRARY_PATH, PKG_CONFIG_PATH, CHROME, ...) so
# that `flutter doctor` and subsequent builds see the complete toolchain.
# shellcheck source=env.sh
source "$KEEPER_DIR/env.sh"
if [ -x "$JDK_DIR/bin/javac" ]; then
  export JAVA_HOME="$JDK_DIR"
else
  export JAVA_HOME="$JAVA_HOME_DIR"
fi
export ANDROID_HOME="$ANDROID_SDK"

"$FLUTTER_BIN" config --android-sdk "$ANDROID_SDK" >/dev/null 2>&1
"$FLUTTER_BIN" --disable-analytics >/dev/null 2>&1 || true

say "environment ready — flutter doctor summary:"
"$FLUTTER_BIN" doctor 2>&1 | sed 's/^/    /'
say "keeper finished."
