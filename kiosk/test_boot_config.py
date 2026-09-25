#!/usr/bin/env python3
"""Check the boot command line for the supported Pi display layouts."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name('boot-config.py')


class BootConfigTests(unittest.TestCase):
    def configure(self, target):
        with tempfile.TemporaryDirectory() as directory:
            boot = Path(directory)
            (boot / 'config.txt').write_text('arm_64bit=1\n')
            (boot / 'cmdline.txt').write_text('root=PARTUUID=abcd-02 video=HDMI-A-1:800x600@60\n')
            env = dict(os.environ, DISAG_BOOT_ROOT=directory, DISAG_TARGET=target)
            for _ in range(2):
                subprocess.run([sys.executable, str(SCRIPT)], env=env, check=True)
            return (boot / 'cmdline.txt').read_text().split()

    def test_pi4_enables_both_hdmi_ports_once(self):
        args = self.configure('raspberry-pi-4')
        self.assertEqual([arg for arg in args if arg.startswith('video=')], [
            'video=HDMI-A-1:1920x1080@60D',
            'video=HDMI-A-2:1920x1080@60D',
        ])

    def test_pi5_keeps_primary_hdmi_fallback(self):
        args = self.configure('raspberry-pi-5')
        self.assertEqual([arg for arg in args if arg.startswith('video=')], [
            'video=HDMI-A-1:1920x1080@60D',
        ])


if __name__ == '__main__':
    unittest.main()
