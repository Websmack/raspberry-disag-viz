#!/bin/bash
set -eu

sysfs_root=${DRM_SYSFS_ROOT:-/sys/class/drm}
dri_root=${DRI_ROOT:-/dev/dri}
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
    [[ -z "$selected" ]] || break
    sleep 1
done

if [[ -z "$selected" ]]; then
    echo 'Keine DRM-Karte mit HDMI-Anschluss gefunden.' >&2
    exit 1
fi

install -d -m 755 "$config_dir"
cat > "$config_dir/20-disag-kms.conf" <<EOF
Section "Device"
    Identifier "Raspberry Pi HDMI KMS"
    Driver "modesetting"
    Option "kmsdev" "$selected"
    Option "AccelMethod" "none"
EndSection

Section "Monitor"
    Identifier "HDMI television"
EndSection

Section "Screen"
    Identifier "Kiosk screen"
    Device "Raspberry Pi HDMI KMS"
    Monitor "HDMI television"
    DefaultDepth 24
EndSection

Section "ServerLayout"
    Identifier "Kiosk layout"
    Screen "Kiosk screen"
EndSection
EOF

echo "Verwende HDMI-DRM-Gerät $selected"
