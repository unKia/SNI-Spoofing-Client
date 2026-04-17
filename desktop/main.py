from __future__ import annotations

import sys

from PySide6.QtCore import QTimer, Qt
from PySide6.QtGui import QColor, QFont, QPalette
from PySide6.QtWidgets import (
    QApplication,
    QComboBox,
    QFormLayout,
    QFrame,
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QPushButton,
    QPlainTextEdit,
    QVBoxLayout,
    QWidget,
)

from backends import available_backend_names
from core.config import AppConfig
from core.runtime import AppRuntime, RuntimeState


APP_STYLESHEET = """
QWidget {
    background: #0d1117;
    color: #e6edf3;
    font-family: Segoe UI, Inter, Arial, sans-serif;
    font-size: 13px;
}
QMainWindow {
    background: #0d1117;
}
QFrame#Panel {
    background: #111826;
    border: 1px solid #273142;
    border-radius: 16px;
}
QLabel#Title {
    font-size: 24px;
    font-weight: 700;
}
QLabel#Subtitle {
    color: #9fb0c3;
}
QLabel#Section {
    font-size: 14px;
    font-weight: 600;
    color: #d7e1ea;
}
QLabel#StatusDot {
    min-width: 12px;
    min-height: 12px;
    max-width: 12px;
    max-height: 12px;
    border-radius: 6px;
    background: #57606a;
}
QLineEdit, QComboBox, QPlainTextEdit {
    background: #0b1220;
    border: 1px solid #2a3443;
    border-radius: 10px;
    padding: 8px 10px;
    selection-background-color: #4aa3ff;
}
QPlainTextEdit {
    padding: 10px;
}
QPushButton {
    background: #1b2433;
    border: 1px solid #334155;
    border-radius: 10px;
    padding: 8px 14px;
    min-height: 18px;
}
QPushButton:hover {
    background: #253146;
}
QPushButton:pressed {
    background: #0f1724;
}
QPushButton#Primary {
    background: #2d6cdf;
    border: 1px solid #2d6cdf;
    color: white;
    font-weight: 600;
}
QPushButton#Primary:hover {
    background: #3d79e8;
}
QPushButton#Danger {
    background: #4a1f2b;
    border: 1px solid #7a3043;
    color: #ffdce4;
}
"""


