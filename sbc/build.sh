#!/bin/bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=${BUILD_WORK:-/var/tmp/disag-dietpi-sbc-build}
IMAGE="$WORK/root"
BASE_IMAGE=${BASE_IMAGE:?BASE_IMAGE ist nicht gesetzt}
BASE_SHA256=${BASE_SHA256:?BASE_SHA256 ist nicht gesetzt}
mkdir -p "$IMAGE"
expected=$(awk 'NR==1{print $1}' "$BASE_SHA256")
echo "$expected  $BASE_IMAGE" | sha256sum -c -
[[ -e "$WORK/kiosk.img" ]] || xz -dc "$BASE_IMAGE" > "$WORK/kiosk.img"
test -z "$(losetup -j "$WORK/kiosk.img")" || { echo 'Image already attached; refusing concurrent build'; exit 1; }
truncate -s 5G "$WORK/kiosk.img"
parted -s "$WORK/kiosk.img" resizepart 1 100%
LOOP=$(losetup --find --show --partscan "$WORK/kiosk.img")
cleanup() {
  for path in dev/pts dev proc sys ''; do umount "$IMAGE/$path" 2>/dev/null || true; done
  losetup -d "$LOOP" 2>/dev/null || true
}
trap cleanup EXIT
e2fsck -pf "${LOOP}p1" || test $? -eq 1
resize2fs "${LOOP}p1"
mount "${LOOP}p1" "$IMAGE"
if [[ -n ${QEMU_STATIC:-} ]]; then install -m 755 "$QEMU_STATIC" "$IMAGE/usr/bin/qemu-aarch64-static"; fi
RESOLV_LINK=''
if [[ -L "$IMAGE/etc/resolv.conf" ]]; then
  RESOLV_LINK=$(readlink "$IMAGE/etc/resolv.conf")
fi
# Absolute links in SBC images are resolved against the build host here.
# Replace the link temporarily so apt in the chroot can resolve package servers.
rm -f "$IMAGE/etc/resolv.conf"
RESOLV_SOURCE=/etc/resolv.conf
if [[ -s /run/systemd/resolve/resolv.conf ]]; then
  RESOLV_SOURCE=/run/systemd/resolve/resolv.conf
fi
install -m 644 "$RESOLV_SOURCE" "$IMAGE/etc/resolv.conf"
mount --bind /dev "$IMAGE/dev"
mount -t devpts devpts "$IMAGE/dev/pts"
mount -t proc proc "$IMAGE/proc"
mount -t sysfs sysfs "$IMAGE/sys"
mkdir -p "$IMAGE/opt/DISAG-VIZ" "$IMAGE/opt/sbc-setup" "$IMAGE/opt/kiosk-common"
cp -a "$ROOT/DISAG-VIZ/." "$IMAGE/opt/DISAG-VIZ/"
cp -a "$ROOT/sbc/." "$IMAGE/opt/sbc-setup/"
cp -a "$ROOT/kiosk/." "$IMAGE/opt/kiosk-common/"
mkdir -p "$IMAGE/opt/kiosk-common/config"
cp -a "$ROOT/config/disag.txt" "$ROOT/config/network.txt" "$IMAGE/opt/kiosk-common/config/"
chroot "$IMAGE" /bin/bash /opt/sbc-setup/install.sh
if [[ -n "$RESOLV_LINK" ]]; then
  rm -f "$IMAGE/etc/resolv.conf"
  ln -s "$RESOLV_LINK" "$IMAGE/etc/resolv.conf"
fi
trap - EXIT
