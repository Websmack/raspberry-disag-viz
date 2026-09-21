#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
# Preserve the appliance's runtime requirements before removing development tools.
apt-mark manual python3 network-manager raspi-firmware linux-image-rpi-v8 linux-image-rpi-2712 xserver-xorg-core xserver-xorg-video-fbdev xserver-xorg-input-libinput xinit x11-xserver-utils openbox fonts-dejavu-core plymouth plymouth-themes firmware-brcm80211
remove=()
while read -r pkg; do
  case "$pkg" in
    gcc-*-base|cpp|cpp-*) continue ;;
    build-essential|gcc|gcc-*|g++|g++-*|linux-headers-*|*-dev|mkvtoolnix|rpi-connect-lite|cloud-init|firmware-atheros|firmware-mediatek|firmware-realtek|firmware-libertas|firmware-ti-connectivity)
      remove+=("$pkg") ;;
  esac
done < <(dpkg-query -W -f='${binary:Package}\n' | sed 's/:arm64$//')
apt-get purge -y "${remove[@]}"
apt-get autoremove --purge -y
mkdir -p /etc/cloud
touch /etc/cloud/cloud-init.disabled
systemctl disable rpi-connect.service 2>/dev/null || true
apt-get clean
