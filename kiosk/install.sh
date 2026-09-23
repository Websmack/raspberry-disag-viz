#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
printf '%s\n' "${DISAG_TARGET:-raspberry-pi}" > /etc/disag-target
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d
mkdir -p /tmp
chown root:root /tmp
chmod 1777 /tmp
apt-get update
apt-get install -y --no-install-recommends \
    locales \
    binutils \
    ca-certificates
sed -i 's/^# *\(de_DE.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen de_DE.UTF-8
cat > /etc/default/locale <<'EOF'
LANG=de_DE.UTF-8
LANGUAGE=de_DE:de
LC_ALL=de_DE.UTF-8
EOF
export LANG=de_DE.UTF-8
export LANGUAGE=de_DE:de
export LC_ALL=de_DE.UTF-8
apt-get install -y --no-install-recommends openjdk-21-jre xserver-xorg-core xserver-xorg-video-fbdev xserver-xorg-input-libinput xinit x11-xserver-utils openbox fonts-dejavu-core plymouth plymouth-themes network-manager
id kiosk >/dev/null 2>&1 || useradd -m -s /usr/sbin/nologin -G video,render,audio kiosk
passwd -l kiosk
id svvdiag >/dev/null 2>&1 || useradd -m -s /bin/bash -G systemd-journal svvdiag
printf 'svvdiag:SVV1905!\n' | chpasswd
chown -R kiosk:kiosk /opt/DISAG-VIZ
# Send application logs to the bounded RAM journal; avoid unbounded SD-card logs.
cat > /opt/DISAG-VIZ/config/logging.properties <<'EOF'
log4j.rootLogger=WARN, stdout
log4j.appender.stdout=org.apache.log4j.ConsoleAppender
log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
log4j.appender.stdout.layout.ConversionPattern=%-5p - %m%n
EOF
install -m 755 /opt/kiosk-setup/session.sh /usr/local/bin/disag-session
install -m 755 /opt/kiosk-setup/display.py /usr/local/bin/disag-display
install -m 755 /opt/kiosk-setup/settings.py /usr/local/bin/disag-settings
install -m 755 /opt/kiosk-setup/network.py /usr/local/bin/disag-network
install -m 755 /opt/kiosk-setup/wait-display.sh /usr/local/bin/disag-wait-display
install -m 644 /opt/kiosk-setup/disag.txt /boot/firmware/disag.txt
install -m 600 /opt/kiosk-setup/network.txt /boot/firmware/network.txt
install -m 644 /opt/kiosk-setup/disag-kiosk.service /etc/systemd/system/
install -m 644 /opt/kiosk-setup/disag-network.service /etc/systemd/system/
install -m 644 /opt/kiosk-setup/openbox.xml /etc/xdg/openbox/kiosk.xml
rm -f /etc/X11/xorg.conf.d/20-disag-fbdev.conf
install -m 644 /opt/kiosk-setup/kms.conf /etc/X11/xorg.conf.d/20-disag-kms.conf
mkdir -p /etc/systemd/journald.conf.d /etc/systemd/system.conf.d
printf '[Journal]\nStorage=volatile\nRuntimeMaxUse=16M\n' > /etc/systemd/journald.conf.d/kiosk.conf
printf '[Manager]\nRuntimeWatchdogSec=30s\nRebootWatchdogSec=2min\nShowStatus=no\n' > /etc/systemd/system.conf.d/kiosk.conf
systemctl enable NetworkManager.service disag-network.service disag-kiosk.service
systemctl set-default multi-user.target
systemctl mask getty@tty1.service getty@tty3.service console-getty.service userconfig.service userconfig-pi.service
systemctl disable ssh.service 2>/dev/null || true
mkdir -p /etc/NetworkManager/system-connections
python3 /usr/local/bin/disag-network
python3 /opt/kiosk-setup/boot-config.py
python3 /opt/kiosk-setup/configure-dietpi.py
rm -f /usr/sbin/policy-rc.d
apt-get clean
