from pathlib import Path

for name in ('disag-arm64', 'disag-armhf', 'disag-aarch64'):
    entry = Path('/proc/sys/fs/binfmt_misc') / name
    if entry.exists():
        entry.write_text('-1\n')
Path('/var/tmp/disag-kiosk-build/keepalive').unlink(missing_ok=True)
print('Temporary ARM emulator registration and WSL keepalive removed.')
