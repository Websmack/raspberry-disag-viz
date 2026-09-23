#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
printf '%s\n' "${DISAG_TARGET:-dietpi-sbc}" > /etc/disag-target
apt_get() {
  apt-get -o Acquire::Retries=5 -o Acquire::http::Pipeline-Depth=0 "$@"
}
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d
apt_get update
apt_get install -y --no-install-recommends binutils openjdk-21-jdk-headless openjdk-21-jre xserver-xorg-core xserver-xorg-video-fbdev xserver-xorg-input-libinput xinit x11-xserver-utils openbox fonts-dejavu-core plymouth plymouth-themes network-manager
id kiosk >/dev/null 2>&1 || useradd -m -s /usr/sbin/nologin kiosk
usermod -s /usr/sbin/nologin -a -G video,render,audio kiosk
passwd -l kiosk
id svvdiag >/dev/null 2>&1 || useradd -m -s /bin/bash svvdiag
usermod -s /bin/bash -a -G systemd-journal svvdiag
printf 'svvdiag:SVV1905!\n' | chpasswd
chown -R kiosk:kiosk /opt/DISAG-VIZ
install -m 755 /opt/kiosk-common/session.sh /usr/local/bin/disag-session
install -m 755 /opt/kiosk-common/display.py /usr/local/bin/disag-display
install -m 755 /opt/kiosk-common/settings.py /usr/local/bin/disag-settings
install -m 755 /opt/kiosk-common/network.py /usr/local/bin/disag-network
install -m 755 /opt/sbc-setup/wait-display.sh /usr/local/bin/disag-wait-display
install -m 644 /opt/kiosk-common/disag.txt /boot/disag.txt
install -m 600 /opt/kiosk-common/network.txt /boot/network.txt
install -m 644 /opt/kiosk-common/disag-kiosk.service /etc/systemd/system/
install -m 644 /opt/kiosk-common/disag-network.service /etc/systemd/system/
install -m 644 /opt/kiosk-common/openbox.xml /etc/xdg/openbox/kiosk.xml
install -m 644 /opt/kiosk-common/kms.conf /etc/X11/xorg.conf.d/20-disag-kms.conf
mkdir -p /etc/systemd/journald.conf.d /etc/systemd/system.conf.d /etc/NetworkManager/system-connections
printf '[Journal]\nStorage=volatile\nRuntimeMaxUse=16M\n' > /etc/systemd/journald.conf.d/kiosk.conf
printf '[Manager]\nRuntimeWatchdogSec=30s\nRebootWatchdogSec=2min\nShowStatus=no\n' > /etc/systemd/system.conf.d/kiosk.conf
python3 /usr/local/bin/disag-network
systemctl enable NetworkManager.service disag-network.service disag-kiosk.service
systemctl set-default multi-user.target
# DietPi führt den ersten Start automatisiert und ohne Dialoge aus.
python3 /opt/kiosk-common/configure-dietpi.py
systemctl mask getty@tty1.service console-getty.service \
  serial-getty@ttyS0.service serial-getty@serial0.service
rm -rf /etc/systemd/system/getty@.service.d \
  /etc/systemd/system/getty@tty1.service.d \
  /etc/systemd/system/serial-getty@.service.d \
  /etc/systemd/system/serial-getty@ttyS0.service.d
systemctl disable systemd-networkd.service ssh.service 2>/dev/null || true
python3 /opt/sbc-setup/boot-config.py
systemctl daemon-reload
systemctl is-enabled --quiet disag-kiosk.service
passwd -S svvdiag | grep -q ' P '
rm -f /usr/sbin/policy-rc.d
apt_get clean
