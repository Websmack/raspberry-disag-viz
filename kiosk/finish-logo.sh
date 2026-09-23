#!/bin/bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
IMAGE=/var/tmp/disag-kiosk-build/root

install -m 644 \
    "$ROOT/kiosk/boot-config.py" \
    "$IMAGE/opt/kiosk-setup/boot-config.py"

chroot "$IMAGE" python3 /opt/kiosk-setup/boot-config.py

test -s "$ROOT/kiosk/logo.png" || {
    echo 'Missing original club logo: kiosk/logo.png'
    exit 1
}

THEME="$IMAGE/usr/share/plymouth/themes/voelkersen"
mkdir -p "$THEME"

install -m 644 \
    "$ROOT/kiosk/logo.png" \
    "$ROOT/kiosk/boot-splash.png" \
    "$ROOT/kiosk/voelkersen.plymouth" \
    "$ROOT/kiosk/voelkersen.script" \
    "$THEME/"

chroot "$IMAGE" plymouth-set-default-theme voelkersen

echo "=== Generating initramfs ==="
mapfile -t kernels < <(find "$IMAGE/lib/modules" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

if ((${#kernels[@]} == 0)); then
    echo "ERROR: No installed kernel modules found." >&2
    exit 1
fi

for kernel in "${kernels[@]}"; do
    initrd="/boot/initrd.img-$kernel"
    if [[ -s "$IMAGE$initrd" ]]; then
        chroot "$IMAGE" update-initramfs -u -k "$kernel"
    else
        chroot "$IMAGE" update-initramfs -c -k "$kernel"
    fi

    case "$kernel" in
        *2712*) firmware_initramfs="$IMAGE/boot/firmware/initramfs_2712" ;;
        *v8*) firmware_initramfs="$IMAGE/boot/firmware/initramfs8" ;;
        *v7*) firmware_initramfs="$IMAGE/boot/firmware/initramfs7" ;;
        *)
            echo "ERROR: Unsupported Raspberry Pi kernel for initramfs: $kernel" >&2
            exit 1
            ;;
    esac

    install -m 644 "$IMAGE$initrd" "$firmware_initramfs"
    echo "Installed $(basename "$firmware_initramfs") for kernel $kernel"
done

echo "=== Available kernels ==="
ls -lah "$IMAGE/boot/" || true

echo "=== Available firmware boot files ==="
ls -lah "$IMAGE/boot/firmware/" || true

echo "=== Searching initramfs/initrd ==="
find "$IMAGE/boot" -maxdepth 2 \
    -type f \
    \( -name 'initramfs*' -o -name 'initrd*' \) \
    -print

echo "=== Checking generated initramfs files ==="

mkdir -p "$ROOT/output"

found=0

while IFS= read -r file; do
    [ -f "$file" ] || continue

    relative="${file#$IMAGE}"
    name="$(basename "$file")"

    echo "Checking: $relative"

    chroot "$IMAGE" lsinitramfs "$relative" \
        > "$ROOT/output/$name.contents.txt"

    grep -q 'plymouth/themes/voelkersen/logo.png' \
        "$ROOT/output/$name.contents.txt"

    grep -q 'plymouth/themes/voelkersen/boot-splash.png' \
        "$ROOT/output/$name.contents.txt"

    echo "OK: Plymouth theme found in $relative"

    found=1
done < <(
    find "$IMAGE/boot" -maxdepth 2 \
        -type f \
        \( -name 'initramfs*' -o -name 'initrd.img-*' \)
)

if [ "$found" -eq 0 ]; then
    echo "ERROR: No initramfs generated."
    exit 1
fi
