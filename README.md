# OrangeAd Player on OrangePi 5B Guide

Designed for OrangePi 5B devices. This internal guide covers setup, configuration, and operation using project scripts.

Refer to the **"Onboarding New OrangePi"** section for instructions on creating a microSD card to onboard more OrangePi devices.

## Project Structure Highlights

Key scripts and their purposes in the OrangeAd Player project:

- `oasetup` (`setup.sh`): Handles all initial system configurations. The original script (`setup.sh`) is intended to be run once. Afterwards, use `oasetup` for easy access.
- `oaplayer` (`player-config.sh`): Manages the Player app, including release selection and autorun configuration. After the initial `setup.sh` has been run, use `oaplayer` for easy access.
- `oasync`: A utility for updating the project from the Git repository while preserving local `config/` folder changes. It stashes local changes, pulls updates, reapplies the stash, and then runs `oasetup` and `oaplayer`.
- `oadisplay`: Edit the `config/display.conf` file with expected display resolution and orientation settings. The script also rerun `display.sh` to apply the changes.
- `sreboot`: Reboots the device.

## Auto-Run Processes on Boot

Services configured to run automatically on boot:

- `slideshow-player.service`: Configures the Player to start automatically on boot, the core functionality of the project.
- `chromium-log-monitor.service`: Runs `chromium-log-monitor` to filter and store relevant logs every days, eliminating unnecessary Chrome logs.
- `display-setup.service`: Executes `display.sh` at boot for display resolution and orientation setup. See `config/display.conf` for specific configurations.
- `hide-cursor.service`: Activates `unclutter` to hide the cursor after 2 seconds of inactivity.

## FAQ

### How to install the Player app?

```bash
git clone https://github.com/oa-device/opi-setup.git ~/player
```

For development purpose:

```bash
git clone -b dev https://github.com/oa-device/opi-setup.git ~/player
```

### How to quickly update the project?

```bash
oasync
```

### How to update the system?

```bash
oasetup
```

### How to change display resolution and orientation?

```bash
oadisplay
```

### How to change from one release to another, or to update the player?

```bash
oaplayer
```

### How to reboot the device?

```bash
sreboot
```

### What to do if 'oa' commands cannot be found?

If any of the `oa` commands cannot be found, as shown below:

```bash
orangepi@opi-kai:~$ oasetup
-bash: oasetup: command not found
```

Please follow these steps:

- Run the `setup.sh` script directly inside the `~/player` directory.
- Exit the terminal then ssh into the machine again. Alternatively, you can run `source ~/.bashrc`.

## Onboarding New OrangePi

### Extremely crucial OS requirements

**Must make sure**:

- The OS you have is for the Orangepi **5B**. Installing wrong OS will brick the whole process.

- **Must** use the Ubuntu **Jammy GNOME** version (not xfce, not custom OS).

- Preferably use **16GB** microSD card. Max is **32GB**. Anything bigger than that will not work.

**Why?** As of the time writing this guide, only the GNOME version has **3D acceleration** enabled by OrangePi. Without 3D acceleration, the slideshow player will not work properly.

Steps to search for the OrangePi 5B OS:

- Head to the [OrangePi 5B Download page](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-Pi-5B.html).
- Official Images -> Ubuntu image. Clicking on the Download will open the Google Drive where the manufacturer hosts the OS images.
- You will see there's many options for the OS (Focal or Jammy, GNOME or xfce, etc.). Make sure you download the **Jammy GNOME** version (currently its name is **Orangepi5b_1.0.2_ubuntu_jammy_desktop_gnome_linux5.10.110.7z**)

### 1. Initial SD Card Setup

#### Default login credentials

The default username and password for the OrangePi 5B is `orangepi` and `orangepi` respectively.

#### 1.1. Install the OS to the SD Card

- Use the [balenaEtcher](https://www.balena.io/etcher/) to install the OS to the SD Card. You can also use the `dd` command to do this, but I find balenaEtcher is more user-friendly.

#### 1.2. Power up the OrangePi 5B with the SD Card

- Plug in the SD Card to the OrangePi 5B **before** powering it up. The OrangePi 5B will set priority to boot from the SD Card if it detects one.

#### 1.3. Clone the repository

Clone the repository directly on the OrangePi 5B.

```bash
git clone https://github.com/oa-device/opi-setup.git ~/player
```

#### 1.4. Install all the necessary packages

```bash
cd ~/player
./setup.sh
```

> ⚠️ **IMPORTANT**: This step is **CRUCIAL**. It handles adding the `util-scripts/` folder to the PATH, installs all the necessary packages, and sets up the auto-run processes on boot.

### 2. Migrate from SD Card to eMMC

Follow the guide Brown already made on Confluence to migrate the OS from the SD card to the eMMC. In brief, the steps are:

- On the corner left, select `Applications -> Accessories -> balenaEtcher` and choose to **Clone drive**
- Select the SD card as the source (normally the SD card is the /dev/mmcblk1)
- Select the eMMC as the destination (normally the eMMC is the /dev/mmcblk0)
- Click **Continue** and wait for the process to finish
- Shut down the device and remove the SD card. Boot up the device again and it should boot from the eMMC

### 3. Post-Setup Procedures on each device

#### 3.1. Change the device hostname

The name format should be `<project><xxxx>` where:

- `<project>` is the project name, for example `labatt`, `africa`, `arq`, etc.
- `<xxxx>` is the number marked on the device.

For example:

- If there's only a number `3` stick to the OrangePi, there's high chance it's not yet designed for any project, the hostname should be `opi0003`.
- If the OrangePi is marked with `Labatt0006`, the hostname should be `labatt0006`.

Safe way to set up the hostname:

```bash
hostname-change.sh
```

#### 3.2. Tailscale Login

To connect the device via Tailscale:

```bash
sudo tailscale up
```

Ensure that you log into Tailscale using the account `device@orangead.ca`. Once enrolled, the device is automatically registered with the same name as device's `hostname`. Remember to rename the device in the Tailscale admin console to match your intended name.

#### 3.3. Setting up the Player

Execute the `player.sh` script to set up the slideshow player:

```bash
oaplayer
```

**Note**:

- The script will ask you to choose which release you want to use (`prod`, `preprod` or `staging`). Choose accordingly to your need.
- Running the `player.sh` script will automatically set up the slideshow player to run on startup on the selected release. If you want to change the release, you can run the `player.sh` script again and choose a different release.

### (Optional) If needed, update Remote Origin for very old devices

Run these commands in each device's terminal:

```bash
cd ~/player
git remote set-url origin https://github.com/oa-device/opi-setup.git
git remote -v
```
