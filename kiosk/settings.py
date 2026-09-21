#!/usr/bin/python3
"""Import a small, non-executable settings file from the Windows-readable boot partition."""
from pathlib import Path
import re

source = Path('/boot/firmware/disag.txt')
target = Path('/opt/DISAG-VIZ/config/ressources.txt')
if source.exists():
    values = {}
    for line in source.read_text(encoding='utf-8-sig').splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        key, sep, value = line.partition('=')
        key, value = key.strip(), value.strip()
        if not sep or key not in ('serverip', 'serverport', 'vizname'):
            raise SystemExit(f'Invalid setting: {key}')
        if key == 'serverport' and not (value.isdigit() and 1 <= int(value) <= 65535):
            raise SystemExit('Invalid serverport')
        if key == 'serverip' and not re.fullmatch(r'[A-Za-z0-9.:-]+', value):
            raise SystemExit('Invalid serverip')
        if not value or '=' in value:
            raise SystemExit(f'Invalid value for {key}')
        values[key] = value
    lines = target.read_text().splitlines()
    result = [line for line in lines if line.partition('=')[0] not in values]
    result += [f'{key}={value}' for key, value in values.items()]
    # In-place write preserves the application's ownership.
    target.write_text('\n'.join(result) + '\n')
