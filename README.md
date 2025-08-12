# opi-setup

OrangePi 5B device management system providing health monitoring API and player utilities for digital signage deployment.

## Overview

**API Service:** FastAPI health monitoring (port 9090)  
**Scripts:** Device configuration, player management, system utilities  
**Purpose:** Deployed on remote OrangePi devices for centralized monitoring

📚 **[Complete Documentation](../docs/README.md)**

## Key Scripts

**Utility Commands:**
- `oasetup` - System configuration and package installation
- `oaplayer` - Player app management and release selection  
- `oasync` - Project updates with config preservation
- `oadisplay` - Display resolution and orientation setup
- `oasvc` - Service status monitoring
- `sreboot` - Device reboot

**Systemd Services:**
- `slideshow-player.service` - Core player functionality
- `display-setup.service` - Display configuration on boot
- `chromium-log-monitor.service` - Log filtering and cleanup
- `hide-cursor.service` - Cursor hiding for displays

## Quick Start

```bash
# Initial installation
git clone https://github.com/oa-device/opi-setup.git ~/Orangead/player
cd ~/Orangead/player
./setup.sh

# Common operations
oasync        # Update project
oaplayer      # Configure player
oadisplay     # Setup display
oasvc         # Check services
sreboot       # Reboot device
```

## Key Documentation

- 🏗️ **[System Architecture](../docs/architecture/system_overview.md)** - Component overview
- 📊 **[Health Scoring](../docs/monitoring/health_scoring.md)** - Monitoring details  
- 🔧 **[Golden Signals](../docs/monitoring/golden_signals.md)** - Operational metrics
- ⚡ **[Getting Started](../docs/development/getting_started.md)** - Development workflow

## Device Onboarding Summary

**Requirements:** Ubuntu Jammy GNOME on OrangePi 5B, 16-32GB microSD  
**Process:** Flash OS → Clone repo → Run `./setup.sh` → Configure hostname → Setup Tailscale → Configure player

For detailed onboarding instructions, see the [complete guide](../docs/infrastructure/deployment.md).
