# slideshow_player Setup Guide

This guide will walk you through steps to **set up the template SD Card**, then **migrate to eMMC** and finally **onboarding the OrangePi with our Player/Detector**.

- Setting up the SD Card from scratch and need to download the OS?

  -> Please carefully read the **Extremely crucial OS requirements** section. Then, follow the guide in **Initial SD Card Setup** section.

- Need to migrate from SD card to eMMC?

  -> Please refer to the **Migrate from SD Card to eMMC** section.

- Onboarding the OrangePi with our Player/Detector app?

  -> Please refer to the **Post-Setup Procedures** section.

- Work on existing OrangePi and need to update something?

  -> Please refer to the **FAQ** section.

## FAQ

### How to install the Player/Detector app?

Quick way:

```bash
git clone https://github.com/oa-kai/opi-setup.git ~/player
```

Detail can be found at **Migrate the all the scripts to the SD Card** section.

### I want to setup display resolution and orientation. How?

Edit the `player/config/display.conf` file:

```bash
cd
cd player/config
nano display.conf
```

To save the file, press `Ctrl + X` then `Y` then `Enter`.

For simplicity, just reboot the machine after changing the display config. Else, you can run the `player/util-scripts/display.sh` script to apply the changes without rebooting:

```bash
cd
cd player/util-scripts
./display.sh
```

### I want to update IMEI. How?

```bash
cd
cd player/util-scripts
./imei-change.sh
```

### I want to update the hostname. How?

```bash
cd
cd player/util-scripts
./hostname-change.sh
```

Make sure to reboot the device after changing the hostname.

### I want to change from one release to another. How?

```bash
cd
cd player
./player-config.sh
```

### I want to sync the files from my local machine to the OrangePi. How?

```bash
cd
cd player
./sync.sh
```

## Extremely crucial OS requirements

Some things you **must make sure**:

- The OS you have is for the Orangepi **5B**. If you have the OS for OrangePi 5 or even the OrangePi 5 Plus, this will **not** work.

- You **must** use the Ubuntu **Jammy GNOME** version (not xfce, not custom OS).

- The SD Card must be at most **32GB** (less than the eMMC size at 64GB). Preferably, use a 16GB SD Card.

**Why?** As of the time writing this guide, only the GNOME version has **3D acceleration** enabled by OrangePi. Without 3D acceleration, the slideshow player will not work properly.

Steps to search for the OrangePi 5B OS:

- Head to the [OrangePi 5B Download page](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-Pi-5B.html).
- Official Images -> Ubuntu image. Clicking on the Download will open the Google Drive where the manufacturer hosts the OS images.
- You will see there's many options for the OS (Focal or Jammy, GNOME or xfce, etc.). Make sure you download the **Jammy GNOME** version (currently its name is **Orangepi5b_1.0.2_ubuntu_jammy_desktop_gnome_linux5.10.110.7z**)

## Initial SD Card Setup

### Default login credentials

The default username and password for the OrangePi 5B is `orangepi` and `orangepi` respectively.

### 1. Install the OS to the SD Card

