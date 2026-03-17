# Torres-Core — Mesh Network

> **Back to index:** [README.md](./README.md)

---

## Overview

Torres-Core Mesh is a community LoRa mesh network built on [Reticulum](https://reticulum.network/) and RNode firmware. It provides encrypted, infrastructure-independent communication over 915 MHz LoRa radio — no internet, no cell towers required.

**Stack:** Reticulum (RNS) · RNode firmware · Heltec LoRa32 V3 · 915 MHz ISM band  
**Backbone:** Docker VM (192.168.50.16) running `rnsd`, LXMF router, Nomad BBS  
**Client app:** Sideband (Android/iOS) — connects via USB serial, Bluetooth, or TCP

---

## How Reticulum Works

Reticulum is fundamentally different from Meshtastic. Key concepts:

- **Host-controlled radios:** The Heltec boards are dumb RF modems. They don't run Reticulum themselves — `rnsd` on the host (Docker VM, laptop, phone) drives them over USB serial, setting frequency, bandwidth, TX power, etc. on connect.
- **Per-packet encryption:** Every packet is encrypted with destination keys. No plaintext on the air.
- **Store-and-forward:** Transport nodes (like Node 0) cache and relay packets even when the destination is offline.
- **LXMF:** The messaging layer on top of Reticulum. Like email for the mesh — messages queue and deliver when a path exists.
- **TCP bridging:** `rnsd` exposes a TCP server on port 4242. Any Reticulum client on the LAN or Tailscale can connect and use the backbone's LoRa interface without needing their own radio.

---

## Architecture

```
Phone (Sideband)
  ├── USB serial → Heltec Node 2/3 (mobile) → RF ~~~
  └── TCP :4242 → Docker VM rnsd → Heltec Node 0 → RF ~~~

Docker VM (192.168.50.16)
  └── rnsd (backbone, transport=true)
        ├── RNodeInterface → /dev/ttyUSB0 (Heltec Node 0, 5.8dBi antenna)
        ├── TCPServerInterface → 0.0.0.0:4242 (LAN/Tailscale clients)
        ├── lxmf-router (message store-and-forward)
        └── nomadnet (BBS / information server)
```

---

## Hardware Inventory

### Heltec LoRa32 V3 Nodes

| Serial | Role | Firmware | Status | Bluetooth | Location |
|--------|------|----------|--------|-----------|----------|
| 00:00:00:01 | Node 1 — Relay | RNode 1.85 | ✅ Flashed | Unknown | TBD — elevated fixed |
| 00:00:00:02 | Node 2 — Mobile A | RNode 1.85 | ✅ Flashed | Enabled | With Rafy |
| 00:00:00:03 | Node 3 — Mobile B | RNode 1.85 | ✅ Flashed | Unknown | TBD |
| (Node 0) | Home backbone | RNode 1.85 | ✅ Running | Disabled | Docker VM USB |

All nodes: SX1262 modem, 850–950 MHz range, 22 dBm max TX, hardware revision 1.

### Antennas

| Node | Antenna | Gain | Adapter needed |
|------|---------|------|----------------|
| Node 0 (home) | 5.8dBi fiberglass + 20ft KMR195 cable | 5.8dBi | SMA Male → RP-SMA Female barrel (~$5) |
| Nodes 1–3 | Stock stub (temporary) | ~2dBi | None |

> **Antenna adapter note:** Heltec V3 has SMA Female. The KMR195 cable end is RP-SMA Male. These don't mate directly — need the barrel adapter above.

### Cases

| Use | Recommendation |
|-----|---------------|
| Mobile handheld | 3D print — search "Heltec LoRa32 V3 case" on Printables |
| Outdoor fixed relay | IP65 ABS enclosure (~$10) — 3D prints crack in Buffalo winters |
| Indoor relay | 3D print fine, any snug case with ventilation |

For outdoor: cable gland PG7 for antenna pigtail, M3 standoffs inside, silica gel packet, self-amalgamating tape on lid seam.

---

## RF Parameters

All nodes currently configured identically for bench testing:

| Parameter | Value | Notes |
|-----------|-------|-------|
| Frequency | 915,000,000 Hz | US ISM band, no license required |
| Bandwidth | 125,000 Hz (125 kHz) | Balance of range and throughput |
| TX Power | 10 dBm | Safe for stub antennas — bump to 17 on Node 0 once 5.8dBi installed |
| Spreading Factor | 8 | Good range/speed balance. SF12 = max range but very slow |
| Coding Rate | 5 | Standard |
| On-air bitrate | 3.12 kbps | At these settings |

> **TX power and antennas:** Higher gain antenna = more effective range at same TX power. A 5.8dBi antenna at 10 dBm outperforms a stub at 17 dBm. Don't run high TX into a poorly matched stub — wastes power and stresses the SX1262 PA.

---

## Node 0 — Docker Backbone

### Docker Compose (`~/mesh-stack/docker-compose.yml`)

```yaml
services:
  rnsd:
    build: .
    container_name: rnsd
    devices:
      - /dev/lora32:/dev/ttyUSB0
    volumes:
      - rns-data:/root/.reticulum
    network_mode: host
    restart: unless-stopped

  nomadnet:
    build: .
    container_name: nomadnet
    command: nomadnet --daemon
    volumes:
      - rns-data:/root/.reticulum
      - nomad-data:/root/.nomadnetwork
    network_mode: host
    restart: unless-stopped
    depends_on:
      - rnsd

volumes:
  rns-data:
  nomad-data:
```

`network_mode: host` is intentional — Reticulum's TCP server needs to bind to the host network. The shared `rns-data` volume gives all containers one identity and one view of the mesh.

### Reticulum Config (`/root/.reticulum/config` inside container)

```toml
[reticulum]
  enable_transport = True
  share_instance = Yes

[interfaces]
  [[LoRa32 Home]]
    type = RNodeInterface
    interface_enabled = True
    port = /dev/ttyUSB0
    frequency = 915000000
    bandwidth = 125000
    txpower = 10
    spreadingfactor = 8
    codingrate = 5

  [[TCP Local]]
    type = TCPServerInterface
    interface_enabled = True
    listen_ip = 0.0.0.0
    listen_port = 4242
```

### Udev Rule (proxmox-n3 host)

Stable device path so the container always finds the radio at `/dev/lora32`:

```
# /etc/udev/rules.d/99-lora32.rules
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="lora32"
```

### Useful Commands

```bash
# Check Node 0 status
docker logs rnsd --tail 20

# Watch live
docker logs rnsd -f

# Verify radio is up
docker exec rnsd cat /root/.reticulum/config

# Restart after config change
docker restart rnsd

# Check TCP port is listening
ss -tlnp | grep 4242
```

---

## Mobile Node Setup (Nodes 1–3)

### Flashing (Windows)

Requirements: `py -m pip install rns pyserial esptool`

```powershell
# Flash a single board
py flash_nodes.py --port COM3

# Flash all detected boards in parallel
py flash_nodes.py

# Verify after flash
rnodeconf COM3 --info
```

The flash script (`scripts/Custom_utilities/flash_nodes.py`) handles: board detection (filters Sonoff ZBDongle), Windows PATH fix for rnodeconf, `which()` → `os.path.isfile()` patch, stdin piping for unattended prompts, parallel flashing with per-board spinner.

### RF Config (applied via rnodeconf, persists to EEPROM)

```powershell
rnodeconf COM3 --freq 915000000 --bw 125000 --txp 10 --sf 8 --cr 5 -c
```

> **Note:** RF parameters in rnodeconf are for reference/verification only. Reticulum overwrites them on connect. The actual operating parameters come from the host's `~/.reticulum/config`.

### Enable Bluetooth (for Sideband pairing)

```powershell
rnodeconf COM3 -b -c
rnodeconf COM3 --info  # verify Bluetooth: Enabled
```

### Reticulum Config for Mobile Host (Windows laptop)

`C:\Users\<user>\.reticulum\config` — add to `[interfaces]` section:

```toml
  [[LoRa32 NodeX]]
    type = RNodeInterface
    enabled = Yes
    port = COM3
    frequency = 915000000
    bandwidth = 125000
    txpower = 10
    spreadingfactor = 8
    codingrate = 5

  [[Node0 TCP]]
    type = TCPClientInterface
    enabled = Yes
    target_host = 192.168.50.16
    target_port = 4242
```

> **Windows config gotcha:** Indentation matters. All interface blocks must have exactly 2 spaces before `[[`. Missing indentation causes the interface to be silently skipped with no error.

---

## Sideband (Android Client)

Sideband connects to the mesh via:
- **USB serial** → direct to Heltec board (most reliable for bench testing)
- **Bluetooth** → pair to Heltec (BLE discovery crashes on some Android versions — pair in system Bluetooth first)
- **TCP** → connect to Node 0 backbone at `192.168.50.16:4242` (LAN) or via Tailscale

### Sideband Hardware Settings (RNode via USB/BT)

| Setting | Value |
|---------|-------|
| Frequency | 915000000 |
| Bandwidth | 125 (kHz — not Hz, UI turns red if wrong) |
| TX Power | 10 |
| Spreading Factor | 8 |
| Coding Rate | 5 |

---

## Windows Gotchas (flash_nodes.py USB stick deployment)

These are baked into the flash script but documented here for reference:

- **rnodeconf not on PATH:** pip installs to `Scripts/` dir which may not be in PATH. Script searches `Scripts/` relative to `sys.executable` directly.
- **`--yes` flag not supported:** rns v1.x doesn't have `--yes`. Script pipes stdin: `8\n\n3\ny\n` (device type, blank enter for warning, band, confirm).
- **`which()` fails on Windows:** rnodeconf uses `which(flasher)` to verify esptool.py is executable. On Windows, `which()` won't find `.py` files. Script patches `rnodeconf.py` to use `os.path.isfile()` instead on first run.
- **`python` vs `py`:** On Windows Store Python, `python` may not be on PATH but `py` is. Script uses `sys.executable` throughout.
- **`clear` not recognized:** rnodeconf calls `clear` between prompts — Windows equivalent is `cls`. Cosmetic only, no functional impact.
- **SyntaxWarning in esptool shim:** Python 3.14 warns about `return` in `finally` block in the recovery esptool shim. Harmless.

---

## Deployment Status

### Phase 1 — MVP ⬜ In Progress

| Task | Status |
|------|--------|
| Flash 4 Heltec V3 boards with RNode firmware | ✅ Done (all 4, v1.85) |
| Node 0 Docker stack running | ✅ Running |
| TCP interface on port 4242 | ✅ Listening |
| RF parameters configured on all nodes | ✅ Done |
| Sideband TCP connection to Node 0 | ✅ Configured |
| Sideband USB serial to mobile node | ⬜ Pending test |
| Sideband Bluetooth to mobile node | ⬜ BLE discovery crashes — workaround TBD |
| RF link test: phone node → Node 0 | ⬜ Pending |
| Announce heard across RF link | ⬜ Pending |
| LXMF message end-to-end | ⬜ Pending |
| Nomad BBS accessible | ⬜ Pending |
| Udev rule for stable /dev/lora32 | ⬜ Pending |

### Phase 2 — Building Nodes ⬜ Planned

Deploy fixed nodes at elevated locations around Buffalo. Seneca One Tower (20F+) is the priority — line-of-sight to 15–25km radius over flat terrain and Lake Erie.

```
                Node B (~Hertel/Delaware)
                        |
                        | ~5km
                        |
Node A (west) —— [Seneca One] —— Node C (~Fillmore/E. Ferry)
                        |
                   Home node
                 (southern anchor)
```

Each outdoor node needs: Heltec V3, IP65 enclosure, SMA pigtail, 3–5dBi antenna, 18650 + TP4056 or USB power bank.

**Seneca One site assessment checklist:**
- Window type: standard glass ✅ passes 915MHz / Low-E coating ❌ attenuates 15–30dB
- Rooftop access?
- Power: USB outlet or 5V available?
- Permanent placement possible?

### Phase 3 — Mobile Truck Node ⬜ Planned

T-Beam Supreme or T-Echo with GPS + solar, 5dBi magnetic mount on truck roof, `ROUTER_CLIENT` role. Park at elevated locations (Olmsted parks, escarpment near East Aurora, I-90 overpass) to temporarily extend coverage during events or emergencies.

### Long-Term — Buffalo → Franklin TN Spine ⬜ Vision

| Segment | Distance | Nodes needed |
|---------|----------|-------------|
| Buffalo → Erie PA | ~95 mi | 8–12 |
| Erie → Cleveland | ~95 mi | 8–12 |
| Cleveland → Cincinnati | ~245 mi | 20–28 |
| Cincinnati → Lexington | ~80 mi | 6–10 |
| Lexington → Nashville/Franklin | ~190 mi | 15–20 |
| **Total** | **~705 mi** | **~60–80** |

I-90 and I-71 corridors have elevation advantages and existing ham radio infrastructure. Multi-org effort — start community relationships now.

---

## Terrain Notes — Buffalo

Buffalo sits on a flat glacial lake plain at ~175–180m MSL. Almost no natural elevation variation — buildings are the main obstacle, not terrain.

- Elevation advantage is outsized — a 3-story rooftop outperforms ground level by 5–10x coverage area
- Lake Erie = free RF highway — LoRa over open water reaches 40km+
- Niagara escarpment rises south of the city — nodes in South Buffalo/Orchard Park have less northward coverage than expected

---

## Security Notes

- 915 MHz ISM band — legal, no license required
- Reticulum uses per-packet encryption with destination keys — not trivially intercepted
- Node names for neighbor/volunteer devices: use `Neighbor-01` style — never names, addresses, or health info
- Workflows and public docs never contain credentials or internal IPs

---

## Hardware Reorder List

| Item | Use | Cost | Source |
|------|-----|------|--------|
| Heltec LoRa32 V3 | Neighbor/volunteer nodes | $20–25 | Amazon / AliExpress |
| T-Beam Supreme | Mobile truck + solar nodes | $45–55 | LilyGO / AliExpress |
| IP65 ABS enclosure (115×90×55mm) | Outdoor housing | $8–12 | Amazon |
| 3dBi rubber duck SMA | Relay/indoor nodes | $6–10 | Amazon |
| 18650 LiFePO4 + holder | Relay backup power | $10–15 | Amazon |
| SMA Male → RP-SMA Female adapter | Antenna cable compatibility | $5–8 (get 5) | Amazon |
| Cable gland PG7 | Weatherproof antenna exit | $1–2 | Amazon |
| Silica gel packets | Enclosure desiccant | $1 | Amazon |

---

*Last updated: March 17, 2026*
