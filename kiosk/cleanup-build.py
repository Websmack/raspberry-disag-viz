from pathlib import Path

entry = Path('/proc/sys/fs/binfmt_misc/disag-aarch64')
if entry.exists():
    entry.write_text('-1\n')
Path('/var/tmp/disag-kiosk-build/keepalive').unlink(missing_ok=True)
print('Temporary ARM emulator registration and WSL keepalive removed.')
