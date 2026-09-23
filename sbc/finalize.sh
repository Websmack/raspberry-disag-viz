#!/bin/bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=${BUILD_WORK:-/var/tmp/disag-dietpi-sbc-build}
IMAGE="$WORK/root"
OUTPUT_BASENAME=${OUTPUT_BASENAME:-voelkersen-disag-dietpi-sbc}
test -s "$ROOT/output/sbc-smoke-result.txt"
test -s "$IMAGE/usr/share/plymouth/themes/voelkersen/boot-splash.png"
LOOP=$(findmnt -n -o SOURCE "$IMAGE" | sed 's/p1$//')
[[ "$LOOP" == /dev/loop* ]]
[[ "$(losetup -n -O BACK-FILE "$LOOP")" == "$WORK/kiosk.img" ]]
chroot "$IMAGE" apt-get clean
for path in var/lib/apt/lists var/cache/apt var/log tmp var/tmp opt/sbc-setup opt/kiosk-common; do
  target=$(realpath "$IMAGE/$path")
  [[ "$target" == "$IMAGE/"* ]] || exit 1
  find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
done
rm -f "$IMAGE/usr/bin/qemu-aarch64-static" "$IMAGE/core" "$IMAGE/opt/DISAG-VIZ/core"
find "$IMAGE/usr/share/doc" -type f ! -name copyright ! -iname '*license*' -delete
find "$IMAGE/usr/share/man" -type f -delete
rm -f "$IMAGE/etc/ssh/ssh_host_"*
truncate -s 0 "$IMAGE/etc/machine-id"
rm -f "$IMAGE/var/lib/dbus/machine-id" "$IMAGE/var/lib/systemd/random-seed"
ln -sfn /etc/machine-id "$IMAGE/var/lib/dbus/machine-id"
sed -i '/^uuid=/d' "$IMAGE/opt/DISAG-VIZ/config/ressources.txt"
chroot "$IMAGE" dpkg-query -W > "$ROOT/output/sbc-packages.txt"
cp "$IMAGE/opt/java-modules.txt" "$ROOT/output/sbc-java-modules.txt"
sync
for path in dev/pts dev proc sys ''; do umount "$IMAGE/$path"; done
# Avoid DietPi's first-boot journal creation and its additional reboot when an
# initramfs is present. Performing this offline is deterministic for all images.
if ! tune2fs -l "${LOOP}p1" | grep -q 'has_journal'; then
  echo 'Adding ext4 journal before image finalization'
  tune2fs -O has_journal "${LOOP}p1"
fi
e2fsck -pf "${LOOP}p1" || test $? -eq 1
resize2fs -M "${LOOP}p1"
blocks=$(dumpe2fs -h "${LOOP}p1" 2>/dev/null | awk '/^Block count:/{print $3}')
blocksize=$(dumpe2fs -h "${LOOP}p1" 2>/dev/null | awk '/^Block size:/{print $3}')
blocks=$((blocks + 128 * 1024 * 1024 / blocksize))
partition_blocks=$(( $(blockdev --getsz "${LOOP}p1") * 512 / blocksize ))
(( blocks <= partition_blocks )) || blocks=$partition_blocks
resize2fs "${LOOP}p1" "$blocks"
e2fsck -pf "${LOOP}p1" || test $? -eq 1
zerofree "${LOOP}p1"
start=$(parted -ms "$LOOP" unit s print | awk -F: '$1==1{gsub("s","",$2);print $2}')
end=$((start + blocks * blocksize / 512 - 1))
losetup -d "$LOOP"
python3 - "$WORK/kiosk.img" "$start" "$end" <<'PY'
from pathlib import Path
import struct, sys
p = Path(sys.argv[1]); start, end = map(int, sys.argv[2:])
with p.open('r+b') as f:
    f.seek(510); assert f.read(2) == b'\x55\xaa'
    f.seek(446 + 8); assert struct.unpack('<I', f.read(4))[0] == start
    f.write(struct.pack('<I', end - start + 1))
    f.truncate((end + 1) * 512)
PY
parted -s "$WORK/kiosk.img" unit B print > "$ROOT/output/sbc-partitions.txt"
xz -T2 -9e -c "$WORK/kiosk.img" > "$ROOT/output/$OUTPUT_BASENAME.img.xz"
cd "$ROOT/output"
xz -t "$OUTPUT_BASENAME.img.xz"
sha256sum "$OUTPUT_BASENAME.img.xz" > "$OUTPUT_BASENAME.img.xz.sha256"
ls -lh "$OUTPUT_BASENAME.img.xz"
