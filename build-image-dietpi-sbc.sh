#!/bin/bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
BUILD_WORK=/var/tmp/disag-dietpi-sbc-build
IMAGE="$BUILD_WORK/root"
OUTPUT_BASENAME=${OUTPUT_BASENAME:-voelkersen-disag-dietpi-sbc}

[[ $EUID -eq 0 ]] || { echo 'Bitte mit sudo starten.' >&2; exit 1; }
for file in "$BASE_IMAGE" "$BASE_SHA256" "$ROOT/DISAG-VIZ/classes/BeamerView.class" "$ROOT/images/SVV_Logo.png" "$ROOT/kiosk/boot-splash.png"; do
  test -s "$file" || { echo "$file fehlt. Basisimage bei Bedarf zuerst mit --download laden." >&2; exit 1; }
done
for command in losetup mount chroot parted resize2fs e2fsck zerofree xz Xvfb java javac; do
  command -v "$command" >/dev/null || { echo "Benötigtes Programm fehlt: $command" >&2; exit 1; }
done
if [[ -e "$BUILD_WORK" ]]; then
  mountpoint -q "$IMAGE" && { echo "$IMAGE ist noch eingehängt; Abbruch." >&2; exit 1; }
  test -z "$(losetup -j "$BUILD_WORK/kiosk.img" 2>/dev/null || true)" || { echo 'Das alte Build-Image ist noch als Loop-Gerät aktiv.' >&2; exit 1; }
  [[ "$BUILD_WORK" == /var/tmp/disag-dietpi-sbc-build ]] || exit 1
  rm -rf -- "$BUILD_WORK"
fi
mkdir -p "$BUILD_WORK" "$ROOT/output"

case $(uname -m) in
  aarch64|arm64) QEMU_STATIC=''; echo 'Nativer ARM64-Host erkannt; QEMU-Registrierung wird übersprungen.' ;;
  *) QEMU_STATIC=$(python3 "$ROOT/kiosk/register-qemu.py") ;;
esac
export BUILD_WORK QEMU_STATIC OUTPUT_BASENAME DISAG_TARGET BASE_IMAGE BASE_SHA256

cleanup_on_error() {
  result=$?
  if (( result != 0 )); then
    for path in dev/pts dev proc sys ''; do mountpoint -q "$IMAGE/$path" && umount "$IMAGE/$path" || true; done
    while read -r loop _; do [[ -n "$loop" ]] && losetup -d "${loop%:}" || true; done < <(losetup -j "$BUILD_WORK/kiosk.img" 2>/dev/null || true)
  fi
  exit "$result"
}
trap cleanup_on_error EXIT

bash "$ROOT/sbc/build.sh"
chroot "$IMAGE" /bin/bash /opt/sbc-setup/compact-java.sh
chroot "$IMAGE" /bin/bash /opt/sbc-setup/minimize.sh
bash "$ROOT/sbc/smoke-test.sh"
bash "$ROOT/sbc/finish-logo.sh"
bash "$ROOT/sbc/inspect-build.sh"
bash "$ROOT/sbc/finalize.sh"

trap - EXIT
[[ "$BUILD_WORK" == /var/tmp/disag-dietpi-sbc-build ]]
rm -rf -- "$BUILD_WORK"
echo "Fertig: $ROOT/output/$OUTPUT_BASENAME.img.xz"
