import os
from pathlib import Path

# API Version
APP_VERSION = "1.0.0"

# Paths
PLAYER_ROOT = Path(os.getenv("PLAYER_ROOT_DIR", "/home/orangepi/Orangead/player"))
SCREENSHOT_DIR = Path("/tmp/screenshots")

# Command paths
SYSTEMCTL_CMD = "/usr/bin/systemctl"
PS_CMD = "/usr/bin/ps"
READLINK_CMD = "/usr/bin/readlink"
PYTHON_CMD = "/usr/bin/python3"
GNOME_SCREENSHOT_CMD = "/usr/bin/gnome-screenshot"

# Cache settings
CACHE_TTL = 5  # Cache TTL in seconds

# Health check settings
HEALTH_SCORE_WEIGHTS = {
    "cpu": 0.2,
    "memory": 0.2,
    "disk": 0.2,
    "player": 0.2,
    "display": 0.15,
    "network": 0.05
}

HEALTH_SCORE_THRESHOLDS = {
    "critical": 50,
    "warning": 80
}

# Screenshot settings
SCREENSHOT_MAX_HISTORY = 50  # Maximum number of screenshot files to keep
SCREENSHOT_RATE_LIMIT = 5  # seconds