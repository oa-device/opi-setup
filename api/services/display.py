import os
import re
import json
import subprocess
import websocket
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Optional
from PIL import Image
from ..core.config import PYTHON_CMD, PLAYER_ROOT, GNOME_SCREENSHOT_CMD, SCREENSHOT_DIR, SCREENSHOT_MAX_HISTORY, SCREENSHOT_RATE_LIMIT
from ..services.utils import run_command
from ..models.schemas import ScreenshotInfo
from collections import deque

# Global state for screenshots
screenshots: deque[ScreenshotInfo] = deque(maxlen=SCREENSHOT_MAX_HISTORY)
LAST_SCREENSHOT_FILE = SCREENSHOT_DIR / ".last_screenshot_time"


def get_chrome_debug_ws_url() -> Optional[str]:
    """Get the Chrome DevTools WebSocket URL."""
    try:
        # Get the WebSocket URL from Chrome's debug API
        result = subprocess.run(["curl", "-s", "http://localhost:9222/json/list"], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            targets = json.loads(result.stdout)
            # Find the target that matches our app URL
            for target in targets:
                if "webSocketDebuggerUrl" in target and "localhost:8080" in target.get("url", ""):
                    return target["webSocketDebuggerUrl"]
            # If we didn't find our specific page, use the first available target
            if targets and "webSocketDebuggerUrl" in targets[0]:
                return targets[0]["webSocketDebuggerUrl"]
    except Exception as e:
        print(f"Error getting Chrome debug URL: {e}")
    return None


async def take_screenshot() -> Optional[Path]:
    """Take a screenshot using Chrome DevTools Protocol."""
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
        # Ensure screenshot directory exists
        SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)

        # Get the running Chrome instance's WebSocket URL
        ws_url = get_chrome_debug_ws_url()
        if not ws_url:
            print("Could not connect to Chrome DevTools")
            return None

        # Connect to Chrome DevTools
        ws = websocket.create_connection(ws_url)

        try:
            # Get current display info for proper scaling
            display_info = get_display_info()
            current_resolution = display_info.get("resolution", "1920x1080").split("x")
            current_width = int(current_resolution[0])
            current_height = int(current_resolution[1])

            # Calculate scale factor to maintain aspect ratio
            scale_factor = min(1920 / current_width, 1080 / current_height)

            # Take screenshot at original resolution
            ws.send(
                json.dumps(
                    {
                        "id": 2,
                        "method": "Page.captureScreenshot",
                        "params": {
                            "format": "jpeg",  # Use JPEG for smaller file size
                            "quality": 80,  # Maintain good quality for text readability
                            "captureBeyondViewport": True,  # Capture full content
                        },
                    }
                )
            )

            result = json.loads(ws.recv())
            if "result" in result and "data" in result["result"]:
                import base64

                # Save the screenshot
                with open(path, "wb") as f:
                    f.write(base64.b64decode(result["result"]["data"]))

                # Verify and process the screenshot
                with Image.open(path) as img:
                    # Calculate dimensions for FullHD while maintaining aspect ratio
                    width, height = img.size
                    # For portrait orientation, use 1080p vertically
                    if height > width:
                        target_height = 1920
                        target_width = 1080
                    else:
                        target_width = 1920
                        target_height = 1080

                    # Calculate scale to fit the target resolution
                    scale = min(target_width / width, target_height / height)
                    new_width = int(width * scale)
                    new_height = int(height * scale)

                    # Resize the image with high-quality settings
                    resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                    resized.save(path, "JPEG", quality=85, optimize=True)

                    print(f"Screenshot dimensions: {resized.size}")

                    # Check if image is not all black or white
                    pixels = list(resized.getdata())[:100]
                    if all(p[0] == 0 and p[1] == 0 and p[2] == 0 for p in pixels):
                        print("Screenshot appears to be all black")
                        path.unlink(missing_ok=True)
                        return None
                    if all(p[0] == 255 and p[1] == 255 and p[2] == 255 for p in pixels):
                        print("Screenshot appears to be all white")
                        path.unlink(missing_ok=True)
                        return None

                    # Save screenshot info
                    screenshot_info = ScreenshotInfo(
                        timestamp=timestamp.isoformat(), filename=filename, path=str(path), resolution=resized.size, size=path.stat().st_size
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
            else:
                print("Failed to capture screenshot through Chrome DevTools")
                return None

        finally:
            ws.close()

    except Exception as e:
        print(f"Screenshot error: {str(e)}")
        if path.exists():
            path.unlink()
        return None


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
        display_info = run_command([PYTHON_CMD, str(PLAYER_ROOT / "util-scripts/gnome-randr.py")], env=env)

        # Parse the output
        info = {"connected": False, "resolution": "unknown", "refresh_rate": "unknown", "rotation": "unknown", "scale": "unknown"}

        if display_info:
            lines = display_info.split("\n")
            for i, line in enumerate(lines):
                # Check for logical monitor info which contains scale and rotation
                if "logical monitor" in line:
                    for detail in lines[i : i + 3]:
                        if "scale:" in detail:
                            scale_match = re.search(r"scale: ([\d.]+)", detail)
                            if scale_match:
                                info["scale"] = scale_match.group(1)
                        if "rotation:" in detail:
                            rotation_match = re.search(r"rotation: (\w+)", detail)
                            if rotation_match:
                                info["rotation"] = rotation_match.group(1)

                # Check for HDMI connection and current mode
                if "HDMI-1" in line:
                    info["connected"] = True
                    # Look for active mode in next lines
                    for mode_line in lines[i + 1 :]:
                        if "*+" in mode_line:  # Current active mode
                            parts = mode_line.strip().split()
                            if len(parts) >= 2:
                                info["resolution"] = parts[0]
                                # Find the rate marked with *+
                                for part in parts[1:]:
                                    if "*+" in part:
                                        info["refresh_rate"] = part.rstrip("*+")
                                        break
                            break
                        elif not mode_line.strip() or not mode_line[0].isspace():
                            break  # Exit if we're past the resolution list

        return info
    except Exception as e:
        print(f"Display info error: {str(e)}")
        return {"error": str(e)}


def get_screenshot_history() -> list[ScreenshotInfo]:
    """Get the history of screenshots."""
    return list(screenshots)
