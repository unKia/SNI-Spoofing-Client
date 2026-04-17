import sys

from .base import BypassBackend
from .macos_network_extension import MacOSNetworkExtensionBackend
from .windows_pydivert import WindowsPyDivertBackend


def build_backend(backend_name: str) -> BypassBackend:
    if backend_name == WindowsPyDivertBackend.name:
        return WindowsPyDivertBackend()
    if backend_name == MacOSNetworkExtensionBackend.name:
        return MacOSNetworkExtensionBackend()
    raise ValueError(f"unsupported backend: {backend_name}")


def available_backend_names() -> list[str]:
    if sys.platform == "win32":
        return [WindowsPyDivertBackend.name]
    if sys.platform == "darwin":
        return [MacOSNetworkExtensionBackend.name]
    return []
