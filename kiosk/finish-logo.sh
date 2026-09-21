#!/bin/bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
IMAGE=/var/tmp/disag-kiosk-build/root
install -m 644 "$ROOT/kiosk/boot-config.py" "$IMAGE/opt/kiosk-setup/boot-config.py"
chroot "$IMAGE" python3 /opt/kiosk-setup/boot-config.py
test -s "$ROOT/kiosk/logo.png" || { echo 'Missing original club logo: kiosk/logo.png'; exit 1; }
THEME="$IMAGE/usr/share/plymouth/themes/voelkersen"
mkdir -p "$THEME"
install -m 644 "$ROOT/kiosk/logo.png" "$ROOT/kiosk/boot-splash.png" "$ROOT/kiosk/voelkersen.plymouth" "$ROOT/kiosk/voelkersen.script" "$THEME/"
chroot "$IMAGE" plymouth-set-default-theme voelkersen
# Generate both Pi 3/4 and Pi 5 initramfs with the selected logo.
chroot "$IMAGE" update-initramfs -u -k all
for name in initramfs8 initramfs_2712; do
  chroot "$IMAGE" lsinitramfs "/boot/firmware/$name" > "$ROOT/output/$name.contents.txt"
  grep -q 'plymouth/themes/voelkersen/logo.png' "$ROOT/output/$name.contents.txt"
  grep -q 'plymouth/themes/voelkersen/boot-splash.png' "$ROOT/output/$name.contents.txt"
done