class MainWindow(QMainWindow):
    def __init__(self, runtime: AppRuntime) -> None:
        super().__init__()
        self.runtime = runtime
        self.setWindowTitle("SNI Spoofing Client")
        self.setMinimumSize(980, 680)

        central = QWidget(self)
        self.setCentralWidget(central)

        root_layout = QVBoxLayout(central)
        root_layout.setContentsMargins(24, 24, 24, 24)
        root_layout.setSpacing(16)

        header = QFrame()
        header.setObjectName("Panel")
        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(22, 20, 22, 20)
        title = QLabel("SNI Spoofing Client")
        title.setObjectName("Title")
        subtitle = QLabel("Windows-first shell with a shared UI model for Windows, Linux, and macOS.")
        subtitle.setObjectName("Subtitle")
        subtitle.setWordWrap(True)
        header_layout.addWidget(title)
        header_layout.addWidget(subtitle)
        root_layout.addWidget(header)

        status_row = QFrame()
        status_row.setObjectName("Panel")
        status_layout = QHBoxLayout(status_row)
        status_layout.setContentsMargins(18, 14, 18, 14)
        status_layout.setSpacing(12)
        self.status_dot = QLabel()
        self.status_dot.setObjectName("StatusDot")
        self.status_text = QLabel("Ready")
        self.status_text.setObjectName("Section")
        self.status_detail = QLabel("")
        self.status_detail.setStyleSheet("color: #9fb0c3;")
        status_layout.addWidget(self.status_dot)
        status_layout.addWidget(self.status_text)
        status_layout.addStretch(1)
        status_layout.addWidget(self.status_detail)
        root_layout.addWidget(status_row)

        body = QGridLayout()
        body.setHorizontalSpacing(16)
        body.setVerticalSpacing(16)
        root_layout.addLayout(body, 1)

        config_panel = QFrame()
        config_panel.setObjectName("Panel")
        config_layout = QVBoxLayout(config_panel)
        config_layout.setContentsMargins(20, 18, 20, 20)
        config_layout.setSpacing(14)

        config_title = QLabel("Connection Profile")
        config_title.setObjectName("Section")
        config_layout.addWidget(config_title)

        form = QFormLayout()
        form.setLabelAlignment(Qt.AlignmentFlag.AlignLeft)
        form.setFormAlignment(Qt.AlignmentFlag.AlignTop)
        form.setVerticalSpacing(12)

        self.listen_host = QLineEdit()
        self.listen_port = QLineEdit()
        self.connect_ip = QLineEdit()
        self.connect_port = QLineEdit()
        self.fake_sni = QLineEdit()
        self.log_level = QComboBox()
        self.log_level.addItems(["debug", "info", "error"])
        self.backend = QComboBox()
        backend_names = available_backend_names()
        self._backend_supported = bool(backend_names)
        if backend_names:
            self.backend.addItems(backend_names)
        else:
            self.backend.addItem("unsupported")

        form.addRow("Listen host", self.listen_host)
        form.addRow("Listen port", self.listen_port)
        form.addRow("Connect IP", self.connect_ip)
        form.addRow("Connect port", self.connect_port)
        form.addRow("Fake SNI", self.fake_sni)
        form.addRow("Log level", self.log_level)
        form.addRow("Backend", self.backend)
        config_layout.addLayout(form)

        button_row = QHBoxLayout()
        self.save_button = QPushButton("Save")
        self.save_button.clicked.connect(self.on_save)
        self.start_button = QPushButton("Start")
        self.start_button.setObjectName("Primary")
        self.start_button.clicked.connect(self.on_start)
        self.stop_button = QPushButton("Stop")
        self.stop_button.setObjectName("Danger")
        self.stop_button.clicked.connect(self.on_stop)
        button_row.addWidget(self.save_button)
        button_row.addWidget(self.start_button)
        button_row.addWidget(self.stop_button)
        button_row.addStretch(1)
        config_layout.addLayout(button_row)

        self.hint = QLabel(
            "UI and config are intentionally platform-neutral. Only capture/inject backend should differ by OS."
        )
        self.hint.setStyleSheet("color: #9fb0c3;")
        self.hint.setWordWrap(True)
        config_layout.addWidget(self.hint)

        logs_panel = QFrame()
        logs_panel.setObjectName("Panel")
        logs_layout = QVBoxLayout(logs_panel)
        logs_layout.setContentsMargins(20, 18, 20, 20)
        logs_layout.setSpacing(12)
        logs_title = QLabel("Runtime Log")
        logs_title.setObjectName("Section")
        logs_layout.addWidget(logs_title)
        self.logs = QPlainTextEdit()
        self.logs.setReadOnly(True)
        self.logs.setPlaceholderText("Runtime events will appear here.")
        logs_layout.addWidget(self.logs)

        body.addWidget(config_panel, 0, 0)
        body.addWidget(logs_panel, 0, 1)
        body.setColumnStretch(0, 1)
        body.setColumnStretch(1, 1)

        self.timer = QTimer(self)
        self.timer.setInterval(150)
        self.timer.timeout.connect(self.poll_runtime)
        self.timer.start()

        self.load_config_to_form()
        self.refresh_ui_state()

    def load_config_to_form(self) -> None:
        config = self.runtime.config
        self.listen_host.setText(config.listen_host)
        self.listen_port.setText(str(config.listen_port))
        self.connect_ip.setText(config.connect_ip)
        self.connect_port.setText(str(config.connect_port))
        self.fake_sni.setText(config.fake_sni)
        self.log_level.setCurrentText(config.log_level)
        self.backend.setCurrentText(config.selected_backend())

    def form_to_config(self) -> AppConfig:
        return self.runtime.config.updated(
            listen_host=self.listen_host.text().strip(),
            listen_port=int(self.listen_port.text().strip()),
            connect_ip=self.connect_ip.text().strip(),
            connect_port=int(self.connect_port.text().strip()),
            fake_sni=self.fake_sni.text().strip(),
            log_level=self.log_level.currentText().strip(),
            backend=self.backend.currentText().strip(),
        )

    def append_log(self, message: str) -> None:
        self.logs.appendPlainText(message)

    def set_status(self, state: RuntimeState, message: str) -> None:
        self.status_text.setText(state.value.capitalize())
        self.status_detail.setText(message)
        palette = {
            RuntimeState.STOPPED: "#57606a",
            RuntimeState.STARTING: "#d4a72c",
            RuntimeState.RUNNING: "#2ea043",
            RuntimeState.STOPPING: "#d4a72c",
            RuntimeState.ERROR: "#f85149",
        }
        self.status_dot.setStyleSheet(
            f"min-width: 12px; min-height: 12px; max-width: 12px; max-height: 12px; border-radius: 6px; background: {palette[state]};"
        )

    def refresh_ui_state(self) -> None:
        self.set_status(self.runtime.state, self.runtime.state_message)
        running = self.runtime.state in (RuntimeState.STARTING, RuntimeState.RUNNING, RuntimeState.STOPPING)
        self.start_button.setEnabled((not running) and self._backend_supported)
        self.stop_button.setEnabled(running)

    def poll_runtime(self) -> None:
        for event in self.runtime.drain_events():
            if event.level == "error":
                self.append_log(f"[ERROR] {event.message}")
            elif event.level == "state":
                self.append_log(f"[STATE] {event.message}")
            else:
                self.append_log(f"[{event.level.upper()}] {event.message}")
        self.refresh_ui_state()

    def on_save(self) -> bool:
        try:
            config = self.form_to_config()
        except ValueError:
            self.append_log("[ERROR] Invalid numeric value in port fields.")
            return False
        try:
            self.runtime.save_config(config)
        except Exception as exc:
            self.append_log(f"[ERROR] {type(exc).__name__}: {exc}")
            return False
        self.load_config_to_form()
        self.append_log("[INFO] Configuration saved.")
        return True

    def on_start(self) -> None:
        if not self.on_save():
            return
        self.runtime.start()
        self.append_log("[INFO] Start requested.")

    def on_stop(self) -> None:
        self.runtime.stop()
        self.append_log("[INFO] Stop requested.")

    def closeEvent(self, event) -> None:  # noqa: N802
        self.runtime.stop()
        super().closeEvent(event)


