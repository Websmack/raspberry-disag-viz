#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
# Preserve the appliance's runtime requirements before removing development tools.
keep=(python3 network-manager raspi-firmware xserver-xorg-core xserver-xorg-video-fbdev xserver-xorg-input-libinput xinit x11-xserver-utils openbox fonts-dejavu-core plymouth plymouth-themes firmware-brcm80211)
while IFS= read -r package; do keep+=("$package"); done < <(dpkg-query -W -f='${binary:Package}\n' 'linux-image-rpi-*' 2>/dev/null || true)
apt-mark manual "${keep[@]}"
remove=()
while read -r pkg; do
  case "$pkg" in
    gcc-*-base|cpp|cpp-*) continue ;;
    build-essential|gcc|gcc-*|g++|g++-*|linux-headers-*|*-dev|mkvtoolnix|rpi-connect-lite|cloud-init|firmware-atheros|firmware-mediatek|firmware-realtek|firmware-libertas|firmware-ti-connectivity)
      remove+=("$pkg") ;;
  esac
done < <(dpkg-query -W -f='${binary:Package}\n' | sed -E 's/:(arm64|armhf)$//')
apt-get purge -y "${remove[@]}"
apt-get autoremove --purge -y
mkdir -p /etc/cloud
touch /etc/cloud/cloud-init.disabled
systemctl disable rpi-connect.service 2>/dev/null || true
apt-get clean
