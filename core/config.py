from __future__ import annotations

from dataclasses import dataclass
import json
import os
import sys
from dataclasses import replace


def get_app_root() -> str:
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def get_user_data_root() -> str:
    if sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA") or os.environ.get("APPDATA") or os.path.expanduser("~")
        return os.path.join(base, "SNI-Spoofing")
    if sys.platform == "darwin":
        return os.path.join(os.path.expanduser("~/Library/Application Support"), "SNI-Spoofing")
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    return os.path.join(base, "SNI-Spoofing")


def get_default_config_path() -> str:
    return os.path.join(get_user_data_root(), "config.json")


@dataclass(frozen=True)
class AppConfig:
    listen_host: str
    listen_port: int
    connect_ip: str
    connect_port: int
    fake_sni: str
    log_level: str = "error"
    backend: str | None = None

    @classmethod
    def default(cls) -> "AppConfig":
        return cls(
            listen_host="0.0.0.0",
            listen_port=40444,
            connect_ip="104.19.229.21",
            connect_port=443,
            fake_sni="hcaptcha.com",
            log_level="error",
            backend=None,
        )

    @classmethod
    def load(cls, config_path: str | None = None) -> "AppConfig":
        path = config_path or get_default_config_path()
        if not os.path.exists(path):
            config = cls.default()
            config.save(path)
            return config
        try:
            with open(path, "r", encoding="utf-8") as file_obj:
                raw = json.load(file_obj)
            return cls(
                listen_host=raw["LISTEN_HOST"],
                listen_port=raw["LISTEN_PORT"],
                connect_ip=raw["CONNECT_IP"],
                connect_port=raw["CONNECT_PORT"],
                fake_sni=raw["FAKE_SNI"],
                log_level=raw.get("LOG_LEVEL", "error"),
                backend=raw.get("BACKEND"),
            )
        except (json.JSONDecodeError, KeyError, TypeError, OSError):
            broken_path = f"{path}.broken"
            try:
                if os.path.exists(path):
                    os.replace(path, broken_path)
            except OSError:
                pass
            config = cls.default()
            config.save(path)
            return config

    def to_dict(self) -> dict[str, object]:
        return {
            "LISTEN_HOST": self.listen_host,
            "LISTEN_PORT": self.listen_port,
            "CONNECT_IP": self.connect_ip,
            "CONNECT_PORT": self.connect_port,
            "FAKE_SNI": self.fake_sni,
            "LOG_LEVEL": self.log_level,
            "BACKEND": self.backend,
        }

    def save(self, config_path: str | None = None) -> None:
        path = config_path or get_default_config_path()
        directory = os.path.dirname(path)
        if directory:
            os.makedirs(directory, exist_ok=True)
        with open(path, "w", encoding="utf-8") as file_obj:
            json.dump(self.to_dict(), file_obj, indent=2, ensure_ascii=False)
            file_obj.write("\n")

    def updated(self, **changes) -> "AppConfig":
        return replace(self, **changes)

    def selected_backend(self) -> str:
        if sys.platform == "win32":
            return self.backend if self.backend == "windows-pydivert" else "windows-pydivert"
        if sys.platform == "darwin":
            return self.backend if self.backend == "macos-network-extension" else "macos-network-extension"
        return "unsupported"
