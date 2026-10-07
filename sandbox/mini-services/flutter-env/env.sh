# Flutter development environment exports.
# Sourced from ~/.bashrc (line added by mini-services/flutter-env/keeper.sh).

export PATH="/home/z/flutter/bin:/home/z/opt/sysroot/usr/bin:$PATH"
export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
export ANDROID_HOME="/home/z/android-sdk"

# Chrome for `flutter run -d chrome` / web builds. The versioned directory
# name can change between container boots, so resolve it dynamically.
CHROME_BIN="$(ls -d /home/z/.agent-browser/browsers/chrome-*/chrome 2>/dev/null | head -1)"
[ -n "$CHROME_BIN" ] && export CHROME_EXECUTABLE="$CHROME_BIN"

# Portable Linux toolchain (clang / cmake / ninja / GTK3 dev) extracted to sysroot
export LD_LIBRARY_PATH="/home/z/opt/sysroot/usr/lib/x86_64-linux-gnu:/home/z/opt/sysroot/usr/lib:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="/home/z/opt/sysroot/usr/lib/x86_64-linux-gnu/pkgconfig:/home/z/opt/sysroot/usr/share/pkgconfig:${PKG_CONFIG_PATH:-}"
