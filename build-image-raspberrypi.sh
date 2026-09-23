#!/bin/bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
WORK=/var/tmp/disag-kiosk-build
IMAGE="$WORK/root"
OUTPUT_BASENAME=${OUTPUT_BASENAME:-voelkersen-disag-raspberry-pi}
DISAG_TARGET=${DISAG_TARGET:-raspberry-pi}
BASE_IMAGE=${BASE_IMAGE:?BASE_IMAGE ist nicht gesetzt; bitte build-image.sh verwenden}
BASE_SHA256=${BASE_SHA256:?BASE_SHA256 ist nicht gesetzt; bitte build-image.sh verwenden}

[[ $EUID -eq 0 ]] || { echo 'Bitte mit sudo starten.' >&2; exit 1; }
test -s "$BASE_IMAGE" || { echo "$BASE_IMAGE fehlt. Zuerst ohne sudo mit --download laden." >&2; exit 1; }
test -s "$BASE_SHA256" || { echo "$BASE_SHA256 fehlt. Zuerst ohne sudo mit --download laden." >&2; exit 1; }
test -s "$ROOT/DISAG-VIZ/classes/BeamerView.class" || { echo 'DISAG-VIZ enthält keine vollständige VIZ-Anwendung.' >&2; exit 1; }
test -s "$ROOT/images/SVV_Logo.png" || { echo 'images/SVV_Logo.png fehlt.' >&2; exit 1; }
test -s "$ROOT/kiosk/boot-splash.png" || { echo 'Logo zuerst mit tools/prepare-logo.sh oder tools/prepare-logo.ps1 vorbereiten.' >&2; exit 1; }
for command in losetup mount chroot parted resize2fs e2fsck zerofree xz Xvfb java javac; do
  command -v "$command" >/dev/null || { echo "Benötigtes Programm fehlt: $command" >&2; exit 1; }
done
if [[ -e "$WORK" ]]; then
  mountpoint -q "$IMAGE" && { echo "$IMAGE ist noch eingehängt; Abbruch." >&2; exit 1; }
  test -z "$(losetup -j "$WORK/kiosk.img" 2>/dev/null || true)" || { echo 'Das alte Build-Image ist noch als Loop-Gerät aktiv.' >&2; exit 1; }
  [[ "$WORK" == /var/tmp/disag-kiosk-build ]] || exit 1
  rm -rf -- "$WORK"
fi
mkdir -p "$WORK" "$ROOT/output"
case "$DIETPI_IMAGE" in
  *-ARMv7-*) TARGET_ARCH=armhf; native_pattern='armv7l|armv8l';;
  *-ARMv8-*) TARGET_ARCH=arm64; native_pattern='aarch64|arm64';;
  *) echo "Nicht unterstützte Raspberry-Pi-Architektur: $DIETPI_IMAGE" >&2; exit 1;;
esac
if [[ $(uname -m) =~ ^($native_pattern)$ ]]; then
  QEMU_STATIC=''
  echo "Nativer $TARGET_ARCH-Host erkannt; QEMU-Registrierung wird übersprungen."
else
  QEMU_STATIC=$(TARGET_ARCH="$TARGET_ARCH" python3 "$ROOT/kiosk/register-qemu.py")
fi
export QEMU_STATIC TARGET_ARCH OUTPUT_BASENAME DISAG_TARGET BASE_IMAGE BASE_SHA256
cleanup_on_error() {
  status=$?
  if (( status != 0 )); then
    for path in dev/pts dev proc sys boot/firmware ''; do mountpoint -q "$IMAGE/$path" && umount "$IMAGE/$path" || true; done
    while read -r loop _; do [[ -n "$loop" ]] && losetup -d "${loop%:}" || true; done < <(losetup -j "$WORK/kiosk.img" 2>/dev/null || true)
  fi
  python3 "$ROOT/kiosk/cleanup-build.py" >/dev/null 2>&1 || true
  exit "$status"
}
trap cleanup_on_error EXIT
bash "$ROOT/kiosk/build.sh"
chroot "$IMAGE" /bin/bash /opt/kiosk-setup/compact-java.sh
chroot "$IMAGE" /bin/bash /opt/kiosk-setup/minimize.sh
bash "$ROOT/kiosk/smoke-test.sh"
bash "$ROOT/kiosk/finish-logo.sh"
bash "$ROOT/kiosk/inspect-build.sh"
bash "$ROOT/kiosk/finalize.sh"
trap - EXIT
python3 "$ROOT/kiosk/cleanup-build.py"
echo "Fertig: $ROOT/output/$OUTPUT_BASENAME.img.xz"
