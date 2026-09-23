#!/usr/bin/python3
import os
import re
import subprocess
from pathlib import Path

base = Path('/proc/sys/fs/binfmt_misc')
arch = os.environ.get('TARGET_ARCH', 'arm64')
if arch == 'arm64':
    binary, machine, elf_class = 'qemu-aarch64-static', 'b700', '02'
elif arch == 'armhf':
    binary, machine, elf_class = 'qemu-arm-static', '2800', '01'
else:
    raise SystemExit(f'Nicht unterstützte Zielarchitektur: {arch}')
candidates = [
    os.environ.get('QEMU_STATIC', ''),
    f'/usr/bin/{binary}',
    f'/var/tmp/disag-tools/qemu8/usr/bin/{binary}',
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

entry = base / f'disag-{arch}'
if entry.exists():
    entry.write_text('-1\n')

def escaped(hex_string: str) -> bytes:
    return ''.join('\\x' + hex_string[i:i + 2] for i in range(0, len(hex_string), 2)).encode()

magic = f'7f454c46{elf_class}01010000000000000000000200{machine}'
mask = 'ffffffffffffff00fffffffffffffffffeffffff'
definition = f':disag-{arch}:M::'.encode() + escaped(magic) + b':' + escaped(mask)
definition += b':' + str(qemu.resolve()).encode() + b':F\n'
(base / 'register').write_bytes(definition)
print(qemu.resolve())
