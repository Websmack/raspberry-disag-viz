#!/usr/bin/python3
"""Configure DietPi's first boot for an unattended kiosk appliance."""
from pathlib import Path

path = next((p for p in (Path('/boot/dietpi.txt'), Path('/boot/firmware/dietpi.txt')) if p.exists()), None)
if path is None:
    raise SystemExit('DietPi configuration /boot/dietpi.txt not found')

values = {
    'AUTO_SETUP_AUTOMATED': '1',
    'AUTO_SETUP_ACCEPT_LICENSE': '1',
    'AUTO_SETUP_NET_ETHERNET_ENABLED': '1',
    'AUTO_SETUP_NET_WIFI_ENABLED': '0',
    'AUTO_SETUP_NET_USESTATIC': '0',
    'AUTO_SETUP_BOOT_WAIT_FOR_NETWORK': '1',
    'AUTO_SETUP_HEADLESS': '1',
    'AUTO_SETUP_SSH_SERVER_INDEX': '-2',
    'AUTO_SETUP_AUTOSTART_TARGET_INDEX': '0',
    'AUTO_SETUP_TIMEZONE': 'Europe/Berlin',
    'AUTO_SETUP_NET_HOSTNAME': 'disag-viz',
    'SURVEY_OPTED_IN': '0',
}
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
