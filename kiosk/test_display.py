import importlib.util
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location('display', Path(__file__).with_name('display.py'))
display = importlib.util.module_from_spec(spec)
spec.loader.exec_module(display)

QUERY = '''Screen 0: minimum 320 x 200, current 1920 x 1080, maximum 7680 x 7680
HDMI-1 connected primary 1920x1080+0+0
   1920x1080     60.00*+
HDMI-2 connected
   1920x1080     60.00 +
   1280x720      60.00
'''

class DisplayTests(unittest.TestCase):
    def configure(self, query, edid_port=None):
        entries = []
        if edid_port:
            edid = Mock()
            edid.parent.name = f'card1-HDMI-A-{edid_port}'
            edid.read_bytes.return_value = b'valid-edid'
            entries = [edid]
        with patch.object(display.subprocess, 'check_output', return_value=query), \
             patch.object(display.subprocess, 'run') as run, \
             patch.object(display, 'Path') as paths:
            paths.return_value.glob.return_value = entries
            display.configure()
            return run

    def test_late_tv_on_second_port_wins_over_forced_first_port(self):
        run = self.configure(QUERY, '2')
        run.assert_called_once_with(['xrandr', '--output', 'HDMI-2', '--primary', '--pos', '0x0', '--auto', '--output', 'HDMI-1', '--off'], check=True, timeout=15)

    def test_headless_uses_first_fallback(self):
        run = self.configure(QUERY)
        self.assertEqual(run.call_args.args[0][2], 'HDMI-1')

    def test_720p_only_tv_uses_its_preferred_mode(self):
        run = self.configure(QUERY.replace('   1920x1080     60.00 +\n', ''), '2')
        self.assertIn('--auto', run.call_args.args[0])

    def test_no_outputs_does_not_issue_invalid_command(self):
        self.configure('HDMI-1 disconnected\n').assert_not_called()

if __name__ == '__main__':
    unittest.main()
