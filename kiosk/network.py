#!/usr/bin/python3
"""Create NetworkManager profiles from the editable boot configuration."""
from __future__ import annotations

import ipaddress
import os
from pathlib import Path
import re
import tempfile


ALLOWED = {
    'lan_enabled', 'lan_method', 'lan_address', 'lan_gateway', 'lan_dns',
    'wifi_enabled', 'wifi_ssid', 'wifi_password', 'wifi_country',
    'wifi_method', 'wifi_address', 'wifi_gateway', 'wifi_dns',
}
REQUIRED = ALLOWED


def read_config(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for number, line in enumerate(path.read_text(encoding='utf-8-sig').splitlines(), 1):
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        key, separator, value = line.partition('=')
        key, value = key.strip(), value.strip()
        if not separator or key not in ALLOWED:
            raise ValueError(f'Ungültige Einstellung in Zeile {number}: {key}')
        if key in values:
            raise ValueError(f'Doppelte Einstellung: {key}')
        if any(ord(character) < 32 for character in value):
            raise ValueError(f'Ungültiges Steuerzeichen in: {key}')
        values[key] = value
    missing = REQUIRED - values.keys()
    if missing:
        raise ValueError(f'Fehlende Einstellungen: {", ".join(sorted(missing))}')
    return values


def enabled(value: str, key: str) -> bool:
    normalized = value.lower()
    if normalized not in {'yes', 'no'}:
        raise ValueError(f'{key} muss yes oder no sein')
    return normalized == 'yes'


def ipv4_section(values: dict[str, str], prefix: str, metric: int) -> list[str]:
    method = values[f'{prefix}_method'].lower()
    if method == 'dhcp':
        return ['[ipv4]', 'method=auto', f'route-metric={metric}', '', '[ipv6]', 'method=auto']
    if method != 'static':
        raise ValueError(f'{prefix}_method muss dhcp oder static sein')

    address = ipaddress.IPv4Interface(values[f'{prefix}_address'])
    gateway = ipaddress.IPv4Address(values[f'{prefix}_gateway'])
    dns_value = values[f'{prefix}_dns']
    dns = [str(ipaddress.ip_address(item.strip())) for item in dns_value.split(',') if item.strip()]
    if not dns:
        raise ValueError(f'{prefix}_dns benötigt bei static mindestens einen DNS-Server')
    return [
        '[ipv4]',
        'method=manual',
        f'address1={address},{gateway}',
        f'dns={";".join(dns)};',
        f'route-metric={metric}',
        '',
        '[ipv6]',
        'method=auto',
    ]


def render_profiles(values: dict[str, str]) -> tuple[dict[str, str], str]:
    use_lan = enabled(values['lan_enabled'], 'lan_enabled')
    use_wifi = enabled(values['wifi_enabled'], 'wifi_enabled')
    if not use_lan and not use_wifi:
        raise ValueError('Mindestens LAN oder WLAN muss aktiviert sein')

    profiles: dict[str, str] = {}
    if use_lan:
        lines = [
            '[connection]', 'id=kiosk-lan', 'type=ethernet', 'autoconnect=true',
            'autoconnect-priority=100', '', '[ethernet]', '',
        ]
        lines.extend(ipv4_section(values, 'lan', 100))
        profiles['kiosk-lan.nmconnection'] = '\n'.join(lines) + '\n'

    country = values['wifi_country'].upper()
    if not re.fullmatch(r'[A-Z]{2}', country):
        raise ValueError('wifi_country muss ein zweistelliger ISO-Ländercode sein')
    if use_wifi:
        ssid = values['wifi_ssid']
        password = values['wifi_password']
        if not 1 <= len(ssid.encode()) <= 32:
            raise ValueError('wifi_ssid muss 1 bis 32 Byte lang sein')
        if password and not (8 <= len(password) <= 63 or re.fullmatch(r'[0-9A-Fa-f]{64}', password)):
            raise ValueError('wifi_password muss leer, 8–63 Zeichen oder 64 Hex-Zeichen lang sein')
        lines = [
            '[connection]', 'id=kiosk-wifi', 'type=wifi', 'autoconnect=true',
            'autoconnect-priority=50', '', '[wifi]', 'mode=infrastructure', f'ssid={ssid}',
        ]
        if password:
            lines.extend(['', '[wifi-security]', 'key-mgmt=wpa-psk', f'psk={password}'])
        lines.append('')
        lines.extend(ipv4_section(values, 'wifi', 200))
        profiles['kiosk-wifi.nmconnection'] = '\n'.join(lines) + '\n'
    return profiles, country


def atomic_write(path: Path, content: str, mode: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f'.{path.name}.', dir=path.parent)
    try:
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(content)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def main() -> None:
    boot_root = Path(os.environ.get('DISAG_BOOT_ROOT', '/boot'))
    source = next((path for path in (boot_root / 'firmware/network.txt', boot_root / 'network.txt') if path.exists()), None)
    if source is None:
        raise SystemExit('network.txt wurde auf der Bootpartition nicht gefunden')
    try:
        profiles, country = render_profiles(read_config(source))
    except ValueError as error:
        raise SystemExit(f'Fehler in {source}: {error}') from error

    connection_dir = Path(os.environ.get('DISAG_NM_CONNECTION_DIR', '/etc/NetworkManager/system-connections'))
    for name in ('kiosk-lan.nmconnection', 'kiosk-wifi.nmconnection'):
        (connection_dir / name).unlink(missing_ok=True)
    for name, content in profiles.items():
        atomic_write(connection_dir / name, content, 0o600)

    crda = Path(os.environ.get('DISAG_CRDA_PATH', '/etc/default/crda'))
    atomic_write(crda, f'REGDOMAIN={country}\n', 0o644)
    print(f'Netzwerkprofile aus {source} aktualisiert: {", ".join(profiles)}')


if __name__ == '__main__':
    main()
