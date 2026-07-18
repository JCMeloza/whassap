"""Transfer engine for WhatsApp Transfer Tool.

Orchestrates the end-to-end transfer: scan source, pull data to
temp directory, push to destination, and clean up. Supports pause,
cancel, and package mapping between source and destination.
"""

import platform
import subprocess
import signal
from pathlib import Path
from backend.models import TransferConfig


def _map_packages(source_packages: list[str],
                  dest_packages: list[str]) -> tuple[dict[str, str], list[str]]:
    """Map source packages to destination packages.

    Pure function. Returns (mapping_dict, warning_messages).
    Only maps packages present on both devices. Generates warnings
    for source packages not found on destination.
    """
    mapping: dict[str, str] = {}
    warnings: list[str] = []
    for sp in source_packages:
        if sp in dest_packages:
            mapping[sp] = sp
        else:
            warnings.append(
                f"{sp} not installed on destination — will not be transferred"
            )
    return mapping, warnings


class TransferEngine:
    """Orchestrates end-to-end WhatsApp data transfer."""

    def __init__(self, adb_provider, scanner, temp_storage,
                 progress_reporter, device_service):
        self._adb = adb_provider
        self._scanner = scanner
        self._temp = temp_storage
        self._reporter = progress_reporter
        self._device = device_service
        self._process: subprocess.Popen | None = None
        self._transfer_id: str | None = None

    def start(self, config: TransferConfig) -> str:
        """Start a transfer: scan → pull → push → cleanup.

        Returns the transfer ID. Raises RuntimeError on failure.
        """
        self._transfer_id = _generate_transfer_id()
        tid = self._transfer_id

        # Phase: create temp dir
        self._temp.create(tid)

        # Phase: scan source
        self._reporter.emit_phase_change("", "scanning")
        src_props = self._device.get_properties(config.sourceSerial)
        src_api = src_props.get("apiLevel", 0)
        scan_results = self._scanner.scan_device(
            config.sourceSerial, config.packages, src_api,
        )
        if not scan_results:
            raise RuntimeError("No WhatsApp data found on source device")

        # Map packages
        dest_pkgs = self._device.detect_packages(config.destSerial)
        pkg_map, warnings = _map_packages(config.packages, dest_pkgs)
        _ = warnings  # Available for future UI warning emission

        # Create package dirs
        self._temp.ensure_package_dirs(config.packages)

        # Phase: pull
        self._reporter.emit_phase_change("scanning", "pull")
        self._run_transfer_phase(
            config.sourceSerial, src_api, config.items,
            config.packages, pull=True,
        )

        # Phase: push
        dest_props = self._device.get_properties(config.destSerial)
        dest_api = dest_props.get("apiLevel", 0)
        self._reporter.emit_phase_change("pull", "push")
        self._run_transfer_phase(
            config.destSerial, dest_api, config.items,
            config.packages, pull=False,
        )

        # Phase: complete
        self._reporter.emit_phase_change("push", "complete")
        self._temp.cleanup()
        return tid

    def _run_transfer_phase(self, serial: str, api_level: int,
                            items: list[str], packages: list[str],
                            pull: bool) -> None:
        """Run adb pull or push for all items across packages."""
        if self._temp.temp_dir is None:
            raise RuntimeError(
                "Temp directory not initialized — call create() before transfer phase"
            )
        temp_src = str(self._temp.temp_dir / "source")
        cmd = "pull" if pull else "push"
        for pkg in packages:
            for item in items:
                if pull:
                    src_path = self._resolve_source_path(pkg, item, api_level)
                    dest_path = f"{temp_src}/{pkg}/{item}"
                    Path(dest_path).parent.mkdir(parents=True, exist_ok=True)
                else:
                    src_path = f"{temp_src}/{pkg}/{item}"
                    dest_path = self._resolve_dest_path(pkg, item, api_level)
                    subprocess.run(
                        [self._adb.adb_path, "-s", serial, "shell",
                         "mkdir", "-p", str(Path(dest_path).parent)],
                        capture_output=True, timeout=10,
                    )
                self._run_adb_cmd(serial, cmd, src_path, dest_path, pkg, item)

    def _run_adb_cmd(self, serial: str, cmd: str, src: str, dest: str,
                     pkg: str, item: str) -> None:
        """Run an adb pull/push command and wait for completion."""
        try:
            self._process = subprocess.Popen(
                [self._adb.adb_path, "-s", serial, cmd, src, dest],
                stdout=subprocess.DEVNULL,
                text=True,
            )
            self._process.wait(timeout=600)
        except subprocess.TimeoutExpired:
            if self._process:
                self._process.kill()
            raise
        finally:
            if self._process and self._process.stderr:
                self._process.stderr.close()
            self._process = None

    def _resolve_source_path(self, pkg: str, item: str,
                              api_level: int) -> str:
        """Resolve source path for an item based on API level."""
        from backend.scanner_service import _PATHS as paths
        base = paths[pkg]["db_scoped" if api_level >= 30 else "db_legacy"]
        if item.startswith("Media/"):
            base = paths[pkg]["media_scoped" if api_level >= 30 else "media_legacy"]
        return base + item.split("/", 1)[-1] if "/" in item else base + item

    def _resolve_dest_path(self, pkg: str, item: str,
                            api_level: int) -> str:
        """Resolve destination path based on device API level."""
        from backend.scanner_service import _PATHS as paths
        base = paths[pkg]["db_scoped" if api_level >= 30 else "db_legacy"]
        if item.startswith("Media/"):
            base = paths[pkg]["media_scoped" if api_level >= 30 else "media_legacy"]
        return base + item.split("/", 1)[-1] if "/" in item else base + item

    def pause(self, transfer_id: str) -> None:
        """Pause a running transfer by sending SIGINT to ADB process."""
        if self._process is not None and self._process.poll() is None:
            if platform.system() == "Windows":
                try:
                    self._process.send_signal(signal.CTRL_C_EVENT)  # type: ignore[attr-defined]
                except AttributeError:
                    self._process.kill()
            else:
                self._process.send_signal(signal.SIGINT)

    def cancel(self, transfer_id: str) -> None:
        """Cancel a transfer: kill process and clean up temp dir."""
        if self._process is not None and self._process.poll() is None:
            self._process.kill()
        self._temp.cleanup()
        self._process = None


def _generate_transfer_id() -> str:
    """Generate a unique transfer ID."""
    from uuid import uuid4
    return str(uuid4())
