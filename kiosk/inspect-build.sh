#!/bin/bash
set -eu
IMAGE=/var/tmp/disag-kiosk-build/root
ROOT=$(cd "$(dirname "$0")/.." && pwd)
for script in "$ROOT"/kiosk/*.sh; do bash -n "$script"; done
python3 "$ROOT/kiosk/test_display.py"
bash "$ROOT/kiosk/test_wait_display.sh"
chroot "$IMAGE" dpkg-query -W '-f=${Installed-Size}\t${binary:Package}\n' | sort -nr | head -25
find "$IMAGE/usr/share/initramfs-tools" -type f -iname '*resize*' -o -iname '*raspi*'
cat "$IMAGE/usr/lib/systemd/system/plymouth-quit.service"
cat "$IMAGE/usr/lib/systemd/system/plymouth-quit-wait.service"
cat "$IMAGE/etc/fstab"
cat "$IMAGE/boot/firmware/cmdline.txt"
cat "$IMAGE/boot/firmware/config.txt"
chroot "$IMAGE" dpkg --audit
chroot "$IMAGE" systemctl is-enabled disag-kiosk.service
chroot "$IMAGE" systemctl is-enabled NetworkManager.service
test -x "$IMAGE/usr/bin/xrandr"
test -x "$IMAGE/usr/bin/xhost"
test -x "$IMAGE/usr/bin/xset"
test -x "$IMAGE/usr/bin/Xorg"
test -s "$IMAGE/usr/lib/xorg/modules/drivers/modesetting_drv.so"
test -s "$IMAGE/etc/X11/xorg.conf.d/20-disag-kms.conf"
grep -q 'Driver "modesetting"' "$IMAGE/etc/X11/xorg.conf.d/20-disag-kms.conf"
grep -q 'Option "kmsdev"' "$IMAGE/usr/local/bin/disag-wait-display"
grep -q -- '-configdir /run/disag-xorg.conf.d' "$IMAGE/etc/systemd/system/disag-kiosk.service"
test ! -e "$IMAGE/etc/X11/xorg.conf.d/20-disag-fbdev.conf"
test -s "$IMAGE/usr/share/plymouth/themes/voelkersen/boot-splash.png"
grep -q 'Image("boot-splash.png")' "$IMAGE/usr/share/plymouth/themes/voelkersen/voelkersen.script"
test -s "$IMAGE/opt/java/lib/security/cacerts"
chroot "$IMAGE" systemctl is-enabled getty@tty1.service | grep -q masked
chroot "$IMAGE" systemctl is-enabled console-getty.service | grep -q masked
chroot "$IMAGE" id svvdiag | grep -q 'systemd-journal'
chroot "$IMAGE" passwd -S svvdiag | grep -q ' P '
test ! -e "$IMAGE/etc/sudoers.d/svvdiag"
grep -q 'console=tty1' "$IMAGE/boot/firmware/cmdline.txt"
grep -q 'systemd.show_status=false' "$IMAGE/boot/firmware/cmdline.txt"
df -h "$IMAGE" "$IMAGE/boot/firmware"
