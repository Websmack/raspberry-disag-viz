#!/bin/bash
set -Eeuo pipefail
IMAGE=${BUILD_WORK:-/var/tmp/disag-dietpi-sbc-build}/root
ROOT=$(cd "$(dirname "$0")/.." && pwd)
for script in "$ROOT"/sbc/*.sh; do bash -n "$script"; done
python3 "$ROOT/kiosk/test_display.py"
python3 "$ROOT/kiosk/test_network.py"
test -x "$IMAGE/opt/java/bin/java"
test -x "$IMAGE/usr/bin/Xorg"
test -s "$IMAGE/usr/lib/xorg/modules/drivers/modesetting_drv.so"
test -s "$IMAGE/boot/dietpi.txt"
grep -q '^AUTO_SETUP_AUTOMATED=1$' "$IMAGE/boot/dietpi.txt"
test -s "$IMAGE/boot/disag.txt"
test -s "$IMAGE/boot/network.txt"
chroot "$IMAGE" dpkg --audit
test "$(chroot "$IMAGE" systemctl is-enabled disag-kiosk.service)" = enabled
test "$(chroot "$IMAGE" systemctl is-enabled disag-network.service)" = enabled
test "$(chroot "$IMAGE" systemctl is-enabled NetworkManager.service)" = enabled
test "$(chroot "$IMAGE" systemctl is-enabled getty@tty1.service)" = masked
test "$(chroot "$IMAGE" systemctl is-enabled serial-getty@ttyS0.service)" = masked
chroot "$IMAGE" passwd -S svvdiag | grep -q ' P '
chroot "$IMAGE" getent passwd svvdiag | grep -q ':/home/svvdiag:/bin/bash$'
chroot "$IMAGE" /opt/java/bin/java -version
df -h "$IMAGE"
