#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
mapfile -t keep < <(dpkg-query -W -f='${binary:Package}\n' | sed -E 's/:arm(hf|64)$//' | grep -E '^(linux-(image|dtb|u-boot|headers)-|raspi-firmware|firmware-)' || true)
apt-mark manual python3 network-manager xserver-xorg-core xserver-xorg-video-fbdev xserver-xorg-input-libinput xinit x11-xserver-utils openbox fonts-dejavu-core plymouth plymouth-themes "${keep[@]}"
remove=()
while read -r pkg; do
  case "$pkg" in
    gcc-*-base|cpp|cpp-*) continue ;;
    build-essential|gcc|gcc-*|g++|g++-*|linux-headers-*|*-dev|cloud-init) remove+=("$pkg") ;;
  esac
done < <(dpkg-query -W -f='${binary:Package}\n' | sed -E 's/:arm(hf|64)$//')
((${#remove[@]} == 0)) || apt-get purge -y "${remove[@]}"
apt-get autoremove --purge -y
apt-get clean
