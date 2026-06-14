# This repo includes several scripts that make Ubuntu a better distro, including setup for other DE's.
# If you're installing with the ubuntu server iso, I recommend cloning this repo already on the usb disk, in case youre using USB Tethering.

The "setup.sh" script fully removes SNAPS and snap-apps, INCLUDING FIREFOX!
Make sure to run this script without setting up the default firefox, because everything **WILL BE PURGED**.

## Installation
(replace setup.sh with the script you wanna run)
### 1. Clone this repo by running:
```bash
git clone https://github.com/beamyyl/better-ubuntu.git
```
### 2. Go into the cloned folder:
```bash
cd better-ubuntu/
```
### 3. Make the script executable:
```bash
chmod +x setup.sh
```
### 4. Run the script (will require sudo password)
```bash
./setup.sh
```