- Use the [balenaEtcher](https://www.balena.io/etcher/) to install the OS to the SD Card. You can also use the `dd` command to do this, but I find balenaEtcher is more user-friendly.

### 2. Power up the OrangePi 5B with the SD Card

- Plug in the SD Card to the OrangePi 5B **before** powering it up. The OrangePi 5B will set priority to boot from the SD Card if it detects one.

### 3. Migrate the all the scripts to the SD Card

Multiple ways to do this:

- Use a USB to transfer the files to the SD Card
- Use the script `sync.sh` to sync the files from your local machine to the SD Card. This method is recommended as it will automatically exclude unwanted folders from the sync process. Make sure:

  - The OrangePi 5B is connected to the internet
  - The OrangePi 5B has `ssh` enabled, by default. To double check, you can enable `ssh` either by using the Settings from the User Interface or by running the `sudo orangepi-config` command and go to `Network -> SSH`.
  - Must be connected to the same network as the OrangePi 5B. Then, find the IP address by running the `ifconfig` command on the OrangePi 5B and use it for the `sync.sh` script.

- Clone the repository directly on the OrangePi 5B.
  The same copy of this repository is also hosted on a public repository associated with Kai orangead account. However, this method is not recommended as it requires Kai to constantly update the code on GitHub, where our team is not normally working on. To clone the repository, run the following command on the OrangePi 5B:

  ```bash
  git clone https://github.com/oa-kai/opi-setup.git ~/player
  ```

### 4. Install all the necessary packages

On the OrangePi 5B, open the `Terminal` app and run the `setup.sh` script. It will do the following:

- Change default user password
- Set up timezone to Montreal
- Update the OS packages
- Install/Update Chromium Browser
- Install/Update Tailscale
- Install/Update Unclutter (to autohide the mouse cursor)
- Set up the screen resolution and orientation.
- Make the OrangePi auto-reboot at 3AM everyday
- Change GNOME Settings:
  - Disable Bluetooth
  - Enable Screen Keyboard
  - Disable Screen Lock

```bash
cd
cd player
./setup.sh
```

### 5. Setting up VNC (Need to be improved)

`Settings -> Sharing -> Remote Desktop`

- Enable `Remote Desktop`
- Enable `Enable Legacy VNC Control` -> Change to `Require a password`
- Enable `Remote Control`
- At `Authentication`, set the password to as you wish.

On your local machine, the only VNC client that works for me is the `TigerVNC` on MacOS. Haven't tried on Windows/Linux yet.

### 6. Setting up Screen Keyboard (optional)

This can be useful when you guys need to set up new WiFi at the destination. The screen keyboard can be enabled by:

`Settings -> Accessibility -> Typing section -> Screen Keyboard`

If the Screen Keyboard still not working yet, you can look for the keyboard icon on the top right corner, then click `Restart` on it. Else, just simply reboot the device.

## Migrate from SD Card to eMMC

Follow the guide Brown already made on Confluence to migrate the OS from the SD card to the eMMC. In brief, the steps are:

- On the corner left, select `Applications -> Accessories -> balenaEtcher` and choose to **Clone drive**
- Select the SD card as the source (normally the SD card is the /dev/mmcblk1)
- Select the eMMC as the destination (normally the eMMC is the /dev/mmcblk0)
- Click **Continue** and wait for the process to finish
- Shut down the device and remove the SD card. Boot up the device again and it should boot from the eMMC

### From here the guide assumes that you have already migrated from SD card to eMMC, and the device is booting from the eMMC

## Post-Setup Procedures

### 1. Change the device hostname

The name format should be `<project><xxxx>` where:

- `<project>` is the project name, for example `labatt`, `africa`, `arq`, etc.
- `<xxxx>` is the number marked on the device.

For example:

- If there's only a number `3` stick to the OrangePi, there's high chance it's not yet designed for any project, the hostname should be `opi0003`.
- If the OrangePi is marked with `Labatt0006`, the hostname should be `labatt0006`.

Safe way to set up the hostname:

```bash
cd
cd player/util-scripts
./hostname-change.sh
```

In this script, Kai already handle the lock on Chromium Web Browser profile. The script will also ask you to reboot the device after changing the hostname (recommended).

**Note:**

- Even though the WiFi dongle will provide USB connection directly, it's a good practice to configure the WiFi broadcasted from the dongle. This will ensure that if anything not running well with the USB connection, you guys can still power the dongle on separate USB power and let the OrangePi use the WiFi. Run the `~/player/util-scripts/wifi.sh` script to update the WiFi configuration.

### 2. Setting up the Slideshow Player

Execute the `player.sh` script to set up the slideshow player:

```bash
cd
cd player
./player.sh
```

**Note**:

- The script will ask you to choose which release you want to use (`prod`, `preprod` or `staging`). Choose accordingly to your need.
- Running the `player.sh` script will automatically set up the slideshow player to run on startup on the selected release. If you want to change the release, you can run the `player.sh` script again and choose a different release.

### 3. IMEI Setup

To ensure that the device is properly registered to the IMEI, run the `imei-change.sh` script:

```bash
cd
cd player/util-scripts
./imei-change.sh
```

### 4. Tailscale Login

To connect the device via Tailscale:

```bash
sudo tailscale up
```

Ensure that you log into Tailscale using the account `device@orangead.ca`. Once enrolled, the device is automatically registered with the same name as device's `hostname`. Remember to rename the device in the Tailscale admin console to match your intended name.
