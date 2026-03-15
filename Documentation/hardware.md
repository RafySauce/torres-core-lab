# Torres-Core — Hardware

> **Back to index:** [README.md](./README.md)

---

## Physical Inventory

### proxmox-n3 — Primary Node (Online)

| Component | Spec |
|-----------|------|
| Case | Jonsbo N3 |
| CPU | AMD Ryzen 5 8600G (6C/12T, integrated graphics) |
| RAM | 64GB DDR5 |
| Boot drive | 2TB Samsung 990 EVO NVMe |
| Storage | 2× 12TB Seagate HDD (ZFS mirror, `datapool`) |
| Role | Primary hypervisor — all current workloads |

### Gaming PC — CoreGaming (Daily Driver, Keep)

| Component | Spec |
|-----------|------|
| CPU | AMD Ryzen 9 5900X (12C/24T) |
| GPU | RTX 4070 12GB |
| Storage | Boot SSD + 4TB Seagate Barracuda HDD (to be removed) |
| Role | Daily use, gaming, Ollama/AI inference host, git operations |

The 4TB Barracuda is freed after media transfer to proxmox-n3. Remove and reallocate to Hal (see below).

### Cortana — Secondary Node (Phase 4)

| Component | Spec | Action |
|-----------|------|--------|
| CPU | Intel Core i7-6700 (4C/8T) | Keep |
| RAM | 16GB DDR4 | Keep |
| Boot drive | 1TB Samsung EVO SSD | Proxmox OS drive |
| Bulk storage | 4TB WD Red HDD | `survpool` — surveillance + backup target |
| Current state | Windows — Reolink NVR | Wipe → Proxmox |
| Target IP | 192.168.50.20 | |

### Hal — GPU Node (Phase 4, On-Demand)

| Component | Spec | Action |
|-----------|------|--------|
| CPU | Intel Core i5-4440 (4C/4T) | Keep |
| RAM | 16GB DDR3 | Keep |
| GPU | GTX 1050 | GPU passthrough for Tdarr, ML |
| Storage | None currently | Install 4TB Barracuda from gaming PC |
| Current state | Idle | |
| Target IP | 192.168.50.21 | |

Hal is on-demand — Wake-on-LAN for bursty GPU workloads. Not always-on. Always-on GPU work (Frigate AI detection) lives on Cortana.

### Network Equipment

| Component | Model | Detail |
|-----------|-------|--------|
| Router | Asus GS-AX5400 | Wi-Fi 6, current main router |
| Switch | Ubiquiti EdgeSwitch 8 150W | 802.1Q VLAN-capable, PoE+ all ports — keep |
| AP (unused) | Asus RT-AX1800S | Planned as second AP, not yet deployed |

---

## Spare Drive Allocation

| Drive | Spec | Decision |
|-------|------|----------|
| 4TB Seagate Barracuda | SATA HDD (from gaming PC) | Install in Hal as primary storage |

---

## Planned Network Hardware (Phase 3)

| Component | Model | Cost |
|-----------|-------|------|
| Router/Gateway | Ubiquiti UDR7 | $279 |
| AP | Ubiquiti U7 Lite × 2 | $198 |
| Backhaul | Flat Cat6 to each AP | ~$30 |
| **Total** | | **~$507** |

EdgeSwitch is already owned and stays. UDR7 replaces the Asus router.

---

## Cortana Migration Plan (Phase 4)

### Pre-Migration

1. Back up any Reolink NVR recordings worth keeping from Windows
2. Document all camera IPs, stream URLs, and NVR settings before wiping
3. Note Reolink app config (server address, credentials)

### Install

1. Wipe Windows, boot Proxmox VE installer from USB
2. Install on 1TB Samsung EVO SSD — ZFS RAID0
3. Set static IP: `192.168.50.20`, hostname: `proxmox-cortana.torres-core.us`
4. Disable enterprise repos, add `pve-no-subscription` repo
5. BIOS: "Restore on AC Power Loss" → Power On

### Storage

1. Create ZFS pool on 4TB WD Red: `survpool` (`ashift=12`, `compression=lz4`, `atime=off`)
2. Create datasets: `survpool/surveillance`, `survpool/backups`
3. Register storage IDs in Proxmox

### SSH Hardening (match n3 baseline)

1. Create `rafy` user with sudo
2. Copy Ed25519 public key from gaming PC
3. Disable root SSH (`PermitRootLogin no`)
4. Add SSH shortcut on gaming PC (`ssh cortana`)
5. Deploy figlet + rainbow MOTD (label: "Cortana")
6. Sudoers: passwordless `pct`, `qm`, `pvesm` for `rafy`

### Redundancy LXCs

- **Tailscale LXC 200** — same setup as LXC 100 on n3. Enable subnet failover in Tailscale admin panel (required when two devices advertise the same subnet). No SSH — `pct enter` only.
- **AdGuard LXC 201** — same setup as LXC 103 on n3. Configure AdGuard Home Sync on n3 to push config to `.22` on schedule. Update router DHCP to add `.22` as secondary DNS.

### Reolink NVR VM (202)

1. Create VM 202: 2 cores, 4GB RAM, q35, OVMF BIOS, 60GB virtio disk
2. Install Windows 10 + VirtIO drivers
3. Install Reolink NVR software
4. Mount `survpool/surveillance` via VirtIO-fs (preferred over SMB — no network hop)
5. Set recording path to VirtIO-fs mount
6. Reconnect all cameras to NVR IP `192.168.50.24`
7. Enable Proxmox watchdog — auto-restart on crash
8. Verify camera streams live in Reolink app

### ZFS Replication

1. Set up SSH key trust between proxmox-n3 and proxmox-cortana (root-to-root)
2. Configure Syncoid: `datapool` on n3 → `survpool/backups` on cortana
3. Set nightly schedule
4. Test restore from replication target

### Frigate (LXC 203) — Post-VLAN

Deploy after Phase 3 VLANs — cameras must be on isolated surveillance VLAN first.

- Privileged Debian 12 LXC, 4 cores, 4GB RAM, static `.25`
- RTSP streams direct from cameras
- Home Assistant integration (motion alerts, automations, camera dashboard)
- Evaluate Coral USB accelerator (~$60) for efficient always-on inference
- Frigate (AI detection) and Reolink NVR (full recording + app) can coexist

---

## Hal Migration Plan (Phase 4)

1. Remove 4TB Seagate Barracuda from gaming PC
2. Install drive in Hal
3. Boot Proxmox VE installer from USB, install on the Barracuda (or get a small SSD for OS)
4. Set static IP: `192.168.50.21`, hostname: `proxmox-hal.torres-core.us`
5. Configure GPU passthrough for GTX 1050
6. Configure Wake-on-LAN
7. SSH hardening to match n3 baseline

> **Note on i5-4440:** It's DDR3-era hardware. Worth monitoring power consumption vs. capability. May be better as a single-purpose dedicated box (e.g., Frigate only) than a full Proxmox node. Evaluate after Phase 3.

---

*Last updated: March 14, 2026*
