from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from backends import available_backend_names
from core.config import AppConfig


class AppConfigTests(unittest.TestCase):
    def test_save_and_load_roundtrip_preserves_log_level_and_backend(self) -> None:
        config = AppConfig(
            listen_host="127.0.0.1",
            listen_port=40444,
            connect_ip="1.1.1.1",
            connect_port=443,
            fake_sni="example.com",
            log_level="info",
            backend="windows-pydivert",
        )

        with tempfile.TemporaryDirectory() as temp_dir:
            path = f"{temp_dir}/config.json"
            config.save(path)
            loaded = AppConfig.load(path)

        self.assertEqual(loaded.listen_host, config.listen_host)
        self.assertEqual(loaded.listen_port, config.listen_port)
        self.assertEqual(loaded.connect_ip, config.connect_ip)
        self.assertEqual(loaded.connect_port, config.connect_port)
        self.assertEqual(loaded.fake_sni, config.fake_sni)
        self.assertEqual(loaded.log_level, config.log_level)
        self.assertEqual(loaded.backend, config.backend)

    def test_load_creates_default_config_when_missing(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing.json"
            loaded = AppConfig.load(str(path))

            self.assertTrue(path.exists())
            self.assertEqual(loaded, AppConfig.default())

    def test_load_repairs_corrupted_config_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "broken.json"
            path.write_text("{not-json", encoding="utf-8")

            loaded = AppConfig.load(str(path))

            self.assertEqual(loaded, AppConfig.default())
            self.assertTrue(path.exists())
            self.assertTrue(Path(f"{path}.broken").exists())

    def test_selected_backend_uses_platform_default_when_config_backend_missing(self) -> None:
        base = AppConfig(
            listen_host="0.0.0.0",
            listen_port=40444,
            connect_ip="1.1.1.1",
            connect_port=443,
            fake_sni="example.com",
        )

        with patch("core.config.sys.platform", "win32"):
            self.assertEqual(base.selected_backend(), "windows-pydivert")

        with patch("core.config.sys.platform", "darwin"):
            self.assertEqual(base.selected_backend(), "macos-network-extension")

    def test_selected_backend_normalizes_mismatched_backend_for_current_platform(self) -> None:
        base = AppConfig(
            listen_host="0.0.0.0",
            listen_port=40444,
            connect_ip="1.1.1.1",
            connect_port=443,
            fake_sni="example.com",
            backend="macos-network-extension",
        )

        with patch("core.config.sys.platform", "win32"):
            self.assertEqual(base.selected_backend(), "windows-pydivert")

        with patch("core.config.sys.platform", "darwin"):
            self.assertEqual(base.selected_backend(), "macos-network-extension")


class BackendAvailabilityTests(unittest.TestCase):
    def test_available_backend_names_returns_list(self) -> None:
        self.assertIsInstance(available_backend_names(), list)


if __name__ == "__main__":
    unittest.main()
