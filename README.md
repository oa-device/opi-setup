# slideshow_player Setup Guide

This guide assume that you guys have already set up the OrangePi 5B with the OS and have it connected to the internet. For the OS, please refer to the **Extremely crucial requirements** section.

This guide also assumes you need to setup the OrangePi 5B from scratch, which means this script will be run to set up the **template SD Card**. If you need to migrate from SD card to eMMC, please refer to the **Migrate from SD Card to eMMC** section.

## Extremely crucial OS requirements

Some things you **must make sure**:

- The OS you have is for the Orangepi **5B**. If you have the OS for OrangePi 5 or even the OrangePi 5 Plus, this will **not** work.

- You **must** use the Ubuntu **Jammy GNOME** version (not xfce, not custom OS).

- The SD Card must be at most **32GB** (less than the eMMC size at 64GB). If you have a 64GB SD Card, you need to shrink the partition to 32GB or less.

Why? As of the time wrting this guide, only the GNOME version has **3D acceleration** enabled by OrangePi. Without 3D acceleration, the slideshow player will not work properly.

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
- Use the `rsync` command to transfer the files to the SD Card through the `ssh` connection. Make sure:

  - The OrangePi 5B is connected to the internet
  - The OrangePi 5B has `ssh` enabled, by default. To double check, you can enable `ssh` either by using the Settings from the User Interface or by running the `sudo orangepi-config` command and go to `Network -> SSH`.
  - Must be connected to the same network as the OrangePi 5B. Then, find the IP address by running the `ifconfig` command on the OrangePi 5B and replace the `<ip-adress>` with its actual IP.
  - Run this command on your local machine at the root of this repository:

  ```bash
  rsync -av -e ssh --progress ./ orangepi@<ip-address>:/home/orangepi/player --exclude='.git/'
  ```

  Where `<ip-address>` is the IP address of the OrangePi 5B.

- Clone the repository directly on the OrangePi 5B.
  The same copy of this repository is also hosted on a public repository associated with Kai orangead account. However, this method is not recommended as it requires Kai to constantly update the code on GitHub, where our team is not normally working on. To clone the repository, run the following command on the OrangePi 5B:

  ```bash
  git clone https://github.com/oa-kai/opi-setup.git ~/player
  ```

### 4. Install all the necessary packages

On the OrangePi 5B, open the `Terminal` app and run the `setup.sh` script to update chromium, install Tailscale:

```bash
cd
cd player
./setup.sh
```

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

The name format should be `opi<xxxx>` where `<xxxx>` is the number marked on the device. For example, if the number marked on the device is `3`, the hostname should be `opi0003`.

Recommended ways possible to set up the hostname:

- Using the command line:

```bash
sudo hostnamectl set-hostname <new-hostname>
```

- Using the `sudo orangepi-config` command:

```bash
sudo orangepi-config
Personal -> Hostname
```

**Important:**

1. You should always reboot the device after changing the hostname.
2. After rebooting, open up the "Chromium Web Browser" once. It will ask you to unlock the profile that is still linked with the old hostname. Click "Unlock" and it will automatically update the profile to the new hostname.
3. Even though the WiFi dongle will provide USB connection directly, it's a good practice to configure the WiFi broadcasted from the dongle. This will ensure that if anything not running well with the USB connection, you guys can still power the dongle on separate USB power and let the OrangePi use the WiFi. Run the `/home/orangepi/player/wifi.sh` script to update the WiFi configuration.

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

Ensure that the IMEI for the device is correctly set up. After proper configuration, the IMEI should be located in:

```bash
/home/orangepi/player/<release>/dist/Documents/imei.txt
```

Where `<release>` is the release you chose in the previous step.

### 4. Tailscale Login

To connect the device via Tailscale:

```bash
sudo tailscale up
```

Ensure that you log into Tailscale using the account `device@orangead.ca`. Once logged in, remember to rename the device in the Tailscale admin console to match your intended device name.

### 5. Adjust screen orientation

If the screen is not oriented correctly, you can adjust it by going to:

```bash
Settings -> Screen Display -> Orientation
```

I used to have a script to configure the display automatically, but it's only applicable for **xfce release**. Since we are using the **GNOME/Wayland release**, the script is no longer applicable. I will do more research on this matter to better automating the process for you guys.
