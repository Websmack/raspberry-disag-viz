#!/usr/bin/python3
"""Enable a quiet splash on DietPi's generic SBC boot configuration."""
from pathlib import Path

path = Path('/boot/dietpiEnv.txt')
if not path.exists():
    path = Path('/boot/dietpiEnv.ini')
if path.exists():
    lines = path.read_text().splitlines()
    wanted = 'quiet splash logo.nologo vt.global_cursor_default=0 loglevel=0 systemd.show_status=false'
    result = []
    found = False
    for line in lines:
        if line.startswith('extraargs='):
            value = line.partition('=')[2]
            for option in wanted.split():
                if option not in value.split():
                    value = f'{value} {option}'.strip()
            line = f'extraargs={value}'
            found = True
        result.append(line)
    if not found:
        result.append(f'extraargs={wanted}')
    path.write_text('\n'.join(result) + '\n')
