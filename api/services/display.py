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
LAST_SCREENSHOT_FILE = SCREENSHOT_DIR / ".last_screenshot_time"

def get_last_screenshot_time() -> Optional[datetime]:
    """Get the last screenshot time from file."""
    try:
        if LAST_SCREENSHOT_FILE.exists():
            timestamp = float(LAST_SCREENSHOT_FILE.read_text().strip())
            last_time = datetime.fromtimestamp(timestamp, timezone.utc)
            
            # Check if the timestamp is too old (e.g., from a previous session)
            now = datetime.now(timezone.utc)
            if (now - last_time).total_seconds() > 3600:  # If older than 1 hour
                LAST_SCREENSHOT_FILE.unlink(missing_ok=True)
                return None
            return last_time
    except (ValueError, OSError):
        LAST_SCREENSHOT_FILE.unlink(missing_ok=True)
    return None

def set_last_screenshot_time(timestamp: datetime) -> None:
    """Save the last screenshot time to file."""
    try:
        SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
        LAST_SCREENSHOT_FILE.write_text(str(timestamp.timestamp()))
    except OSError as e:
        print(f"Error saving timestamp: {e}")

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
    # Check rate limit
    now = datetime.now(timezone.utc)
    last_time = get_last_screenshot_time()
    
    if last_time:
        time_since_last = (now - last_time).total_seconds()
        print(f"Time since last screenshot: {time_since_last} seconds")
        if time_since_last < SCREENSHOT_RATE_LIMIT:
            print(f"Rate limit hit: Need to wait {SCREENSHOT_RATE_LIMIT - time_since_last:.1f} more seconds")
            return None
    else:
        print("No previous screenshot time recorded")
    
    timestamp = now
    filename = f"screenshot_{timestamp.strftime('%Y%m%d_%H%M%S')}.png"
    path = SCREENSHOT_DIR / filename
    print(f"Taking new screenshot: {filename}")
    
    try:
        # Set up environment with proper X11 and DBUS session
        env = os.environ.copy()
        env["DISPLAY"] = ":0.0"
        env["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=/run/user/1000/bus"
        env["XAUTHORITY"] = "/run/user/1000/gdm/Xauthority"
        
        # Ensure screenshot directory exists
        SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
        
        # Take screenshot of the entire screen (no options means full screen)
        print("Running gnome-screenshot command...")
        result = subprocess.run(
            [GNOME_SCREENSHOT_CMD, "-f", str(path)],
            env=env,
            capture_output=True,
            timeout=10  # Increased timeout to 10 seconds
        )
        
        if result.returncode == 0 and path.exists() and path.stat().st_size > 0:
            try:
                print(f"Screenshot taken, size: {path.stat().st_size} bytes")
                # Verify the screenshot is valid
                with Image.open(path) as img:
                    print(f"Image dimensions: {img.size}")
                    # Check image dimensions
                    if img.size[0] < 100 or img.size[1] < 100:
                        print(f"Screenshot dimensions too small: {img.size}")
                        path.unlink(missing_ok=True)  # Clean up failed screenshot
                        return None
                        
                    # Check if image is not all black or white
                    pixels = list(img.getdata())[:100]
                    if all(p[0] == 0 and p[1] == 0 and p[2] == 0 for p in pixels):
                        print("Screenshot appears to be all black")
                        path.unlink(missing_ok=True)  # Clean up failed screenshot
                        return None
                    if all(p[0] == 255 and p[1] == 255 and p[2] == 255 for p in pixels):
                        print("Screenshot appears to be all white")
                        path.unlink(missing_ok=True)  # Clean up failed screenshot
                        return None
                    
                    print("Screenshot validation passed")
                    # Screenshot is valid, save info
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
                    
                    # Update last screenshot time only on success
                    set_last_screenshot_time(timestamp)
                    print("Screenshot info saved and timestamp updated")
                    return path
            except Exception as e:
                print(f"Error validating screenshot: {str(e)}")
                path.unlink(missing_ok=True)  # Clean up failed screenshot
                return None
        
        error_msg = result.stderr.decode() if result.stderr else 'Unknown error'
        print(f"Screenshot failed: {error_msg}")
        path.unlink(missing_ok=True)  # Clean up failed screenshot
        return None
        
    except subprocess.TimeoutExpired:
        print("Screenshot timed out after 10 seconds")
        path.unlink(missing_ok=True)  # Clean up failed screenshot
        return None
    except Exception as e:
        print(f"Screenshot error: {str(e)}")
        path.unlink(missing_ok=True)  # Clean up failed screenshot
        return None

def get_screenshot_history() -> list[ScreenshotInfo]:
    """Get the history of screenshots."""
    return list(screenshots) 