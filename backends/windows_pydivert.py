from __future__ import annotations

import socket
import threading

from .base import ActiveBypassConnection, BypassBackend
from fake_tcp import FakeInjectiveConnection, FakeTcpInjector


class WindowsPyDivertBackend(BypassBackend):
    name = "windows-pydivert"

    def __init__(self) -> None:
        self.connections: dict[tuple, FakeInjectiveConnection] = {}
        self._injector: FakeTcpInjector | None = None
        self._thread: threading.Thread | None = None
        self._started = False

    def start(self, interface_ipv4: str, connect_ip: str) -> None:
        if self._started:
            return
        self.connections.clear()
        w_filter = (
            "tcp and "
            + "("
            + "(ip.SrcAddr == "
            + interface_ipv4
            + " and ip.DstAddr == "
            + connect_ip
            + ")"
            + " or "
            + "(ip.SrcAddr == "
            + connect_ip
            + " and ip.DstAddr == "
            + interface_ipv4
            + ")"
            + ")"
        )
        self._injector = FakeTcpInjector(w_filter, self.connections)
        self._thread = threading.Thread(target=self._injector.run, args=(), daemon=True)
        self._thread.start()
        self._started = True

    def stop(self) -> None:
        if self._injector is None:
            return
        try:
            self._injector.w.close()
        except Exception:
            pass
        if self._thread is not None and self._thread.is_alive():
            self._thread.join(timeout=2)
        self._injector = None
        self._thread = None
        self.connections.clear()
        self._started = False

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
        connection = FakeInjectiveConnection(
            outgoing_sock,
            interface_ipv4,
            connect_ip,
            src_port,
            connect_port,
            fake_data,
            "wrong_seq",
            incoming_sock,
        )
        self.connections[connection.id] = connection
        return connection

    def unregister_connection(self, connection: ActiveBypassConnection) -> None:
        if not isinstance(connection, FakeInjectiveConnection):
            return
        connection.monitor = False
        self.connections.pop(connection.id, None)
