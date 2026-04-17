from __future__ import annotations

from abc import ABC, abstractmethod
import socket
from typing import Tuple


ConnectionId = Tuple[str, int, str, int]


class ActiveBypassConnection(ABC):
    @property
    @abstractmethod
    def id(self) -> ConnectionId:
        raise NotImplementedError

    @abstractmethod
    async def wait_until_ready(self, timeout: float) -> None:
        raise NotImplementedError


class BypassBackend(ABC):
    name = "base"

    @abstractmethod
    def start(self, interface_ipv4: str, connect_ip: str) -> None:
        raise NotImplementedError

    @abstractmethod
    def stop(self) -> None:
        raise NotImplementedError

    @abstractmethod
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
        raise NotImplementedError

    @abstractmethod
    def unregister_connection(self, connection: ActiveBypassConnection) -> None:
        raise NotImplementedError
