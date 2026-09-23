#!/usr/bin/python3
import importlib.util
from pathlib import Path
import tempfile

spec = importlib.util.spec_from_file_location('disag_network', Path(__file__).with_name('network.py'))
module = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(module)


def values(**changes):
    data = {
        'lan_enabled': 'yes', 'lan_method': 'dhcp', 'lan_address': '',
        'lan_gateway': '', 'lan_dns': '', 'wifi_enabled': 'no',
        'wifi_ssid': 'Test WLAN', 'wifi_password': 'testpasswort',
        'wifi_country': 'DE', 'wifi_method': 'dhcp', 'wifi_address': '',
        'wifi_gateway': '', 'wifi_dns': '',
    }
    data.update(changes)
    return data


lan, country = module.render_profiles(values())
assert set(lan) == {'kiosk-lan.nmconnection'} and country == 'DE'

both, _ = module.render_profiles(values(
    wifi_enabled='yes', lan_method='static', lan_address='192.168.10.20/24',
    lan_gateway='192.168.10.1', lan_dns='1.1.1.1, 9.9.9.9'))
assert set(both) == {'kiosk-lan.nmconnection', 'kiosk-wifi.nmconnection'}
assert 'address1=192.168.10.20/24,192.168.10.1' in both['kiosk-lan.nmconnection']
assert 'psk=testpasswort' in both['kiosk-wifi.nmconnection']

wifi, _ = module.render_profiles(values(lan_enabled='no', wifi_enabled='yes', wifi_password=''))
assert set(wifi) == {'kiosk-wifi.nmconnection'}
assert '[wifi-security]' not in wifi['kiosk-wifi.nmconnection']

for bad in (
    values(lan_enabled='no'),
    values(lan_method='static', lan_address='invalid', lan_gateway='192.168.1.1', lan_dns='1.1.1.1'),
    values(wifi_enabled='yes', wifi_password='short'),
):
    try:
        module.render_profiles(bad)
    except ValueError:
        pass
    else:
        raise AssertionError('Invalid configuration accepted')

with tempfile.TemporaryDirectory() as directory:
    config = Path(directory, 'network.txt')
    config.write_text('\ufeff# test\n' + '\n'.join(f'{key}={value}' for key, value in values().items()) + '\n')
    assert module.read_config(config)['lan_enabled'] == 'yes'

print('network configuration tests passed')
