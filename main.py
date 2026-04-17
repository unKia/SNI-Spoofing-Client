from __future__ import annotations

import asyncio
import argparse
import traceback
import sys

from backends import build_backend
from core.config import AppConfig
from core.server import SniSpoofingServer


def run_headless(config_path: str | None = None) -> None:
    config = AppConfig.load(config_path)
    backend = build_backend(config.selected_backend())
    server = SniSpoofingServer(config, backend)
    asyncio.run(server.serve_forever())


def run_desktop(config_path: str | None = None) -> None:
    from desktop.main import main as desktop_main

    desktop_main(config_path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="SNI Spoofing Client")
    parser.add_argument(
        "--config",
        dest="config_path",
        default=None,
        help="Path to config.json. Defaults to the app root config file.",
    )
    parser.add_argument(
        "--headless",
        action="store_true",
        help="Run the backend without the desktop UI.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if sys.platform == "win32" and not args.headless:
        run_desktop(args.config_path)
        return

    run_headless(args.config_path)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        raise
