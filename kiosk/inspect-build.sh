#!/bin/bash
set -eu
IMAGE=/var/tmp/disag-kiosk-build/root
ROOT=$(cd "$(dirname "$0")/.." && pwd)
for script in "$ROOT"/kiosk/*.sh; do bash -n "$script"; done
python3 "$ROOT/kiosk/test_display.py"
python3 "$ROOT/kiosk/test_network.py"
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
chroot "$IMAGE" systemctl is-enabled disag-network.service
chroot "$IMAGE" systemctl is-enabled NetworkManager.service
test -s "$IMAGE/boot/firmware/network.txt"
test -s "$IMAGE/etc/NetworkManager/system-connections/kiosk-lan.nmconnection"
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
chroot "$IMAGE" systemctl is-enabled getty@tty2.service | grep -q enabled
chroot "$IMAGE" systemctl is-enabled console-getty.service | grep -q masked
for dietpi_config in "$IMAGE/boot/dietpi.txt" "$IMAGE/boot/firmware/dietpi.txt"; do
  test -f "$dietpi_config" || continue
  grep -q '^AUTO_SETUP_HEADLESS=0$' "$dietpi_config"
  grep -q '^AUTO_UNMASK_LOGIND=1$' "$dietpi_config"
done
chroot "$IMAGE" id svvdiag | grep -q 'systemd-journal'
chroot "$IMAGE" passwd -S svvdiag | grep -q ' P '
test ! -e "$IMAGE/etc/sudoers.d/svvdiag"
grep -q 'console=tty1' "$IMAGE/boot/firmware/cmdline.txt"
grep -q 'systemd.show_status=false' "$IMAGE/boot/firmware/cmdline.txt"
grep -q '^auto_initramfs=1$' "$IMAGE/boot/firmware/config.txt"
grep -Eq '^[[:space:]]*dtoverlay=vc4-kms-v3d' "$IMAGE/boot/firmware/config.txt"
find "$IMAGE/boot/firmware" -maxdepth 1 -type f \( -name 'initramfs7' -o -name 'initramfs8' -o -name 'initramfs_2712' \) -size +0c | grep -q .
df -h "$IMAGE" "$IMAGE/boot/firmware"
