#!/usr/bin/python3
from pathlib import Path

config = Path('/boot/firmware/config.txt')
marker = '# DISAG kiosk, Raspberry Pi 3 and later'
original = config.read_text().split(marker, 1)[0].rstrip()
if 'dtoverlay=vc4-kms-v3d' not in original:
    original += '\n[all]\ndtoverlay=vc4-kms-v3d'
config.write_text(original + '\n\n' + marker + '\n[all]\nauto_initramfs=1\ndisable_splash=1\ndisable_fw_kms_setup=1\ndtparam=watchdog=on\n')
cmdline = Path('/boot/firmware/cmdline.txt')
prefixes = ('console=', 'video=', 'init=', 'systemd.run', 'loglevel=', 'vt.global_cursor_default=', 'systemd.show_status=', 'rd.systemd.show_status=')
args = [arg for arg in cmdline.read_text().split() if not arg.startswith(prefixes) and arg not in ('quiet', 'splash', 'logo.nologo')]
args += ['console=tty1', 'quiet', 'splash', 'logo.nologo', 'vt.global_cursor_default=0', 'loglevel=0', 'systemd.show_status=false', 'rd.systemd.show_status=false', 'video=HDMI-A-1:1920x1080@60D']
cmdline.write_text(' '.join(args) + '\n')
