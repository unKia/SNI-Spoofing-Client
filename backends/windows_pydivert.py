from __future__ import annotations

import importlib
import platform
import socket
import sys
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
        self._filter = ""
        self._interface_ipv4 = ""
        self._connect_ip = ""

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
        self._filter = w_filter
        self._interface_ipv4 = interface_ipv4
        self._connect_ip = connect_ip
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

    def diagnostic_summary(self) -> str:
        pydivert_version = "-"
        pydivert_path = "-"
        windivert_path = "-"
        try:
            pydivert = importlib.import_module("pydivert")
            pydivert_version = getattr(pydivert, "__version__", "-")
            pydivert_path = getattr(pydivert, "__file__", "-")
        except Exception as exc:
            pydivert_path = f"unavailable:{type(exc).__name__}:{exc}"
        try:
            windivert_dll = importlib.import_module("pydivert.windivert_dll")
            windivert_path = getattr(windivert_dll, "__file__", "-")
        except Exception as exc:
            windivert_path = f"unavailable:{type(exc).__name__}:{exc}"
        return (
            f"name={self.name} started={self._started} interface={self._interface_ipv4 or '-'} "
            f"target={self._connect_ip or '-'} machine={platform.machine()} "
            f"python={platform.python_version()} bits={64 if sys.maxsize > 2**32 else 32} "
            f"pydivert={pydivert_version} pydivert_path={pydivert_path} "
            f"windivert_path={windivert_path} filter={self._filter or '-'}"
        )

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
