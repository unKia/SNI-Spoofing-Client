from __future__ import annotations

import socket

from .base import ActiveBypassConnection, BypassBackend


class MacOSNetworkExtensionBackend(BypassBackend):
    name = "macos-network-extension"

    def start(self, interface_ipv4: str, connect_ip: str) -> None:
        raise NotImplementedError(
            "backend e macOS hanooz bayad ba Network Extension e dakhele پوشه macos-arm vasl beshe."
        )

    def stop(self) -> None:
        return

    def register_connection(
        self,
        outgoing_sock: socket.socket,
        interface_ipv4: str,
        connect_ip: str,
        src_port: int,
        connect_port: int,
        fake_data: bytes,
        incoming_sock: socket.socket,
    ) -> ActiveBypassConnection:
        raise NotImplementedError("backend e macOS hanooz implement نشده.")

    def unregister_connection(self, connection: ActiveBypassConnection) -> None:
        return
