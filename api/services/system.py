import psutil
import platform
import re
from typing import Dict
from datetime import datetime, timezone
from ..core.config import SYSTEMCTL_CMD, PS_CMD, PLAYER_ROOT
from ..services.utils import run_command


def get_system_metrics() -> Dict:
    """Get comprehensive system metrics including CPU, memory, disk, and network usage."""
    try:
        # Get base metrics (keeping existing structure)
        cpu_metrics = {
            "percent": psutil.cpu_percent(interval=1),
            "cores": psutil.cpu_count(),
            "frequency": psutil.cpu_freq()._asdict() if psutil.cpu_freq() else None,
            "per_core": psutil.cpu_percent(interval=1, percpu=True),
        }

        memory = psutil.virtual_memory()
        memory_metrics = {
            "total": memory.total,
            "available": memory.available,
            "percent": memory.percent,
            "used": memory.used,
            "free": memory.free,
            "cached": memory.cached,
            "buffers": memory.buffers if hasattr(memory, "buffers") else None,
        }

        disk = psutil.disk_usage("/")
        disk_metrics = {"total": disk.total, "free": disk.free, "percent": disk.percent, "used": disk.used}

        # Add disk I/O metrics
        try:
            disk_io = psutil.disk_io_counters()
            if disk_io:
                disk_metrics["io"] = {
                    "read_bytes": disk_io.read_bytes,
                    "write_bytes": disk_io.write_bytes,
                    "read_count": disk_io.read_count,
                    "write_count": disk_io.write_count,
                }
        except Exception:
            pass

        # Add network metrics
        try:
            network_metrics = {"interfaces": {}, "connections": len(psutil.net_connections())}

            # Get network interface stats
            net_if_stats = psutil.net_if_stats()
            net_io_counters = psutil.net_io_counters(pernic=True)

            for iface, stats in net_if_stats.items():
                interface_metrics = {"up": stats.isup, "speed": stats.speed, "mtu": stats.mtu}

                # Add IO metrics if available
                if iface in net_io_counters:
                    io_stats = net_io_counters[iface]
                    interface_metrics.update(
                        {
                            "bytes_sent": io_stats.bytes_sent,
                            "bytes_recv": io_stats.bytes_recv,
                            "packets_sent": io_stats.packets_sent,
                            "packets_recv": io_stats.packets_recv,
                            "errors_in": io_stats.errin,
                            "errors_out": io_stats.errout,
                        }
                    )

                network_metrics["interfaces"][iface] = interface_metrics
        except Exception:
            network_metrics = {}

        return {"cpu": cpu_metrics, "memory": memory_metrics, "disk": disk_metrics, "network": network_metrics, "boot_time": psutil.boot_time()}
    except Exception as e:
        return {
            "cpu": {"percent": psutil.cpu_percent(interval=1), "cores": psutil.cpu_count()},
            "memory": {
                "total": psutil.virtual_memory().total,
                "available": psutil.virtual_memory().available,
                "percent": psutil.virtual_memory().percent,
            },
            "disk": {"total": psutil.disk_usage("/").total, "free": psutil.disk_usage("/").free, "percent": psutil.disk_usage("/").percent},
            "error": str(e),
        }


def get_service_info(service_name: str) -> Dict:
    """Get detailed information about a systemd service."""
    info = {"status": "unknown", "mainpid": "unknown", "activestate": "unknown", "substate": "unknown"}

    try:
        status = run_command([SYSTEMCTL_CMD, "is-active", service_name])
        info["status"] = status if status else "inactive"

        show_output = run_command([SYSTEMCTL_CMD, "show", service_name])
        for line in show_output.split("\n"):
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            if key == "MainPID":
                info["mainpid"] = value
            elif key == "ActiveState":
                info["activestate"] = value.lower()
            elif key == "SubState":
                info["substate"] = value.lower()
    except Exception:
        pass

    return info


def get_device_info() -> Dict[str, str]:
    """Get device type and series based on hostname."""
    hostname = platform.node().lower()

    # Extract series and number from hostname (e.g., 'arq0001', 'labatt0002')
    series_match = re.match(r"^([a-z]+)(\d+)$", hostname)
    if series_match:
        series = series_match.group(1).upper()
        return {"type": "OrangePi", "series": series, "hostname": hostname}

    return {"type": "OrangePi", "series": "UNKNOWN", "hostname": hostname}


def get_version_info() -> Dict:
    """Get system and player version information."""
    try:
        # Get system info
        system_info = {
            "os": platform.system(),
            "release": platform.release(),
            "version": platform.version(),
            "machine": platform.machine(),
            "processor": platform.processor(),
            "hostname": platform.node(),
        }

        # Extract series from hostname (e.g., labatt0001 -> labatt)
        hostname = system_info["hostname"].lower()
        series_match = re.match(r"^([a-zA-Z]+)", hostname)
        if series_match:
            system_info["series"] = series_match.group(1)

        # Get player version if available
        player_version_file = PLAYER_ROOT / "version.txt"
        if player_version_file.exists():
            with open(player_version_file) as f:
                system_info["player_version"] = f.read().strip()

        # Get Tailscale version
        try:
            # Use full path to tailscale binary and proper list format for command
            tailscale_version_output = run_command(["/usr/bin/tailscale", "version"])
            if tailscale_version_output:
                # Extract just the version number from the first line (e.g., "1.78.1")
                version_number = tailscale_version_output.split("\n")[0].strip()
                system_info["tailscale_version"] = version_number
            else:
                # If command succeeds but returns empty, try alternative location
                tailscale_version_output = run_command(["/usr/local/bin/tailscale", "version"])
                if tailscale_version_output:
                    version_number = tailscale_version_output.split("\n")[0].strip()
                    system_info["tailscale_version"] = version_number
                else:
                    system_info["tailscale_version"] = None
        except Exception:
            system_info["tailscale_version"] = None

        return system_info
    except Exception as e:
        return {"error": str(e)}
