from __future__ import annotations

import unittest
from unittest.mock import patch

import main as launcher


class LauncherTests(unittest.TestCase):
    def test_windows_defaults_to_desktop(self) -> None:
        with patch.object(launcher.sys, "platform", "win32"), patch.object(
            launcher, "run_desktop"
        ) as run_desktop, patch.object(launcher, "run_headless") as run_headless, patch.object(
            launcher, "parse_args"
        ) as parse_args:
            parse_args.return_value = type("Args", (), {"config_path": None, "headless": False})()

            launcher.main()

            run_desktop.assert_called_once_with(None)
            run_headless.assert_not_called()

    def test_headless_forces_server_mode(self) -> None:
        with patch.object(launcher.sys, "platform", "win32"), patch.object(
            launcher, "run_desktop"
        ) as run_desktop, patch.object(launcher, "run_headless") as run_headless, patch.object(
            launcher, "parse_args"
        ) as parse_args:
            parse_args.return_value = type("Args", (), {"config_path": "custom.json", "headless": True})()

            launcher.main()

            run_headless.assert_called_once_with("custom.json")
            run_desktop.assert_not_called()


if __name__ == "__main__":
    unittest.main()
