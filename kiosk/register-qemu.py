#!/usr/bin/python3
import os
import re
import subprocess
from pathlib import Path

base = Path('/proc/sys/fs/binfmt_misc')
candidates = [
    os.environ.get('QEMU_AARCH64_STATIC', ''),
    '/usr/bin/qemu-aarch64-static',
    '/var/tmp/disag-tools/qemu8/usr/bin/qemu-aarch64-static',
]
qemu = None
found_versions = []
for candidate in candidates:
    path = Path(candidate) if candidate else None
    if path is None or not path.is_file():
        continue
    version_text = subprocess.check_output([str(path), '--version'], text=True)
    match = re.search(r'version (\d+)', version_text)
    found_versions.append(version_text.splitlines()[0])
    if match and int(match.group(1)) >= 8:
        qemu = path
        break
if qemu is None:
    details = '; '.join(found_versions) if found_versions else 'keine Installation gefunden'
    raise SystemExit(f'QEMU 8 oder neuer wird benötigt: {details}')

entry = base / 'disag-aarch64'
if entry.exists():
    entry.write_text('-1\n')

def escaped(hex_string: str) -> bytes:
    return ''.join('\\x' + hex_string[i:i + 2] for i in range(0, len(hex_string), 2)).encode()

magic = '7f454c460201010000000000000000000200b700'
mask = 'ffffffffffffff00fffffffffffffffffeffffff'
definition = b':disag-aarch64:M::' + escaped(magic) + b':' + escaped(mask)
definition += b':' + str(qemu.resolve()).encode() + b':F\n'
(base / 'register').write_bytes(definition)
print(qemu.resolve())
