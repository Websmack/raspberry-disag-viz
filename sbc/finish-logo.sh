#!/bin/bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
IMAGE=${BUILD_WORK:-/var/tmp/disag-dietpi-sbc-build}/root
THEME="$IMAGE/usr/share/plymouth/themes/voelkersen"
mkdir -p "$THEME"
install -m 644 "$ROOT/kiosk/logo.png" "$ROOT/kiosk/boot-splash.png" "$ROOT/kiosk/voelkersen.plymouth" "$ROOT/kiosk/voelkersen.script" "$THEME/"
chroot "$IMAGE" plymouth-set-default-theme voelkersen
chroot "$IMAGE" update-initramfs -u -k all
found=0
for initrd in "$IMAGE"/boot/initrd.img-*; do
  [[ -s "$initrd" ]] || continue
  chroot "$IMAGE" lsinitramfs "${initrd#$IMAGE}" > "$ROOT/output/sbc-initramfs.contents.txt"
  grep -q 'plymouth/themes/voelkersen/boot-splash.png' "$ROOT/output/sbc-initramfs.contents.txt"
  found=1
done
(( found == 1 ))
