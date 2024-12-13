#!/usr/bin/env python3

import os
import re
import platform
import psutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Optional, List
from collections import deque
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse, FileResponse
from pydantic import BaseModel
from PIL import Image

# Constants
APP_VERSION = "1.0.0"
SCREENSHOT_DIR = Path("/tmp/screenshots")
PLAYER_ROOT = Path(os.getenv("PLAYER_ROOT_DIR", "/home/orangepi/Orangead/player"))

# Command paths with full paths for reliability
SYSTEMCTL_CMD = "/usr/bin/systemctl"
PS_CMD = "/usr/bin/ps"
READLINK_CMD = "/usr/bin/readlink"
PYTHON_CMD = "/usr/bin/python3"
GNOME_SCREENSHOT_CMD = "/usr/bin/gnome-screenshot"

# Initialize FastAPI app
app = FastAPI()
app.version = APP_VERSION

# Models
class ScreenshotInfo(BaseModel):
    timestamp: str
    filename: str
    path: str

# Global state
screenshots: deque[ScreenshotInfo] = deque(maxlen=10)
last_screenshot_time: Optional[datetime] = None

def run_command(cmd: List[str], env: Optional[Dict] = None) -> str:
    """Run a shell command and return its output."""
    try:
        result = subprocess.run(
            cmd,
            env=env or os.environ,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return ""

def get_service_info(service_name: str) -> Dict:
    """Get detailed information about a systemd service."""
    info = {
        "status": "unknown",
        "mainpid": "unknown",
        "activestate": "unknown",
        "substate": "unknown"
    }
    
    try:
        status = run_command([SYSTEMCTL_CMD, "is-active", service_name])
        info["status"] = status if status else "inactive"
        
        show_output = run_command([SYSTEMCTL_CMD, "show", service_name])
        for line in show_output.split('\n'):
            if '=' not in line:
                continue
            key, value = line.split('=', 1)
            if key == "MainPID":
                info["mainpid"] = value
            elif key == "ActiveState":
                info["activestate"] = value.lower()
            elif key == "SubState":
                info["substate"] = value.lower()
    except Exception:
        pass
    
    return info

def get_system_metrics() -> Dict:
    """Get system metrics including CPU, memory, and disk usage."""
    return {
        "cpu": {
            "percent": psutil.cpu_percent(interval=1),
            "cores": psutil.cpu_count()
        },
        "memory": {
            "total": psutil.virtual_memory().total,
            "available": psutil.virtual_memory().available,
            "percent": psutil.virtual_memory().percent
        },
        "disk": {
            "total": psutil.disk_usage('/').total,
            "free": psutil.disk_usage('/').free,
            "percent": psutil.disk_usage('/').percent
        }
    }

def get_display_info() -> Dict:
    """Get display configuration and status."""
    try:
        # Set up environment for DBUS
        env = os.environ.copy()
        env["DISPLAY"] = ":0.0"
        env["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=/run/user/1000/bus"
        
        # Run gnome-randr.py to get display info
        display_info = run_command(
            [PYTHON_CMD, str(PLAYER_ROOT / "util-scripts/gnome-randr.py")],
            env=env
        )
        
        # Parse the output
        info = {
            "connected": False,
            "resolution": "unknown",
            "refresh_rate": "unknown",
            "rotation": "unknown",
            "scale": "unknown"
        }
        
        if display_info:
            lines = display_info.split('\n')
            for i, line in enumerate(lines):
                # Check for logical monitor info which contains scale and rotation
                if 'logical monitor' in line:
                    for detail in lines[i:i+3]:
                        if 'scale:' in detail:
                            scale_match = re.search(r'scale: ([\d.]+)', detail)
                            if scale_match:
                                info["scale"] = scale_match.group(1)
                        if 'rotation:' in detail:
                            rotation_match = re.search(r'rotation: (\w+)', detail)
                            if rotation_match:
                                info["rotation"] = rotation_match.group(1)
                
                # Check for HDMI connection and current mode
                if 'HDMI-1' in line:
                    info["connected"] = True
                    # Look for active mode in next lines
                    for mode_line in lines[i+1:]:
                        if '*+' in mode_line:  # Current active mode
                            parts = mode_line.strip().split()
                            if len(parts) >= 2:
                                info["resolution"] = parts[0]
                                # Find the rate marked with *+
                                for part in parts[1:]:
                                    if '*+' in part:
                                        info["refresh_rate"] = part.rstrip('*+')
                                        break
                            break
                        elif not mode_line.strip() or not mode_line[0].isspace():
                            break  # Exit if we're past the resolution list
        
        return info
    except Exception as e:
        print(f"Display info error: {str(e)}")
        return {"error": str(e)}

def get_current_release() -> str:
    """Get the current release path from the slideshow service."""
    try:
        service_file = "/etc/systemd/system/slideshow-player.service"
        if not os.path.exists(service_file):
            return "unknown"
            
        with open(service_file) as f:
            content = f.read()
            
        # Extract release path using the same logic as player-config.sh
        import re
        match = re.search(r'(?<=ExecStart=).*?(?=/dist/linux/slideshow-player)', content)
        if match:
            return os.path.basename(match.group())
    except Exception:
        pass
    return "unknown"

def get_deployment_info() -> Dict:
    """Get deployment information."""
    try:
        # Get current release info
        release_info = get_current_release()
        if not release_info:
            return {
                "status": "unknown",
                "error": "Could not determine release path",
                "last_update": datetime.now(timezone.utc).isoformat()
            }
        
        # Get service statuses
        services = {
            "slideshow": get_service_info("slideshow-player.service"),
            "watchdog": get_service_info("watchdog.service"),
            "hide_cursor": get_service_info("hide-cursor.service")
        }
        
        # Get display information
        display = get_display_info()
        
        # Get last reboot time
        last_reboot = run_command(["who", "-b"]).split()[-1]
        
        # Check last successful oasync with proper timezone and precision
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
            "display": display
        }
        
        # Remove None values
        return {k: v for k, v in deployment_info.items() if v is not None}
    except Exception as e:
        return {
            "status": "unknown",
            "error": str(e),
            "last_update": datetime.now(timezone.utc).isoformat()
        }

def check_player_status() -> Dict[str, str]:
    """Check if the player is actually running in Chromium."""
    try:
        # Check if slideshow service is active
        service_active = run_command(
            [SYSTEMCTL_CMD, "is-active", "slideshow-player.service"]
        ) == "active"
        
        # Check if Chromium is running the player
        chromium_running = False
        if service_active:
            ps_output = run_command([PS_CMD, "aux"])
            chromium_running = "chromium-browser" in ps_output and "slideshow-player" in ps_output
        
        # Get display status
        display_info = get_display_info()
        
        return {
            "service_status": "active" if service_active else "inactive",
            "player_status": "running" if chromium_running else "stopped",
            "display_connected": display_info.get("connected", False),
            "healthy": service_active and chromium_running and display_info.get("connected", False)
        }
    except Exception as e:
        return {
            "service_status": "unknown",
            "player_status": "unknown",
            "display_connected": False,
            "healthy": False,
            "error": str(e)
        }

async def take_screenshot() -> Optional[Path]:
    """Take a screenshot using gnome-screenshot."""
    global last_screenshot_time
    
    timestamp = datetime.now(timezone.utc)
    filename = f"screenshot_{timestamp.strftime('%Y%m%d_%H%M%S')}.png"
    path = SCREENSHOT_DIR / filename
    
    try:
        # Set up environment with proper X11 and DBUS session
        env = os.environ.copy()
        env["DISPLAY"] = ":0.0"
        env["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=/run/user/1000/bus"
        env["XAUTHORITY"] = "/run/user/1000/gdm/Xauthority"
        
        # Take screenshot
        result = subprocess.run(
            [GNOME_SCREENSHOT_CMD, "--window", "--include-border", "-f", str(path)],
            env=env,
            capture_output=True,
            timeout=5
        )
        
        if result.returncode == 0 and path.exists() and path.stat().st_size > 0:
            # Verify the screenshot isn't all black
            with Image.open(path) as img:
                pixels = list(img.getdata())[:100]
                if not all(p[0] == 0 and p[1] == 0 and p[2] == 0 for p in pixels):
                    screenshots.append(ScreenshotInfo(
                        timestamp=timestamp.isoformat(),
                        filename=filename,
                        path=str(path)
                    ))
                    
                    # Clean up old files
                    while len(screenshots) > 10:
                        old = screenshots.popleft()
                        Path(old.path).unlink(missing_ok=True)
                    
                    last_screenshot_time = timestamp
                    return path
                else:
                    print("Screenshot appears to be all black, retrying with different method")
                    # Try alternative method
                    result = subprocess.run(
                        [GNOME_SCREENSHOT_CMD, "--display=:0.0", "--window", "--include-border", "-f", str(path)],
                        env=env,
                        capture_output=True,
                        timeout=5
                    )
                    if result.returncode == 0 and path.exists() and path.stat().st_size > 0:
                        screenshots.append(ScreenshotInfo(
                            timestamp=timestamp.isoformat(),
                            filename=filename,
                            path=str(path)
                        ))
                        last_screenshot_time = timestamp
                        return path
        
        print(f"Screenshot failed: {result.stderr.decode() if result.stderr else 'Unknown error'}")
        return None
        
    except Exception as e:
        print(f"Screenshot error: {str(e)}")
        return None

@app.get("/health")
async def health_check():
    """Get system health status and metrics."""
    try:
        metrics = get_system_metrics()
        deployment = get_deployment_info()
        player = check_player_status()
        
        # Get current time in UTC
        now = datetime.now(timezone.utc)
        
        # Determine overall status
        status = "online"
        if not player["healthy"]:
            status = "maintenance" if player["service_status"] == "active" else "offline"
        
        return JSONResponse({
            "status": status,
            "timestamp": now.isoformat(),
            "timestamp_epoch": int(now.timestamp()),
            "version": {
                "api": app.version,
                "python": platform.python_version(),
                "system": {
                    "platform": platform.system(),
                    "release": platform.release(),
                    "os": f"{platform.system()} {platform.release()}",
                    "type": "OrangePi",
                    "series": "UNKNOWN"
                }
            },
            "metrics": metrics,
            "deployment": deployment,
            "player": player
        })
    except Exception as e:
        now = datetime.now(timezone.utc)
        return JSONResponse({
            "status": "error",
            "timestamp": now.isoformat(),
            "timestamp_epoch": int(now.timestamp()),
            "error": str(e)
        })

@app.get("/screenshots/latest")
async def get_latest_screenshot():
    """Get the latest screenshot."""
    if not screenshots:
        raise HTTPException(status_code=404, detail="No screenshots available")
    
    latest = screenshots[-1]
    if not Path(latest.path).exists():
        raise HTTPException(status_code=404, detail="Screenshot file not found")
    
    return FileResponse(latest.path)

@app.post("/screenshots/capture")
async def capture_screenshot():
    """Capture a new screenshot."""
    # Rate limit: only allow one screenshot every 5 seconds
    if last_screenshot_time and (datetime.now(timezone.utc) - last_screenshot_time).total_seconds() < 5:
        raise HTTPException(status_code=429, detail="Please wait 5 seconds between screenshots")
    
    screenshot_path = await take_screenshot()
    if not screenshot_path:
        raise HTTPException(status_code=500, detail="Failed to capture screenshot")
    
    return {"status": "success", "message": "Screenshot captured successfully"} 