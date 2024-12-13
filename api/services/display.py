import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Optional
from PIL import Image
from ..core.config import (
    PYTHON_CMD, 
    PLAYER_ROOT, 
    GNOME_SCREENSHOT_CMD, 
    SCREENSHOT_DIR,
    SCREENSHOT_MAX_HISTORY,
    SCREENSHOT_RATE_LIMIT
)
from ..services.utils import run_command
from ..models.schemas import ScreenshotInfo
from collections import deque

# Global state for screenshots
screenshots: deque[ScreenshotInfo] = deque(maxlen=SCREENSHOT_MAX_HISTORY)
last_screenshot_time: Optional[datetime] = None

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

async def take_screenshot() -> Optional[Path]:
    """Take a screenshot using gnome-screenshot."""
    global last_screenshot_time
    
    # Check rate limit
    now = datetime.now(timezone.utc)
    if last_screenshot_time and (now - last_screenshot_time).total_seconds() < SCREENSHOT_RATE_LIMIT:
        return None
    
    timestamp = now
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
                    screenshot_info = ScreenshotInfo(
                        timestamp=timestamp.isoformat(),
                        filename=filename,
                        path=str(path),
                        resolution=img.size,
                        size=path.stat().st_size
                    )
                    screenshots.append(screenshot_info)
                    
                    # Clean up old files
                    while len(screenshots) > SCREENSHOT_MAX_HISTORY:
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
                        screenshot_info = ScreenshotInfo(
                            timestamp=timestamp.isoformat(),
                            filename=filename,
                            path=str(path),
                            resolution=img.size,
                            size=path.stat().st_size
                        )
                        screenshots.append(screenshot_info)
                        last_screenshot_time = timestamp
                        return path
        
        print(f"Screenshot failed: {result.stderr.decode() if result.stderr else 'Unknown error'}")
        return None
        
    except Exception as e:
        print(f"Screenshot error: {str(e)}")
        return None

def get_screenshot_history() -> list[ScreenshotInfo]:
    """Get the history of screenshots."""
    return list(screenshots) 