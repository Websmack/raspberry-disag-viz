#!/usr/bin/python3
"""Select one HDMI television, preferring real EDID over the boot fallback."""
import re
import subprocess
from pathlib import Path


def configure():
    query = subprocess.check_output(['xrandr', '--query'], text=True)
    connected = re.findall(r'^(\S+) connected', query, re.M)
    if not connected:
        return
    actual = []
    for edid in sorted(Path('/sys/class/drm').glob('card*-HDMI-A-*/edid')):
        try:
            if edid.read_bytes():
                number = edid.parent.name.rsplit('-', 1)[1]
                actual.extend([f'HDMI-{number}', f'HDMI-A-{number}'])
        except OSError:
            pass
    chosen = next((name for name in connected if name in actual), connected[0])
    # EDID's preferred mode wins over the forced 1080p boot fallback.
    command = ['xrandr', '--output', chosen, '--primary', '--pos', '0x0']
    command += ['--auto']
    for name in connected:
        if name != chosen:
            command += ['--output', name, '--off']
    subprocess.run(command, check=True, timeout=15)


if __name__ == '__main__':
    configure()
