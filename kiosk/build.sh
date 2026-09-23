#!/bin/bash
set -Eeuo pipefail
export PATH=/opt/disag-e2fsprogs/sbin:$PATH
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=/var/tmp/disag-kiosk-build
BASE_IMAGE=${BASE_IMAGE:?BASE_IMAGE ist nicht gesetzt}
BASE_SHA256=${BASE_SHA256:?BASE_SHA256 ist nicht gesetzt}
mkdir -p "$WORK/root"
expected=$(awk 'NR==1{print $1}' "$BASE_SHA256")
echo "$expected  $BASE_IMAGE" | sha256sum -c -
if [[ ! -e "$WORK/kiosk.img" ]]; then
  xz -dc "$BASE_IMAGE" > "$WORK/kiosk.img"
fi
test -z "$(losetup -j "$WORK/kiosk.img")" || { echo 'Image already attached; refusing concurrent build'; exit 1; }
truncate -s 5G "$WORK/kiosk.img"
parted -s "$WORK/kiosk.img" resizepart 2 100%
LOOP=$(losetup --find --show --partscan "$WORK/kiosk.img")
cleanup() {
  for p in dev/pts dev proc sys boot/firmware ''; do umount "$WORK/root/$p" 2>/dev/null || true; done
  losetup -d "$LOOP" 2>/dev/null || true
}
trap cleanup EXIT
e2fsck -pf "${LOOP}p2" || test $? -eq 1
resize2fs "${LOOP}p2"
mount "${LOOP}p2" "$WORK/root"
mount "${LOOP}p1" "$WORK/root/boot/firmware"
if [[ -n ${QEMU_STATIC:-} ]]; then
  test -x "$QEMU_STATIC"
  cp "$QEMU_STATIC" "$WORK/root/usr/bin/$(basename "$QEMU_STATIC")"
fi
cp -L /etc/resolv.conf "$WORK/root/etc/resolv.conf"
mount --bind /dev "$WORK/root/dev"
mount -t devpts devpts "$WORK/root/dev/pts"
mount -t proc proc "$WORK/root/proc"
mount -t sysfs sysfs "$WORK/root/sys"
mkdir -p "$WORK/root/opt/DISAG-VIZ" "$WORK/root/opt/kiosk-setup"
cp -a "$ROOT/DISAG-VIZ/." "$WORK/root/opt/DISAG-VIZ/"
cp -a "$ROOT/kiosk/." "$WORK/root/opt/kiosk-setup/"
chroot "$WORK/root" /bin/bash /opt/kiosk-setup/install.sh
echo 'Configured image mounted at /var/tmp/disag-kiosk-build/root; finalization pending logo.'
trap - EXIT
