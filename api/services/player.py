import os
import re
import psutil
from typing import Dict
from datetime import datetime, timezone
from pathlib import Path
from ..core.config import SYSTEMCTL_CMD, PS_CMD, PLAYER_ROOT
from ..services.utils import run_command
from ..services.display import get_display_info
from ..services.system import get_service_info


def check_player_status() -> Dict[str, str]:
    """Check if the player is actually running in Chromium."""
    try:
        # Check if slideshow service is active
        service_active = run_command([SYSTEMCTL_CMD, "is-active", "slideshow-player.service"]) == "active"

        # Check if Chromium is running the player
        chromium_running = False
        if service_active:
            ps_output = run_command([PS_CMD, "aux"])
            chromium_running = "chromium-browser" in ps_output and "slideshow-player" in ps_output

        # Get display status
        display_info = get_display_info()

        # Get process details if running
        process_info = None
        player_start_time = None
        if chromium_running:
            try:
                for proc in psutil.process_iter(["pid", "cpu_percent", "memory_percent", "create_time"]):
                    if "chromium-browser" in proc.name():
                        create_time = datetime.fromtimestamp(proc.create_time(), timezone.utc)
                        player_start_time = create_time.isoformat()
                        process_info = {
                            "pid": proc.pid, 
                            "cpu_usage": proc.cpu_percent(), 
                            "memory_usage": proc.memory_percent(),
                            "start_time": player_start_time
                        }
                        break
            except Exception:
                pass

        return {
            "service_status": "active" if service_active else "inactive",
            "player_status": "running" if chromium_running else "stopped",
            "display_connected": display_info.get("connected", False),
            "healthy": service_active and chromium_running and display_info.get("connected", False),
            "process": process_info,
            "player_start_time": player_start_time,
        }
    except Exception as e:
        return {"service_status": "unknown", "player_status": "unknown", "display_connected": False, "healthy": False, "error": str(e)}


def get_deployment_info() -> Dict:
    """Get deployment information."""
    try:
        # Get current release info
        release_info = get_current_release()
        if not release_info:
            return {"status": "unknown", "error": "Could not determine release path", "last_update": datetime.now(timezone.utc).isoformat()}

        # Get service statuses
        services = {
            "slideshow": get_service_info("slideshow-player.service"),
            "watchdog": get_service_info("watchdog.service"),
            "hide_cursor": get_service_info("hide-cursor.service"),
        }

        # Get display information
        display = get_display_info()

        # Get last reboot time from psutil
        try:
            boot_timestamp = psutil.boot_time()
            boot_datetime = datetime.fromtimestamp(boot_timestamp, timezone.utc)
            last_reboot = boot_datetime.isoformat()
        except Exception:
            last_reboot = datetime.now(timezone.utc).isoformat()

        # Check last successful oasync
        last_sync = None
        last_sync_epoch = None
        try:
            sync_log = Path(PLAYER_ROOT / "logs/oasync").glob("*.log")
            latest_log = max(sync_log, key=os.path.getctime)
            with open(latest_log) as f:
                log_content = f.read()
                if "Could not run oasetup" not in log_content and "Could not run oaplayer" not in log_content:
                    sync_time = datetime.fromtimestamp(os.path.getctime(latest_log))
                    sync_time_utc = sync_time.astimezone(timezone.utc)
                    last_sync = sync_time_utc.isoformat()
                    last_sync_epoch = int(sync_time_utc.timestamp())
        except Exception:
            pass

        # Get player version
        version = "unknown"
        version_file = PLAYER_ROOT / release_info / "version.txt"
        if version_file.exists():
            version = version_file.read_text().strip()

        # Determine overall status
        service_status = all(svc["status"] == "active" for svc in services.values())
        display_status = display.get("connected", False)

        deployment_info = {
            "status": "active" if service_status and display_status else "inactive",
            "version": version,
            "release_path": str(PLAYER_ROOT / release_info),
            "last_update": datetime.now(timezone.utc).isoformat(),
            "last_reboot": last_reboot,
            "last_sync": last_sync,
            "last_sync_epoch": last_sync_epoch,
            "services": services,
            "display": display,
        }

        # Remove None values
        return {k: v for k, v in deployment_info.items() if v is not None}
    except Exception as e:
        return {"status": "unknown", "error": str(e), "last_update": datetime.now(timezone.utc).isoformat()}


def get_current_release() -> str:
    """Get the current release path from the slideshow service."""
    try:
        service_file = "/etc/systemd/system/slideshow-player.service"
        if not os.path.exists(service_file):
            return "unknown"

        with open(service_file) as f:
            content = f.read()

        # Extract release path
        import re

        match = re.search(r"(?<=ExecStart=).*?(?=/dist/linux/slideshow-player)", content)
        if match:
            return os.path.basename(match.group())
    except Exception:
        pass
    return "unknown"