def _configure_application(app: QApplication) -> None:
    app.setStyle("Fusion")
    palette = QPalette()
    palette.setColor(QPalette.ColorRole.Window, QColor("#0d1117"))
    palette.setColor(QPalette.ColorRole.WindowText, QColor("#e6edf3"))
    palette.setColor(QPalette.ColorRole.Base, QColor("#0b1220"))
    palette.setColor(QPalette.ColorRole.AlternateBase, QColor("#111826"))
    palette.setColor(QPalette.ColorRole.ToolTipBase, QColor("#e6edf3"))
    palette.setColor(QPalette.ColorRole.ToolTipText, QColor("#0d1117"))
    palette.setColor(QPalette.ColorRole.Text, QColor("#e6edf3"))
    palette.setColor(QPalette.ColorRole.Button, QColor("#1b2433"))
    palette.setColor(QPalette.ColorRole.ButtonText, QColor("#e6edf3"))
    palette.setColor(QPalette.ColorRole.Highlight, QColor("#2d6cdf"))
    palette.setColor(QPalette.ColorRole.HighlightedText, QColor("#ffffff"))
    app.setPalette(palette)
    app.setFont(QFont("Segoe UI", 10))


def main(config_path: str | None = None) -> int:
    app = QApplication(sys.argv)
    _configure_application(app)
    app.setStyleSheet(APP_STYLESHEET)
    runtime = AppRuntime(config_path)
    window = MainWindow(runtime)
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
