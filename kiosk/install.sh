#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d
apt-get update
apt-get install -y --no-install-recommends openjdk-21-jre xserver-xorg-core xserver-xorg-video-fbdev xserver-xorg-input-libinput xinit x11-xserver-utils openbox fonts-dejavu-core plymouth plymouth-themes
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
install -m 755 /opt/kiosk-setup/wait-display.sh /usr/local/bin/disag-wait-display
install -m 644 /opt/kiosk-setup/disag.txt /boot/firmware/disag.txt
install -m 644 /opt/kiosk-setup/disag-kiosk.service /etc/systemd/system/
install -m 644 /opt/kiosk-setup/openbox.xml /etc/xdg/openbox/kiosk.xml
rm -f /etc/X11/xorg.conf.d/20-disag-fbdev.conf
install -m 644 /opt/kiosk-setup/kms.conf /etc/X11/xorg.conf.d/20-disag-kms.conf
mkdir -p /etc/systemd/journald.conf.d /etc/systemd/system.conf.d
printf '[Journal]\nStorage=volatile\nRuntimeMaxUse=16M\n' > /etc/systemd/journald.conf.d/kiosk.conf
printf '[Manager]\nRuntimeWatchdogSec=30s\nRebootWatchdogSec=2min\nShowStatus=no\n' > /etc/systemd/system.conf.d/kiosk.conf
systemctl enable disag-kiosk.service
systemctl set-default multi-user.target
systemctl mask getty@tty1.service getty@tty3.service console-getty.service userconfig.service userconfig-pi.service
systemctl disable ssh.service 2>/dev/null || true
mkdir -p /etc/NetworkManager/system-connections
cat > /etc/NetworkManager/system-connections/kiosk-lan.nmconnection <<'EOF'
[connection]
id=kiosk-lan
type=ethernet
autoconnect=true
[ethernet]
[ipv4]
method=auto
[ipv6]
method=auto
EOF
chmod 600 /etc/NetworkManager/system-connections/kiosk-lan.nmconnection
python3 /opt/kiosk-setup/boot-config.py
rm -f /usr/sbin/policy-rc.d
apt-get clean
