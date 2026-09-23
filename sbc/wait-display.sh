#!/bin/bash
set -eu

sysfs_root=${DRM_SYSFS_ROOT:-/sys/class/drm}
dri_root=${DRI_ROOT:-/dev/dri}
fb_root=${FB_ROOT:-/dev}
config_dir=${XORG_CONFIG_DIR:-/run/disag-xorg.conf.d}
selected=''

for _ in $(seq 1 60); do
    fallback=''
    for connector in "$sysfs_root"/card*-HDMI-A-*; do
        [[ -e "$connector" ]] || continue
        name=${connector##*/}
        card=${name%%-*}
        device="$dri_root/$card"
        [[ -c "$device" ]] || continue
        [[ -n "$fallback" ]] || fallback=$device
        if [[ "$(cat "$connector/status" 2>/dev/null || true)" == connected ]]; then
            selected=$device
            break
        fi
    done
    [[ -n "$selected" ]] || selected=$fallback
    [[ -n "$selected" || -c "$fb_root/fb0" ]] && break
    sleep 1
done

install -d -m 755 "$config_dir"
if [[ -n "$selected" ]]; then
    cat > "$config_dir/20-disag-display.conf" <<EOF
Section "Device"
    Identifier "DISAG SBC HDMI KMS"
    Driver "modesetting"
    Option "kmsdev" "$selected"
    Option "AccelMethod" "none"
EndSection
EOF
    echo "Verwende HDMI-DRM-Gerät $selected"
elif [[ -c "$fb_root/fb0" ]]; then
    cat > "$config_dir/20-disag-display.conf" <<EOF
Section "Device"
    Identifier "DISAG SBC framebuffer"
    Driver "fbdev"
    Option "fbdev" "$fb_root/fb0"
EndSection
EOF
    echo "Verwende Framebuffer $fb_root/fb0"
else
    echo 'Weder eine HDMI-DRM-Karte noch /dev/fb0 gefunden.' >&2
    exit 1
fi
