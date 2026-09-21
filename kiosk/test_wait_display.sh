#!/bin/bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

mkdir -p "$temp/sys/card0-HDMI-A-1" "$temp/sys/card1-HDMI-A-1" "$temp/dev" "$temp/config"
printf 'disconnected\n' > "$temp/sys/card0-HDMI-A-1/status"
printf 'connected\n' > "$temp/sys/card1-HDMI-A-1/status"
mknod "$temp/dev/card0" c 1 3
mknod "$temp/dev/card1" c 1 5

DRM_SYSFS_ROOT="$temp/sys" DRI_ROOT="$temp/dev" XORG_CONFIG_DIR="$temp/config" \
  "$ROOT/kiosk/wait-display.sh"
grep -q "Option \"kmsdev\" \"$temp/dev/card1\"" "$temp/config/20-disag-kms.conf"
grep -q 'Option "AccelMethod" "none"' "$temp/config/20-disag-kms.conf"
echo 'Dynamic DRM selection test passed.'
