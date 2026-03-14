# Torres-Core — Infrastructure

> **Back to index:** [README.md](./README.md)

---

## Nodes

| Node | Status | IP | Role |
|------|--------|----|------|
| proxmox-n3 | ✅ Online | 192.168.50.10 | Primary hypervisor |
| proxmox-cortana | ⬜ Planned (Phase 4) | 192.168.50.20 | Secondary hypervisor — NVR, redundancy, backup target |
| proxmox-hal | ⬜ Planned (Phase 4) | 192.168.50.21 | On-demand GPU burst node |

---

## proxmox-n3 — Primary Hypervisor

| Component | Spec |
|-----------|------|
| Case | Jonsbo N3 |
| CPU | AMD Ryzen 5 8600G (6C/12T, integrated graphics) |
| RAM | 64GB DDR5 |
| Boot/OS | 2TB Samsung 990 EVO NVMe — ZFS RAID0, Proxmox VE 9.1 |
| Bulk storage | 2× 12TB Seagate HDD — ZFS mirror (`datapool`, ~10.9TB usable) |
| IP | `192.168.50.10` (static, DHCP reservation) |
| Hostname | `proxmox-n3.torres-core.us` |

### Storage — proxmox-n3

**rpool (NVMe — Proxmox OS + VM disks)**

| Storage ID | Path | Content |
|------------|------|---------|
| `local` | `/var/lib/vz` | ISOs, templates, backups |
| `local-zfs` | `rpool/data` | VM disks, container rootdirs |

**datapool (2× 12TB HDD ZFS Mirror)**

| Dataset | Path | Purpose |
|---------|------|---------|
| `datapool/media` | `/datapool/media` | Plex media root |
| `datapool/media/movies` | `/datapool/media/movies` | Movies |
| `datapool/media/tv` | `/datapool/media/tv` | TV shows |
| `datapool/media/music` | `/datapool/media/music` | Music |
| `datapool/media-private` | `/datapool/media-private` | Private media |
| `datapool/backups` | `/datapool/backups` | Proxmox backups |
| `datapool/isos` | `/datapool/isos` | ISO storage |
| `datapool/surveillance` | `/datapool/surveillance` | Camera recordings |
| `datapool/appdata` | `/datapool/appdata` | Docker volumes, service configs |

**Proxmox storage registrations:**

| Storage ID | Path | Content Types |
|------------|------|---------------|
| `datapool-media` | `/datapool/media` | images, rootdir, backup, iso, vztmpl, snippets |
| `datapool-backups` | `/datapool/backups` | backup |
| `datapool-isos` | `/datapool/isos` | iso, vztmpl |

**ZFS pool properties:** `ashift=12`, `compression=lz4`, `atime=off`, `xattr=sa`, `acltype=posixacl`

### VMs and Containers — proxmox-n3

| ID | Hostname | Type | IP | Cores | RAM | Purpose | Onboot |
|----|----------|------|----|-------|-----|---------|--------|
| 100 | tailscale | LXC (privileged) | .11 | 1 | 512MB | Tailscale subnet router | Yes |
| 101 | plex | LXC (privileged) | .12 | 4 | 4GB | Plex Media Server | Yes |
| 102 | homeassistant | VM (HAOS) | .13 | 2 | 4GB | Home Assistant OS + Zigbee | Yes |
| 103 | adguard | LXC (unprivileged) | .14 | 1 | 512MB | AdGuard Home — DNS | Yes |
| 104 | docker | VM (Debian 13) | .16 | 4 | 8GB | Docker Engine + Portainer | Yes |
| 9000 | debian-13-cloudinit | VM Template | — | 2 | 2GB | Cloud-init golden image | No |

### Sanoid ZFS Snapshots

| Pool | Template | Hourly | Daily | Monthly |
|------|----------|--------|-------|---------|
| `datapool` | production | 24 | 30 | 6 |
| `rpool` | system | 4 | 7 | 2 |

