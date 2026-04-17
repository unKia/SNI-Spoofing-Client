from __future__ import annotations

import asyncio
from dataclasses import dataclass
from enum import Enum
import queue
import threading
import time
from typing import Iterable

from backends import build_backend
from core.config import AppConfig
from core.server import SniSpoofingServer


class RuntimeState(str, Enum):
    STOPPED = "stopped"
    STARTING = "starting"
    RUNNING = "running"
    STOPPING = "stopping"
    ERROR = "error"


@dataclass(frozen=True)
class RuntimeEvent:
    timestamp: float
    level: str
    message: str


class AppRuntime:
    def __init__(self, config_path: str | None = None) -> None:
        self._config_path = config_path
        self._config = AppConfig.load(config_path)
        self._state = RuntimeState.STOPPED
        self._state_message = "Ready"
        self._events: queue.Queue[RuntimeEvent] = queue.Queue()
        self._lock = threading.RLock()
        self._thread: threading.Thread | None = None
        self._loop: asyncio.AbstractEventLoop | None = None
        self._task: asyncio.Task | None = None
        self._server: SniSpoofingServer | None = None
        self._backend = None

    @property
    def config(self) -> AppConfig:
        return self._config

    @property
    def state(self) -> RuntimeState:
        return self._state

    @property
    def state_message(self) -> str:
        return self._state_message

    def reload_config(self) -> AppConfig:
        self._config = AppConfig.load(self._config_path)
        return self._config

    def save_config(self, config: AppConfig | None = None) -> None:
        (config or self._config).save(self._config_path)
        self._config = config or self._config

    def update_config(self, **changes) -> AppConfig:
        self._config = self._config.updated(**changes)
        return self._config

    def drain_events(self) -> list[RuntimeEvent]:
        events: list[RuntimeEvent] = []
        while True:
            try:
                events.append(self._events.get_nowait())
            except queue.Empty:
                return events

    def _emit(self, level: str, message: str) -> None:
        self._events.put(RuntimeEvent(time.time(), level, message))

    def _set_state(self, state: RuntimeState, message: str) -> None:
        self._state = state
        self._state_message = message
        self._emit("state", f"{state.value}: {message}")

    def start(self) -> None:
        with self._lock:
            if self._thread is not None and self._thread.is_alive():
                return

            try:
                self.reload_config()
                backend = build_backend(self._config.selected_backend())
                server = SniSpoofingServer(self._config, backend)
            except Exception as exc:
                self._backend = None
                self._server = None
                self._set_state(RuntimeState.ERROR, f"{type(exc).__name__}: {exc}")
                self._emit("error", f"{type(exc).__name__}: {exc}")
                return

            self._backend = backend
            self._server = server
            self._set_state(
                RuntimeState.STARTING,
                f"Starting {backend.name} on {self._config.listen_host}:{self._config.listen_port}",
            )
            self._thread = threading.Thread(target=self._run_server, name="SNI Runtime", daemon=True)
            self._thread.start()

    def _run_server(self) -> None:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        self._loop = loop
        assert self._server is not None
        task = loop.create_task(self._server.serve_forever())
        self._task = task
        self._set_state(RuntimeState.RUNNING, "Backend is active")
        self._emit("info", f"backend={self._config.selected_backend()}")
        try:
            loop.run_until_complete(task)
        except asyncio.CancelledError:
            pass
        except Exception as exc:  # pragma: no cover - runtime surface
            self._set_state(RuntimeState.ERROR, f"{type(exc).__name__}: {exc}")
            self._emit("error", f"{type(exc).__name__}: {exc}")
        finally:
            pending: Iterable[asyncio.Task] = [t for t in asyncio.all_tasks(loop) if not t.done()]
            for pending_task in pending:
                pending_task.cancel()
            if pending:
                loop.run_until_complete(asyncio.gather(*pending, return_exceptions=True))
            loop.run_until_complete(loop.shutdown_asyncgens())
            loop.close()
            with self._lock:
                self._loop = None
                self._task = None
                self._server = None
                self._backend = None
                self._thread = None
                if self._state != RuntimeState.ERROR:
                    self._set_state(RuntimeState.STOPPED, "Ready")

    def stop(self) -> None:
        with self._lock:
            if self._thread is None or not self._thread.is_alive():
                self._set_state(RuntimeState.STOPPED, "Ready")
                return

            self._set_state(RuntimeState.STOPPING, "Stopping backend")
            if self._server is not None:
                self._server.close()
            if self._loop is not None and self._task is not None:
                self._loop.call_soon_threadsafe(self._task.cancel)

        thread = self._thread
        if thread is not None:
            thread.join(timeout=5)
            if thread.is_alive():
                self._emit("error", "Runtime stop timed out")
                self._set_state(RuntimeState.ERROR, "Stop timed out")
