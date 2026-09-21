#!/bin/bash
set -Eeuo pipefail
export PATH=/opt/disag-e2fsprogs/sbin:$PATH
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=/var/tmp/disag-kiosk-build
IMAGE="$WORK/root"
test -s "$ROOT/output/smoke-result.txt"
test -s "$IMAGE/usr/share/plymouth/themes/voelkersen/logo.png"
test -s "$IMAGE/usr/share/plymouth/themes/voelkersen/boot-splash.png"
LOOP=$(findmnt -n -o SOURCE "$IMAGE" | sed 's/p2$//')
[[ "$LOOP" == /dev/loop* ]]
[[ "$(losetup -n -O BACK-FILE "$LOOP")" == "$WORK/kiosk.img" ]]
if mountpoint -q "$IMAGE/tmp/.X11-unix"; then
  echo 'Smoke-test socket mount still active; stop test and unmount it first.'
  exit 1
fi
# Remove only generated caches, test material and build tools inside this image.
chroot "$IMAGE" apt-get clean
for path in var/lib/apt/lists var/cache/apt var/log tmp var/tmp opt/kiosk-setup; do
  target=$(realpath "$IMAGE/$path")
  [[ "$target" == "$IMAGE/"* ]] || exit 1
  find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
done
rm -f "$IMAGE/usr/bin/qemu-aarch64-static"
rm -f "$IMAGE/core" "$IMAGE/opt/DISAG-VIZ/core"
# Preserve package copyright/license notices while omitting offline manuals.
find "$IMAGE/usr/share/doc" -type f ! -name copyright ! -iname '*license*' -delete
find "$IMAGE/usr/share/man" -type f -delete
rm -f "$IMAGE/etc/ssh/ssh_host_"*
truncate -s 0 "$IMAGE/etc/machine-id"
rm -f "$IMAGE/var/lib/dbus/machine-id" "$IMAGE/var/lib/systemd/random-seed"
ln -s /etc/machine-id "$IMAGE/var/lib/dbus/machine-id"
rm -f "$IMAGE/etc/resolv.conf"
ln -s /run/NetworkManager/resolv.conf "$IMAGE/etc/resolv.conf"
sed -i '/^uuid=/d' "$IMAGE/opt/DISAG-VIZ/config/ressources.txt"
chroot "$IMAGE" dpkg-query -W > "$ROOT/output/packages.txt"
cp "$IMAGE/opt/java-modules.txt" "$ROOT/output/java-modules.txt"
sync
for path in dev/pts dev proc sys boot/firmware ''; do umount "$IMAGE/$path"; done
e2fsck -pf "${LOOP}p2" || test $? -eq 1
resize2fs -M "${LOOP}p2"
blocks=$(dumpe2fs -h "${LOOP}p2" 2>/dev/null | awk '/^Block count:/{print $3}')
blocksize=$(dumpe2fs -h "${LOOP}p2" 2>/dev/null | awk '/^Block size:/{print $3}')
# Retain 128 MiB of working space; the original resize hook expands at first boot.
blocks=$((blocks + 128 * 1024 * 1024 / blocksize))
partition_blocks=$(( $(blockdev --getsz "${LOOP}p2") * 512 / blocksize ))
if (( blocks > partition_blocks )); then
  blocks=$partition_blocks
fi
resize2fs "${LOOP}p2" "$blocks"
e2fsck -pf "${LOOP}p2" || test $? -eq 1
zerofree "${LOOP}p2"
start=$(parted -ms "$LOOP" unit s print | awk -F: '$1==2{gsub("s","",$2);print $2}')
end=$((start + blocks * blocksize / 512 - 1))
losetup -d "$LOOP"
# Rewrite only the partition-2 length in the MBR of our build image.
python3 - "$WORK/kiosk.img" "$start" "$end" <<'PY'
from pathlib import Path
import struct, sys
p=Path(sys.argv[1]); start,end=map(int,sys.argv[2:])
with p.open('r+b') as f:
    f.seek(510)
    assert f.read(2)==b'\x55\xaa'
    f.seek(446+16+8)
    assert struct.unpack('<I',f.read(4))[0]==start
    f.write(struct.pack('<I',end-start+1))
    f.truncate((end+1)*512)
PY
parted -s "$WORK/kiosk.img" unit B print > "$ROOT/output/partitions.txt"
xz -T2 -9e -c "$WORK/kiosk.img" > "$ROOT/output/voelkersen-disag-pi3-pi5.img.xz"
cd "$ROOT/output"
xz -t voelkersen-disag-pi3-pi5.img.xz
sha256sum voelkersen-disag-pi3-pi5.img.xz > voelkersen-disag-pi3-pi5.img.xz.sha256
ls -lh voelkersen-disag-pi3-pi5.img.xz
