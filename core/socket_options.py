from __future__ import annotations

import socket
import sys


def _safe_setsockopt(sock: socket.socket, level: int, name: int, value: int) -> None:
    try:
        sock.setsockopt(level, name, value)
    except (AttributeError, OSError):
        return


def configure_keepalive(sock: socket.socket) -> None:
    _safe_setsockopt(sock, socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)

    if sys.platform == "darwin":
        keepalive_name = getattr(socket, "TCP_KEEPALIVE", None)
        if keepalive_name is not None:
            _safe_setsockopt(sock, socket.IPPROTO_TCP, keepalive_name, 11)
        return

    idle_name = getattr(socket, "TCP_KEEPIDLE", None)
    intvl_name = getattr(socket, "TCP_KEEPINTVL", None)
    cnt_name = getattr(socket, "TCP_KEEPCNT", None)
    if idle_name is not None:
        _safe_setsockopt(sock, socket.IPPROTO_TCP, idle_name, 11)
    if intvl_name is not None:
        _safe_setsockopt(sock, socket.IPPROTO_TCP, intvl_name, 2)
    if cnt_name is not None:
        _safe_setsockopt(sock, socket.IPPROTO_TCP, cnt_name, 3)