Sanoid runs via systemd timer every 15 minutes. Verify: `zfs list -t snapshot`

---

## proxmox-cortana — Secondary Hypervisor (Phase 4, Planned)

| Component | Spec |
|-----------|------|
| CPU | Intel Core i7-6700 (4C/8T) |
| RAM | 16GB DDR4 |
| Boot/OS | 1TB Samsung EVO SSD — ZFS RAID0, Proxmox VE |
| Bulk storage | 4TB WD Red HDD — `survpool` (single disk, no redundancy) |
| IP | `192.168.50.20` (reserved) |
| Hostname | `proxmox-cortana.torres-core.us` |

### Storage — proxmox-cortana (Planned)

**survpool (4TB WD Red — single disk)**

| Dataset | Path | Purpose |
|---------|------|---------|
| `survpool/surveillance` | `/survpool/surveillance` | Reolink NVR recordings |
| `survpool/backups` | `/survpool/backups` | ZFS replication target from n3 |

> WD Red is a single disk — no redundancy. ZFS provides checksumming and dataset management, but n3 is the source of truth. Cortana is the backup target.

### VMs and Containers — proxmox-cortana (Planned)

| ID | Hostname | Type | IP | Cores | RAM | Purpose | Onboot |
|----|----------|------|----|-------|-----|---------|--------|
| 200 | tailscale-cortana | LXC (privileged) | .23 | 1 | 512MB | Tailscale subnet router — backup | Yes |
| 201 | adguard-cortana | LXC (unprivileged) | .22 | 1 | 512MB | AdGuard Home — DNS failover | Yes |
| 202 | reolink-nvr | VM (Windows 10) | .24 | 2 | 4GB | Reolink NVR — camera recordings | Yes |
| 203 | frigate | LXC (privileged) | .25 | 4 | 4GB | Frigate AI NVR (post-VLAN) | Yes |

---

## proxmox-hal — GPU Node (Phase 4, On-Demand)

| Component | Spec |
|-----------|------|
| CPU | Intel Core i5-4440 (4C/4T) |
| RAM | 16GB DDR3 |
| GPU | GTX 1050 |
| Storage | 4TB Seagate Barracuda (from gaming PC) |
| IP | `192.168.50.21` (reserved) |

Hal is on-demand — Wake-on-LAN for bursty GPU workloads (Tdarr, ML experiments, Plex transcode offload). Not always-on. Frigate stays on Cortana since it needs to be always running.

---

## Cloud-Init Template (VM 9000)

Golden Debian 13 image for rapid VM provisioning. Clone workflow:

```bash
sudo qm clone 9000 <VMID> --name <hostname> --full
sudo qm set <VMID> --ipconfig0 ip=192.168.50.XX/24,gw=192.168.50.1 --nameserver 192.168.50.14
sudo qm start <VMID>
# SSH-ready in ~60 seconds
```

Pre-baked: `rafy` user, Ed25519 SSH key, figlet+rainbow MOTD, root SSH disabled, `qemu-guest-agent`, bashrc pulled from GitHub on first boot.

---

## Redundancy Map

| Service | Primary | Failover | Strategy |
|---------|---------|----------|----------|
| DNS | AdGuard LXC 103 (n3, .14) | AdGuard LXC 201 (cortana, .22) | Router DHCP hands out both — auto failover |
| Remote access | Tailscale LXC 100 (n3) | Tailscale LXC 200 (cortana) | Tailscale subnet failover — both active simultaneously |
| NVR / cameras | Reolink NVR VM 202 (cortana) | SD card on each camera | Proxmox watchdog auto-restarts VM on crash |
| Media (Plex) | LXC 101 (n3) | — | Single node — not mission critical |
| Home Assistant | VM 102 (n3) | — | Single node — Zigbee stays local |
| n3 data | `datapool` ZFS mirror (2×12TB) | `survpool/backups` (cortana) | ZFS replication via Syncoid |

---

*Last updated: March 14, 2026*
