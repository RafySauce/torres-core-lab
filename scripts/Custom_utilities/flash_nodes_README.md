# Torres-Core Mesh — Bulk Node Flasher

Automatically detects Heltec LoRa32 V3 boards on a powered USB hub,
downloads the latest Meshtastic firmware from GitHub, and flashes all
of them in parallel. Safely ignores the Sonoff ZBDongle even though it
shares the same CP2102 chip ID.

---

## Setup (one time)

**1. Install CP210x driver** (required on Windows — boards won't show as COM ports without it)

Download from: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers
→ "CP210x Windows Drivers" → install → reboot if prompted

**2. Install Python dependencies**

```powershell
py -m pip install esptool requests pyserial
```

---

## Usage

```powershell
# Flash all detected boards (most common)
py flash_nodes.py

# Just list what boards are detected, don't flash
py flash_nodes.py --list

# Flash a single specific port
py flash_nodes.py --port COM3

# Download firmware only, don't flash anything
py flash_nodes.py --dry-run
```

---

## Workflow for bulk flashing (10 boards)

1. Plug all boards into the powered USB hub
2. Run `py flash_nodes.py --list` to confirm all boards detected
3. Run `py flash_nodes.py` — confirm when prompted
4. Wait ~60 seconds — boards flash in parallel
5. Each board reboots automatically into Meshtastic
6. Open Meshtastic app on phone, pair via Bluetooth

---

## How it works

- Scans all COM ports for CP2102 devices (VID `10C4`, PID `EA60`)
- Filters out the Sonoff ZBDongle by checking product/description strings
- Hits GitHub API to find the latest Meshtastic release
- Downloads `firmware-heltec-wsl-v3-X.X.X.bin` (caches in `./firmware/`)
- Puts each board into ESP32-S3 bootloader mode via 1200bps DTR trick
- Runs esptool in parallel threads, one per board
- Reports per-board pass/fail with a summary

---

## Troubleshooting

**Board not detected:**
- CP210x driver not installed — see setup step 1
- Charge-only USB cable — swap for a data cable
- Try a different USB port on the hub

**Flash fails with "Failed to connect":**
- Board didn't enter bootloader mode automatically
- Hold the PRG button on the board, then press RST once, release PRG
- Re-run the script — it will retry

**"No matching firmware found":**
- GitHub API returned a release without the heltec-wsl-v3 binary
- Check https://github.com/meshtastic/firmware/releases manually
- Download the .bin file and place it in the `./firmware/` folder
- Script will use the cached file automatically

---

## Node roles after flashing

All boards come up as `CLIENT` role by default. Change role in the
Meshtastic app under Radio Config → Device:

| Node | Role |
|------|------|
| Node 1 (relay) | `ROUTER` |
| Node 2 (mobile A) | `CLIENT` (default, no change needed) |
| Node 3 (mobile B) | `CLIENT` (default, no change needed) |

---

*Torres-Core Mesh · buffalo-mesh-technical-plan.md for full rollout plan*
