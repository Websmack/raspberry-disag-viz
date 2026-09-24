#!/usr/bin/python3
"""Configure DietPi's first boot for an unattended kiosk appliance."""
import os
from pathlib import Path

boot_root = Path(os.environ.get('DISAG_BOOT_ROOT', '/boot'))
paths = [p for p in (boot_root / 'dietpi.txt', boot_root / 'firmware/dietpi.txt') if p.exists()]
if not paths:
    raise SystemExit('DietPi configuration /boot/dietpi.txt not found')

values = {
    'AUTO_SETUP_AUTOMATED': '1',
    'AUTO_SETUP_ACCEPT_LICENSE': '1',
    'AUTO_SETUP_NET_ETHERNET_ENABLED': '1',
    'AUTO_SETUP_NET_WIFI_ENABLED': '0',
    'AUTO_SETUP_NET_USESTATIC': '0',
    # The kiosk starts without a server connection and reconnects itself. Do
    # not let missing DHCP, Internet or Wi-Fi block DietPi firstboot forever.
    'AUTO_SETUP_BOOT_WAIT_FOR_NETWORK': '0',
    'AUTO_SETUP_HEADLESS': '0',
    'AUTO_UNMASK_LOGIND': '1',
    'AUTO_SETUP_SSH_SERVER_INDEX': '-2',
    'AUTO_SETUP_AUTOSTART_TARGET_INDEX': '0',
    'AUTO_SETUP_TIMEZONE': 'Europe/Berlin',
    'AUTO_SETUP_NET_HOSTNAME': 'disag-viz',
    'SURVEY_OPTED_IN': '0',
}
for path in paths:
    result, seen = [], set()
    for line in path.read_text().splitlines():
        key = line.partition('=')[0]
        if key in values:
            result.append(f'{key}={values[key]}')
            seen.add(key)
        else:
            result.append(line)
    result.extend(f'{key}={value}' for key, value in values.items() if key not in seen)
    path.write_text('\n'.join(result) + '\n')
