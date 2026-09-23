#!/bin/bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
IMAGE=${BUILD_WORK:-/var/tmp/disag-dietpi-sbc-build}/root
mkdir -p "$IMAGE/tmp/.X11-unix" "$IMAGE/tmp/kiosk-smoke" /tmp/.X11-unix
mountpoint -q "$IMAGE/tmp/.X11-unix" || mount --bind /tmp/.X11-unix "$IMAGE/tmp/.X11-unix"
Xvfb :98 -screen 0 1920x1080x24 -ac -nolisten tcp > "$ROOT/output/sbc-xvfb.log" 2>&1 &
XVFB=$!
SESSION=''
cleanup() {
  test -z "$SESSION" || kill "$SESSION" 2>/dev/null || true
  kill "$XVFB" 2>/dev/null || true
  test -z "$SESSION" || wait "$SESSION" 2>/dev/null || true
  wait "$XVFB" 2>/dev/null || true
  umount "$IMAGE/tmp/.X11-unix" 2>/dev/null || true
}
trap cleanup EXIT
javac --release 17 -d "$IMAGE/tmp/kiosk-smoke" "$ROOT/kiosk/Capture.java"
for _ in {1..20}; do DISPLAY=:98 xdpyinfo >/dev/null 2>&1 && break; sleep 1; done
chroot "$IMAGE" /usr/bin/env DISPLAY=:98 /usr/local/bin/disag-session > "$ROOT/output/sbc-smoke.log" 2>&1 &
SESSION=$!
sleep 20
kill -0 "$SESSION"
chroot "$IMAGE" /usr/bin/env DISPLAY=:98 /opt/java/bin/java -cp /tmp/kiosk-smoke Capture /tmp/kiosk-smoke/screen.png
cp "$IMAGE/tmp/kiosk-smoke/screen.png" "$ROOT/output/sbc-kiosk-smoke.png"
first=''
for proc in /proc/[0-9]*; do
  if [[ "$(readlink "$proc/root" 2>/dev/null || true)" == "$IMAGE" ]] && tr '\0' ' ' < "$proc/cmdline" 2>/dev/null | grep -Eq '^([^ ]*qemu[^ ]* )?/opt/java/bin/java .*BeamerView'; then first=${proc##*/}; break; fi
done
test -n "$first"
kill -KILL "$first"
sleep 10
kill -0 "$SESSION"
second=''
for proc in /proc/[0-9]*; do
  if [[ "$(readlink "$proc/root" 2>/dev/null || true)" == "$IMAGE" ]] && tr '\0' ' ' < "$proc/cmdline" 2>/dev/null | grep -Eq '^([^ ]*qemu[^ ]* )?/opt/java/bin/java .*BeamerView'; then second=${proc##*/}; break; fi
done
test -n "$second"; test "$first" != "$second"
printf 'ARM64 Java GUI launched; killed PID %s; supervisor restarted PID %s.\n' "$first" "$second" | tee "$ROOT/output/sbc-smoke-result.txt"
