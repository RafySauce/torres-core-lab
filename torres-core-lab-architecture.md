# Torres-Core Home Lab — Architecture & Roadmap

## Current State Summary

### Node 1: proxmox-n3 (Primary Hypervisor) — ONLINE
| Component | Spec |
|-----------|------|
| Case | Jonsbo N3 |
| CPU | AMD Ryzen 5 8600G (6C/12T, integrated graphics) |
| RAM | 64GB DDR5 |
| Boot/OS | 2TB Samsung 990 EVO NVMe (ZFS-backed Proxmox VE 9.1) |
| Bulk Storage | 2× 12TB Seagate HDDs — ZFS mirror (`datapool`, ~10.9TB usable) |
| Filesystem | ZFS (not LVM) |
| Role | Primary hypervisor |
| IP | `192.168.50.10` (static) |
| Hostname | `proxmox-n3.torres-core.us` |

---

### Storage Layout — proxmox-n3

**rpool (NVMe — Proxmox OS + VM disks)**
| Proxmox Storage ID | Path | Content |
|--------------------|------|---------|
| `local` | `/var/lib/vz` | ISOs, templates, backups |
| `local-zfs` | `rpool/data` | VM disks, container rootdirs |

**datapool (2× 12TB HDD ZFS Mirror)**
| Dataset | Path | Purpose |
|---------|------|---------|
| `datapool/media` | `/datapool/media` | Plex/Jellyfin media root |
| `datapool/media/movies` | `/datapool/media/movies` | Movies |
| `datapool/media/tv` | `/datapool/media/tv` | TV shows |
| `datapool/media/music` | `/datapool/media/music` | Music |
| `datapool/media-private` | `/datapool/media-private` | Private media |
| `datapool/backups` | `/datapool/backups` | Backups |
| `datapool/isos` | `/datapool/isos` | ISO storage |
| `datapool/surveillance` | `/datapool/surveillance` | Camera recordings |
| `datapool/appdata` | `/datapool/appdata` | Docker volumes, service configs |

**Proxmox Storage Registrations:**
| Storage ID | Path | Content Types |
|------------|------|---------------|
| `datapool-media` | `/datapool/media` | images, rootdir, backup, iso, vztmpl, snippets |
| `datapool-backups` | `/datapool/backups` | backup |
| `datapool-isos` | `/datapool/isos` | iso, vztmpl |

---

### Containers & VMs — proxmox-n3

| CT/VM ID | Hostname | Type | IP | Cores | RAM | Purpose | Onboot |
|----------|----------|------|----|-------|-----|---------|--------|
| 100 | tailscale | LXC (privileged) | 192.168.50.11 | 1 | 512MB | Tailscale subnet router — advertises 192.168.50.0/24 | Yes |
| 101 | plex | LXC (privileged) | 192.168.50.12 | 4 | 4GB | Plex Media Server — mounts /datapool/media at /media | Yes |
| 102 | homeassistant | VM (HAOS) | 192.168.50.13 | 2 | 4GB | Home Assistant OS — Zigbee coordinator via USB passthrough | Yes |
| 103 | adguard | LXC (unprivileged) | 192.168.50.14 | 1 | 512MB | AdGuard Home — DNS ad/tracker blocking, local DNS rewrites | Yes |
| 104 | docker | VM (Debian 13) | 192.168.50.16 | 4 | 8GB | Docker Engine + Portainer — media automation stack host | Yes |
| 9000 | debian-13-cloudinit | VM Template | — | 2 | 2GB | Golden Debian 13 cloud-init template — clone for all future VMs | No |

---

### Node 2: proxmox-cortana (Secondary Hypervisor) — PLANNED (Phase 4)
| Component | Spec |
|-----------|------|
| Case | Cortana (existing PC) |
| CPU | Intel Core i7-6700 (4C/8T) |
| RAM | 16GB DDR4 |
| Boot/OS | 1TB Samsung EVO SSD (Proxmox VE on ZFS) |
| Bulk Storage | 4TB WD Red HDD (`survpool` — single disk) |
| Role | Secondary hypervisor — NVR, redundancy services, backup target |
| IP | `192.168.50.20` (static) |
| Hostname | `proxmox-cortana.torres-core.us` |

### Storage Layout — proxmox-cortana (Planned)

**rpool (1TB SSD — Proxmox OS + VM/CT disks)**
| Proxmox Storage ID | Path | Content |
|--------------------|------|---------|
| `local` | `/var/lib/vz` | ISOs, templates, backups |
| `local-zfs` | `rpool/data` | VM disks, container rootdirs |

**survpool (4TB WD Red — single disk)**
| Dataset | Path | Purpose |
|---------|------|---------|
| `survpool/surveillance` | `/survpool/surveillance` | Reolink NVR recordings |
| `survpool/backups` | `/survpool/backups` | ZFS replication target from proxmox-n3 |

> **Note:** WD Red is a single disk — no redundancy. ZFS still provides checksumming and dataset management but this is not a mirror. n3 is the source of truth; Cortana is the backup target.

### Containers & VMs — proxmox-cortana (Planned)

| CT/VM ID | Hostname | Type | IP | Cores | RAM | Purpose | Onboot |
|----------|----------|------|----|-------|-----|---------|--------|
| 200 | tailscale-cortana | LXC (privileged) | 192.168.50.23 | 1 | 512MB | Backup Tailscale subnet router — redundancy for LXC 100 | Yes |
| 201 | adguard-cortana | LXC (unprivileged) | 192.168.50.22 | 1 | 512MB | Secondary AdGuard Home — DNS failover, synced from LXC 103 | Yes |
| 202 | reolink-nvr | VM (Windows 10) | 192.168.50.24 | 2 | 4GB | Reolink NVR — camera recordings to survpool/surveillance | Yes |
| 203 | frigate | LXC (privileged) | 192.168.50.25 | 4 | 4GB | Frigate NVR — AI object detection (future, post-VLAN Phase 3) | Yes |

---

### Node 3: proxmox-hal (GPU Node) — PLANNED (Phase 4, on-demand)
| Component | Spec |
|-----------|------|
| CPU | Intel Core i5-4440 (4C/4T) |
| RAM | 16GB DDR3 |
| GPU | GTX 1050 |
| Storage | 4TB Seagate Barracuda (from gaming PC, after media transfer) |
| Current Role | Idle |
| Future Role | On-demand GPU burst node — Tdarr, ML experiments, Plex transcode offload |
| IP | `192.168.50.21` (reserved) |

> **Note:** Hal is on-demand, not always-on. Wake-on-LAN for bursty GPU workloads. Frigate AI detection lives on Cortana (CPU or Coral USB), not Hal — Frigate needs to be always-on.

---

### Network (Current)
| Component | Detail |
|-----------|--------|
| Router | Asus GS-AX5400 (consumer, Wi-Fi 6) |
| Switch | Ubiquiti EdgeSwitch 8 150W (802.1Q VLAN, PoE+ all ports) |
| AP | Asus RT-AX1800S (planned as second AP, not yet deployed) |
| VLANs | Not yet configured |
| DNS | AdGuard Home primary 192.168.50.14, secondary 192.168.50.22 (after Cortana) |
| Firewall | Router-level only |
| Subnet | 192.168.50.0/24 |
| Gateway | 192.168.50.1 |

### Network (Planned Upgrade — Back Pocket)
| Component | Detail | Cost |
|-----------|--------|------|
| Router/Gateway | Ubiquiti UDR7 (Wi-Fi 7, VLAN, IDS/IPS) | $279 |
| AP × 2 | Ubiquiti U7 Lite (Wi-Fi 7, PoE, ceiling mount) | $198 |
| Backhaul | Flat Cat6 runs to each AP | ~$30 |
| Switch | EdgeSwitch 8 150W (already owned — powers APs via PoE+) | $0 |
| **Total** | | **~$507** |

**Note:** VLANs are a software config on UDR7 + EdgeSwitch. Can be done at any time without rebuilding anything. Large house with thick walls = two U7 Lites confirmed.

---

### Remote Access & DNS
| Service | Status |
|---------|--------|
| Tailscale | Primary subnet router LXC 100 (n3) + backup LXC 200 (cortana, planned) — advertising 192.168.50.0/24. Also on: Android phone, gaming PC, laptop, GL.iNet travel router. |
| Cloudflare | Domain: `torres-core.us` registered and pointed to Cloudflare. No tunnels configured yet. |
| Reverse Proxy | Not deployed yet — planned for Docker VM (Nginx Proxy Manager or Caddy) |
| AdGuard Home | Primary LXC 103 (n3) + secondary LXC 201 (cortana, planned) — DNS rewrites, DoH upstreams, synced via AdGuard Home Sync |
| SMB | Samba on Proxmox host — hardened (mediauser only, root access removed) |

---

### AdGuard Home Configuration
| Setting | Value |
|---------|-------|
| Primary URL | http://adguard.torres-core.us:3000 (LXC 103, n3) |
| Secondary URL | http://192.168.50.22:3000 (LXC 201, cortana — planned) |
| Upstream DNS | Cloudflare DoH + Quad9 DoH (parallel requests) |
| Bootstrap DNS | 1.1.1.1, 9.9.9.9 |
| Blocklists | AdGuard DNS filter, OISD Full, HaGeZi Multi Pro |
| Block rate | ~24% on day 1 |
| Sync | AdGuard Home Sync: n3 (primary) → cortana (replica) on schedule |

**DNS Rewrites:**
| Hostname | IP |
|----------|----|
| proxmox-n3.torres-core.us | 192.168.50.10 |
| plex.torres-core.us | 192.168.50.12 |
| homeassistant.torres-core.us | 192.168.50.13 |
| adguard.torres-core.us | 192.168.50.14 |
| proxmox-cortana.torres-core.us | 192.168.50.20 |
| adguard-cortana.torres-core.us | 192.168.50.22 |
| reolink-nvr.torres-core.us | 192.168.50.24 |
| docker.torres-core.us | 192.168.50.16 |
| portainer.torres-core.us | 192.168.50.16 |
| frigate.torres-core.us | 192.168.50.25 |

---

### Mobile Travel Network — BUILT & CONNECTED
| Component | Detail |
|-----------|--------|
| Router | GL.iNet AX1800 (Flint) — Tailscale client (no subnet advertising) |
| Power | EcoFlow River Pro 2 |
| Camera | Reolink (connected to travel WiFi) |
| Streaming | Roku (connected to travel WiFi) |
| VPN | Proton VPN via WireGuard (manual profiles) |
| DNS | AdGuard Home built-in on GL.iNet (travel ad blocking) |
| Home tunnel | ✅ Tailscale on GL.iNet — split tunnel to 192.168.50.0/24 via LXC 100 |

**Verified:** Roku on travel WiFi discovers and streams Plex at 192.168.50.12 via Tailscale tunnel.

---

## Build Log — proxmox-n3 (March 1–4, 2026)

### 1. Fresh Proxmox VE 9.1 Install
- Wiped previous install (couldn't log in after ~1 year)
- Installed Proxmox VE 9.1 on 2TB Samsung 990 EVO NVMe
- Filesystem: ZFS (RAID0, single NVMe)
- Set static IP: 192.168.50.10
- Hostname: proxmox-n3.torres-core.us
- Disabled enterprise repos (renamed .sources to .sources.disabled)
- Added pve-no-subscription repo

### 2. Storage Configuration
- Wiped old partitions from both 12TB Seagate HDDs (`wipefs -a`)
- Created ZFS mirror pool: `datapool` (2× 12TB, ~10.9TB usable)
  - `ashift=12`, `compression=lz4`, `atime=off`, `xattr=sa`, `acltype=posixacl`
- Created dataset structure: media (movies/tv/music), media-private, backups, isos, surveillance, appdata
- Registered `datapool-media`, `datapool-backups`, `datapool-isos` in Proxmox storage config

### 3. Tailscale Subnet Router (LXC 100)
- Created privileged Debian 12 LXC (1 core, 512MB RAM)
- Enabled TUN device access (`/dev/net/tun` bind mount + cgroup allow)
- Enabled IP forwarding (net.ipv4.ip_forward=1, net.ipv6.conf.all.forwarding=1)
- Installed Tailscale v1.94.2 from official repo
- Authenticated and advertising 192.168.50.0/24 subnet route
- Approved subnet route in Tailscale admin panel
- Set onboot=1 for auto-start
- **Verified:** laptop, phone, gaming PC can reach Proxmox UI via tailnet

### 4. Plex Media Server (LXC 101)
- Created privileged Debian 12 LXC (4 cores, 4GB RAM, 8GB rootfs)
- Mounted datapool/media into container at /media (bind mount via mp0)
- Added child dataset mounts: mp1 (movies), mp2 (tv), mp3 (music), mp4 (private)
- Installed Plex Media Server from official repo
- Accessed web UI at http://192.168.50.12:32400/web
- Linked Plex account (lifetime pass)
- **Disabled remote access / UPnP** — will use Tailscale or Cloudflare Tunnel instead
- Libraries configured: Movies → /media/movies, TV → /media/tv, Music → /media/music
- **COMPLETE:** ~2TB media transfer from gaming PC
- Updated Plex to latest version via apt
- Set onboot=1

### 5. SMB File Sharing (Temporary → Hardened)
- Installed Samba on Proxmox host
- Configured shares: `[media]` → /datapool/media, `[private-media]` → /datapool/media-private
- Set root smbpasswd for file transfer
- **COMPLETED:** ~2TB media transfer from gaming PC
- Created `mediauser` Samba account, removed root Samba access
- Mapped network drives on gaming PC (M: → media, P: → private-media)

### 6. SSH Hardening
- Created non-root user `rafy` with sudo access on Proxmox host
- Generated Ed25519 SSH key on gaming PC
- Copied public key to Proxmox via ssh-copy-id
- Disabled root SSH login (PermitRootLogin no) on Proxmox host
- Configured SSH shortcut on gaming PC (~/.ssh/config → `ssh proxmox-n3`)
- Deployed custom bashrc with figlet banner + rainbow system info MOTD
- Created `rafy` user inside Plex LXC (101)
- Copied SSH key into Plex container, configured shortcut (`ssh plex`)
- Disabled root SSH inside Plex container
- Deployed figlet bashrc inside Plex container
- Configured sudoers for rafy: passwordless pct, qm, pvesm commands
- **Tailscale LXC (100):** No SSH needed — access via `pct enter` only (minimal attack surface)

### 7. System Maintenance
- Disabled pve-enterprise.sources and ceph.sources (renamed to .disabled)
- Added pve-no-subscription.list
- Git installed and configured on gaming PC
- SSH keys (Ed25519) generated on gaming PC
- DHCP reservation created on Asus router for proxmox-n3 (192.168.50.10)
- Set BIOS "Restore on AC Power Loss" → Power On
- Verified both LXCs auto-start after reboot

### 8. Home Assistant OS (VM 102) — March 3, 2026
- Downloaded HAOS 14.2 qcow2 image from GitHub
- Created VM 102: 2 cores, 4GB RAM, q35 machine type, OVMF BIOS
- Imported HAOS disk to local-zfs
- USB passthrough: Sonoff ZBDongle-P (Silicon Labs CP210x, ID 10c4:ea60)
- Completed onboarding, created admin account
- Set static IP: 192.168.50.13/24
- ZHA integration configured — coordinator (TI CC2652P) recognized
- Door sensors paired via Zigbee
- Set onboot=1
- **TODO:** Add WiFi devices, set up automations, pair remaining Zigbee devices

### 9. Travel Network — Tailscale + Plex Verified — March 4, 2026
- GL.iNet AX1800 joined Tailscale as client (no subnet advertising)
- Split tunnel confirmed: travel devices reach 192.168.50.0/24 via LXC 100
- GL.iNet AdGuard Home enabled for travel ad/tracker blocking (local, no home hop)
- **Verified:** Roku on travel WiFi streams Plex via Tailscale — instant server discovery, clean playback

### 10. AdGuard Home (LXC 103) — March 4, 2026
- Created unprivileged Debian 12 LXC (1 core, 512MB RAM, 4GB rootfs)
- Static IP: 192.168.50.14, onboot=1
- Installed AdGuard Home v0.107.72 via official install script
- Upstream DNS: Cloudflare DoH + Quad9 DoH (parallel requests)
- Bootstrap DNS: 1.1.1.1, 9.9.9.9
- Blocklists: AdGuard DNS filter + OISD Full + HaGeZi Multi Pro
- DNS rewrites configured for all lab hostnames (torres-core.us)
- Router cutover: Asus DHCP pushing 192.168.50.14 as DNS to all clients
- Router WAN DNS pointed at 192.168.50.14
- **Verified:** 24% block rate on day 1, nslookup resolving correctly from all clients
- rafy user created, sudo installed, root SSH disabled
- figlet banner + rainbow MOTD deployed
- SSH shortcut added to gaming PC (`ssh adguard`)

### 11. Sanoid ZFS Snapshots — March 5, 2026
- Installed sanoid 2.2.0-2 from Debian trixie repo
- Config: `/etc/sanoid/sanoid.conf`
  - `datapool` — production template: 24 hourly, 30 daily, 6 monthly (recursive)
  - `rpool` — system template: 4 hourly, 7 daily, 2 monthly (recursive)
- systemd timer auto-enabled on install, runs every 15 minutes
- First snapshot run verified — all datasets covered including VM disks and media
- **Verified:** `zfs list -t snapshot` confirms snapshots on all datapool and rpool datasets
- Proxmox host upgraded: 76 packages + proxmox-kernel-6.17.13-1-pve, AMD microcode updated
- Rebooted to new kernel — all LXCs and VMs confirmed online

### 13. Cloud-Init VM Template (VM 9000) — March 6, 2026
- Downloaded Debian 13 genericcloud qcow2 image (smallest cloud variant)
- Created VM 9000 as template base: q35, 2 cores, 2GB RAM, 8GB local-zfs disk
- Imported cloud image disk, attached cloud-init ISO drive
- Configured cloud-init: ciuser=rafy, SSH key baked in, DHCP default, DNS .14, searchdomain torres-core.us
- Enabled snippets on local storage: `pvesm set local --content iso,backup,snippets`
- Created vendor snippet: `/var/lib/vz/snippets/debian-baseline.yaml`
  - Installs: figlet, sudo, qemu-guest-agent
  - Disables root SSH on first boot
  - Pulls bashrc from GitHub: `RafySauce/torres-core-lab/main/scripts/bashrc-rafy.sh`
- Converted to Proxmox template: `qm template 9000`
- **Verified:** Clone boots in ~60s, SSH key auth works, full figlet banner + rainbow MOTD, no console needed

**Clone workflow for all future VMs:**
```bash
sudo qm clone 9000 <VMID> --name <hostname> --full
sudo qm set <VMID> --ipconfig0 ip=192.168.50.XX/24,gw=192.168.50.1 --nameserver 192.168.50.14
sudo qm start <VMID>
# SSH in ~60 seconds later — done
```
- Created VM 104 via CLI: `qm create` — Debian 13 netinst ISO, q35, 4 cores, 8GB RAM, 32GB local-zfs disk, onboot=1
- Installed Debian 13 (trixie) — minimal install, SSH server only
- Static IP: 192.168.50.16/24, gateway .1, DNS .14
- rafy user: sudo access, Ed25519 SSH key from gaming PC, root SSH disabled
- figlet banner + rainbow MOTD deployed (label: "Docker")
- SSH shortcut added to gaming PC (`ssh docker`)
- Installed Docker Engine 29.3.0 from Docker's official bookworm repo
  - docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin
  - rafy added to docker group
- Installed Portainer CE (latest) — running on port 9443
- **Verified:** `docker run hello-world` clean, Portainer UI accessible at https://192.168.50.16:9443
- Portainer restart policy set: `docker update --restart unless-stopped portainer`

### 14. Docker VM — VirtIO-fs Media Mount — March 6, 2026
- Added second VirtIO-fs directory mapping (`media` → `/datapool/media`) on Proxmox host
- Mounted in Docker VM at `/mnt/media` via virtiofs
- Added to `/etc/fstab` for persistence: `media /mnt/media virtiofs defaults 0 0`
- **Verified:** `/mnt/media/movies`, `/mnt/media/tv` accessible from Docker VM
- Set permissions from Proxmox host: `chown -R 1000:1000` on movies and tv datasets

### 15. Media Automation Stack (Docker VM 104) — March 6, 2026
- Created `~/media-stack/` project directory with `docker-compose.yml` and `.env`
- `.env` contains ProtonVPN OpenVPN credentials (gitignored)
- Committed compose file to `torres-core-lab` GitHub repo under `docker/media-stack/`

**Stack containers (all routed through Gluetun VPN):**
| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| gluetun | qmcgaw/gluetun | 8000 (control) | VPN gateway — ProtonVPN OpenVPN, Netherlands, port forwarding enabled |
| qbittorrent | linuxserver/qbittorrent | 8080 | Torrent download client |
| sonarr | linuxserver/sonarr | 8989 | TV show management — root folder `/tv` |
| radarr | linuxserver/radarr | 7878 | Movie management — root folder `/movies` |
| prowlarr | linuxserver/prowlarr | 9696 | Indexer manager — synced to Sonarr + Radarr |
| bazarr | linuxserver/bazarr | 6767 | Subtitle management — connected to Sonarr + Radarr |
| overseerr | linuxserver/overseerr | 5055 | Request UI — connected to Plex + Sonarr + Radarr |
| flaresolverr | flaresolverr/flaresolverr | 8191 | Cloudflare bypass proxy for Prowlarr indexers |

**Gluetun VPN configuration:**
- Provider: ProtonVPN (Plus plan)
- Protocol: OpenVPN UDP 1194
- Country: Netherlands
- Port forwarding: enabled (NAT-PMP via `+pmp` suffix on username)
- Forwarded port: dynamic (written to `/tmp/gluetun/forwarded_port`)
- Kill switch: active — all containers use `network_mode: "service:gluetun"`
- Local network access: `FIREWALL_OUTBOUND_SUBNETS=192.168.50.0/24` (for Plex/Overseerr connectivity)
- Healthcheck: ping-based with 30s start period

**Prowlarr indexers configured:**
- 1337x (with FlareSolverr tag for Cloudflare bypass)
- EZTV (TV focused)
- The Pirate Bay
- LimeTorrents

**Service interconnections:**
- Prowlarr → Sonarr + Radarr (Full Sync — indexers pushed automatically)
- Sonarr + Radarr → qBittorrent (download client, localhost:8080)
- Bazarr → Sonarr + Radarr (API key connection for subtitle matching)
- Overseerr → Plex (192.168.50.12:32400) + Sonarr + Radarr (request routing)

**qBittorrent settings:**
- Default save path: `/downloads/complete`
- Incomplete path: `/downloads/incomplete`
- Listening port: set to Gluetun forwarded port (dynamic)
- UPnP/NAT-PMP: disabled (Gluetun handles port forwarding)
- Seeding ratio limit: configured

**Volume mounts:**
- `/mnt/appdata/<service>` → container `/config` (persistent config per service)
- `/mnt/appdata/downloads` → container `/downloads` (shared download directory)
- `/mnt/media/movies` → Radarr + Bazarr `/movies`
- `/mnt/media/tv` → Sonarr + Bazarr `/tv`

**DNS rewrites added to AdGuard Home:**
- `docker.torres-core.us` → 192.168.50.16
- `portainer.torres-core.us` → 192.168.50.16

**Verified:**
- VPN tunnel active — public IP in Netherlands (ProtonVPN)
- Port forwarding working — seeders can connect inbound
- All 8 container UIs accessible via `docker.torres-core.us:<port>`
- Full pipeline test: Overseerr request → Radarr search → Prowlarr indexers → qBittorrent download
- Sonarr and Radarr both connected to qBittorrent as download client
- Bazarr connected to both Sonarr and Radarr for subtitle automation

**Web UI quick reference:**
| Service | URL |
|---------|-----|
| Portainer | https://docker.torres-core.us:9443 |
| qBittorrent | http://docker.torres-core.us:8080 |
| Sonarr | http://docker.torres-core.us:8989 |
| Radarr | http://docker.torres-core.us:7878 |
| Prowlarr | http://docker.torres-core.us:9696 |
| Bazarr | http://docker.torres-core.us:6767 |
| Overseerr | http://docker.torres-core.us:5055 |

**Known issues / notes:**
- Gluetun MTU discovery error (`VPN route not found for tun0`) is cosmetic — routing works fine
- DNS block list download times out on startup occasionally — resolves after tunnel stabilizes
- Some torrent releases have low seeder health — use Manual Search in Radarr/Sonarr to pick better-seeded alternatives
- `radarr.servarr.com` update check fails through VPN (non-critical, just a version check)

---

## Build Log — proxmox-cortana (Phase 4 — Planned)

### Step 1: Base Proxmox Install
- [ ] Back up any Reolink NVR recordings worth keeping from Windows
- [ ] Note all camera IPs, stream URLs, and NVR config before wiping
- [ ] Wipe Windows, install Proxmox VE on 1TB Samsung EVO SSD
- [ ] Filesystem: ZFS (RAID0, single disk)
- [ ] Set static IP: 192.168.50.20
- [ ] Hostname: proxmox-cortana.torres-core.us
- [ ] Disable enterprise repos, add pve-no-subscription repo (same as n3)
- [ ] Set BIOS → "Restore on AC Power Loss" → Power On

### Step 2: Storage Configuration
- [ ] Create ZFS pool on 4TB WD Red: `survpool`
  - `ashift=12`, `compression=lz4`, `atime=off`
- [ ] Create datasets: `survpool/surveillance`, `survpool/backups`
- [ ] Register `survpool-surveillance` and `survpool-backups` in Proxmox storage config

### Step 3: SSH Hardening (match n3 baseline)
- [ ] Create `rafy` user with sudo access
- [ ] Copy Ed25519 public key from gaming PC
- [ ] Disable root SSH (`PermitRootLogin no`)
- [ ] Add SSH shortcut on gaming PC (`ssh cortana`)
- [ ] Deploy figlet banner + rainbow MOTD bashrc (update figlet label to "Cortana")
- [ ] Configure sudoers: passwordless `pct`, `qm`, `pvesm` for rafy

### Step 4: Redundancy LXCs
- [ ] **Tailscale LXC (200)** — same process as LXC 100 on n3
  - Privileged Debian 12, TUN access, IP forwarding enabled
  - Authenticate to same Tailscale account, advertise `192.168.50.0/24`
  - **Note:** Enable subnet failover in Tailscale admin — two devices advertising same subnet requires this
  - No SSH — access via `pct enter` only
  - onboot=1
- [ ] **AdGuard Home LXC (201)** — same process as LXC 103 on n3
  - Unprivileged Debian 12, static IP 192.168.50.22
  - Install AdGuard Home, same upstreams and blocklists as primary
  - Install **AdGuard Home Sync** on n3 → push config from LXC 103 → LXC 201 on schedule
  - onboot=1
- [ ] **Router DHCP update:** Add `192.168.50.22` as secondary DNS alongside `192.168.50.14`

### Step 5: Reolink NVR VM (202)
- [ ] Download Windows 10 ISO, upload to cortana local storage
- [ ] Create VM 202: 2 cores, 4GB RAM, q35, OVMF BIOS, 60GB virtio disk on `local-zfs`
- [ ] Install Windows 10, VirtIO drivers
- [ ] Install Reolink NVR software
- [ ] Mount `survpool/surveillance` into VM via VirtIO-fs (preferred over Samba — no network hop)
- [ ] Set NVR recording path to VirtIO-fs mount point
- [ ] Reconnect all cameras to new NVR IP (192.168.50.24)
- [ ] Enable Proxmox watchdog on VM 202 (auto-restart on crash)
- [ ] onboot=1
- [ ] **Verified:** Camera streams live in Reolink app on phone/tablet

### Step 6: ZFS Replication from n3 (Backup Target)
- [ ] Set up SSH key trust between proxmox-n3 and proxmox-cortana (root-to-root for ZFS replication)
- [ ] Configure Sanoid/Syncoid: `datapool` snapshots on n3 → `survpool/backups` on cortana
- [ ] Set replication schedule (daily or nightly)
- [ ] Test restore from replication target

### Step 7: Frigate AI NVR (203) — Post-VLAN, Phase 4/5
- [ ] Deploy after Phase 3 VLANs — cameras must be on isolated surveillance VLAN first
- [ ] Privileged Debian 12 LXC, 4 cores, 4GB RAM, static IP 192.168.50.25
- [ ] Pull RTSP streams directly from cameras
- [ ] Integrate with Home Assistant (VM 102 on n3) — motion alerts, automations, camera dashboard
- [ ] Evaluate Coral USB accelerator (~$60) for low-power, efficient inference
- [ ] Reolink NVR VM (202) and Frigate (203) can coexist — Frigate for AI detection, Reolink NVR for full recording and phone/tablet app access

---

## IP Address Map

| IP | Hostname | Role |
|----|----------|------|
| 192.168.50.1 | — | Router (Asus GS-AX5400) |
| 192.168.50.10 | proxmox-n3 | Proxmox hypervisor (primary) |
| 192.168.50.11 | tailscale | Tailscale subnet router — primary (LXC 100, n3) |
| 192.168.50.12 | plex | Plex Media Server (LXC 101, n3) |
| 192.168.50.13 | homeassistant | Home Assistant OS (VM 102, n3) |
| 192.168.50.14 | adguard | AdGuard Home DNS — primary (LXC 103, n3) |
| 192.168.50.15 | — | Reserved: Cloudflare Tunnel (planned) |
| 192.168.50.16 | docker | Docker VM — Docker Engine + Portainer (VM 104, n3) |
| 192.168.50.20 | proxmox-cortana | Proxmox hypervisor (secondary — Phase 4) |
| 192.168.50.21 | proxmox-hal | Proxmox GPU node (on-demand — Phase 4) |
| 192.168.50.22 | adguard-cortana | AdGuard Home DNS — secondary/failover (LXC 201, cortana) |
| 192.168.50.23 | tailscale-cortana | Tailscale subnet router — backup (LXC 200, cortana) |
| 192.168.50.24 | reolink-nvr | Reolink NVR Windows VM (VM 202, cortana) |
| 192.168.50.25 | frigate | Frigate AI NVR (LXC 203, cortana — future) |

---

## Use Cases — Full Inventory

### Priority 1 — Active
| Use Case | Status | Service | Platform |
|----------|--------|---------|----------|
| Media server | ✅ Running | Plex | LXC 101, n3 |
| Secure remote access | ✅ Done | Tailscale subnet router | LXC 100, n3 |
| DNS ad/tracker blocking | ✅ Done — 24% block rate | AdGuard Home | LXC 103, n3 |
| Travel network | ✅ Done — Plex verified on Roku | Tailscale + GL.iNet AdGuard | GL.iNet |

### Priority 2 — Next Up
| Use Case | Status | Service | Platform |
|----------|--------|---------|----------|
| Home automation | 🔄 In progress — HA installed, door sensors paired | Home Assistant | VM 102, n3 |
| ZFS snapshots | ✅ Done — all datasets covered, timer active | Sanoid | proxmox-n3 host |
| Docker platform | ✅ Done — Docker 29.3.0 + Portainer CE live | Docker + Portainer | VM 104, n3 |
| Cloud-init template | ✅ Done — golden Debian 13 image, clone workflow verified | Proxmox cloud-init | VM 9000, proxmox-n3 |
| Media automation stack | ✅ Running — full pipeline verified, VPN + port forwarding active | Gluetun+qBit+Sonarr+Radarr+Prowlarr+Bazarr+Overseerr+FlareSolverr | Docker VM 104, n3 |

### Priority 3 — Phase 3 Network
| Use Case | Status | Service | Platform |
|----------|--------|---------|----------|
| Reverse proxy | Planned | Nginx Proxy Manager or Caddy | Docker VM |
| VLAN segmentation | Planned — needs UDR7 | Ubiquiti UDR7 + EdgeSwitch | Network |
| Email aggregation | Planned | Stalwart/Fetchmail + Roundcube | Docker (planned) |
| Family service access | Planned | Cloudflare Tunnels | LXC (planned) |

### Priority 4 — Node Expansion (Phase 4)
| Use Case | Status | Service | Platform |
|----------|--------|---------|----------|
| Surveillance NVR | ⬜ Planned — migrate from Windows | Reolink NVR | VM 202, cortana |
| DNS redundancy | ⬜ Planned | AdGuard Home Sync | LXC 201, cortana |
| Tailscale redundancy | ⬜ Planned | Tailscale | LXC 200, cortana |
| ZFS replication / backup | ⬜ Planned | Sanoid/Syncoid | n3 → cortana |
| AI surveillance | ⬜ Future — post-VLAN | Frigate + Coral USB | LXC 203, cortana |
| GPU burst workloads | ⬜ Future — on-demand | Tdarr, ML experiments | proxmox-hal |

### Priority 5 — Advanced Services (Phase 5)
| Use Case | Status | Service | Platform |
|----------|--------|---------|----------|
| Asset tracking (cars, dogs, equipment) | Idea | Traccar | Docker (planned) |
| Round-up savings automation | Idea | Custom (Python + Plaid API + Firefly III) | Docker (planned) |
| Password manager | Idea | Vaultwarden | Docker (planned) |
| Wiki / documentation | Idea | BookStack or Outline | Docker (planned) |
| Dashboard | Idea | Homepage or Heimdall | Docker (planned) |
| Monitoring | Idea | Uptime Kuma + Grafana | Docker (planned) |
| Tdarr media transcoding | Idea — needs Hal online | Tdarr | proxmox-hal (future) |
| Offsite backup | Idea | Backblaze B2 / Cloudflare R2 | Automated script |

---

## Suggested Build Order (Revised)

### Phase 1 — Quick Wins ✅ COMPLETE
1. ✅ Fresh Proxmox VE 9.1 install on NVMe
2. ✅ ZFS mirror pool (datapool) on 12TB HDDs with dataset structure
3. ✅ Tailscale subnet router (LXC 100) — remote access working
4. ✅ Media transfer from gaming PC — complete
5. ✅ Plex configured, updated, libraries scanning
6. ✅ Set Plex LXC to onboot=1
7. ✅ SSH hardened — created rafy user, root SSH disabled, Ed25519 key auth
8. ✅ SSH config shortcut on gaming PC (`ssh proxmox-n3`)
9. ✅ Custom bashrc deployed (figlet banner + rainbow system info)
10. ✅ DHCP reservation for proxmox-n3 (.10) on router
11. ✅ Harden SMB: created mediauser, removed root Samba access
12. ✅ Set BIOS "Restore on AC Power Loss" → Power On
13. ✅ GL.iNet Tailscale configured — split tunnel to home lab
14. ✅ Plex streaming via Tailscale verified on travel Roku

### Phase 2 — Core Infrastructure (In Progress)
1. ✅ Deploy Home Assistant VM — installed, Zigbee coordinator connected, door sensors paired
2. ✅ Deploy AdGuard Home (LXC 103) — live, 24% block rate, DNS rewrites active
3. ✅ Sanoid automated ZFS snapshots — running, all datasets covered, timer active
4. ✅ Deploy Docker VM (VM 104) — Debian 13, Docker 29.3.0, Portainer CE, static IP .16
5. ✅ VirtIO-fs mount — datapool/appdata mounted at /mnt/appdata in Docker VM, persists on reboot
6. ✅ Cloud-init template (VM 9000) — golden Debian 13 image, rafy user, SSH key, figlet MOTD, root SSH disabled, bashrc from GitHub
7. ✅ VirtIO-fs media mount — datapool/media mounted at /mnt/media in Docker VM, persists on reboot
8. ✅ Deploy media automation stack — Gluetun (ProtonVPN NL + port forwarding), qBittorrent, Sonarr, Radarr, Prowlarr, Bazarr, Overseerr, FlareSolverr — all wired together, full pipeline verified
9. ✅ DNS rewrites added — docker.torres-core.us + portainer.torres-core.us → .16
10. ⬜ Home Assistant: WiFi devices, automations, remaining Zigbee devices
11. ⬜ Cloudflare Tunnel (deferred — post Docker)

### Phase 3 — Network Segmentation (Weeks 4-8)
1. Purchase UDR7 + 2× U7 Lite
2. Replace Asus router, deploy APs with Cat6 backhaul
3. Create VLANs: Management, Trusted, Lab, IoT, Surveillance, Guest
4. Deploy reverse proxy (Nginx Proxy Manager or Caddy) — clean hostnames without ports
5. Isolate IoT devices, reconnect Alexas on restricted VLAN
6. Isolate cameras on surveillance VLAN (prerequisite for Frigate)
7. VLAN-isolate media automation stack (torrent traffic)

### Phase 4 — Node Expansion (Weeks 8-12)
1. Convert Cortana to Proxmox node (proxmox-cortana)
   - Base install + storage + SSH hardening
   - Tailscale backup LXC (200)
   - AdGuard secondary LXC (201) + AdGuard Home Sync from n3
   - Router DHCP: add 192.168.50.22 as secondary DNS
   - Reolink NVR Windows VM (202) — cameras reconnected, watchdog enabled
   - ZFS replication: n3 → cortana via Sanoid/Syncoid
2. Bring Hal online as on-demand GPU node (proxmox-hal)
   - Install 4TB Barracuda, Proxmox VE, GPU passthrough for GTX 1050
   - Configure Wake-on-LAN
3. Deploy Frigate (LXC 203 on cortana) — after VLANs are live
   - Integrate with Home Assistant for automations and camera dashboard
   - Evaluate Coral USB accelerator for efficient inference

### Phase 5 — Advanced Services (Ongoing)
1. Email aggregation server
2. Asset tracking (Traccar)
3. Monitoring stack (Uptime Kuma, Grafana)
4. Password manager (Vaultwarden)
5. Wiki (BookStack / Outline)
6. Round-up savings automation (custom build)
7. Offsite backup (Backblaze B2 / Cloudflare R2)

---

## Redundancy Map

| Service | Primary | Failover | Strategy |
|---------|---------|----------|----------|
| DNS | AdGuard LXC 103 (n3, .14) | AdGuard LXC 201 (cortana, .22) | Router hands out both IPs — auto failover |
| Remote access | Tailscale LXC 100 (n3) | Tailscale LXC 200 (cortana) | Tailscale subnet failover — both active |
| NVR / cameras | Reolink NVR VM 202 (cortana) | Local SD on each camera | Proxmox watchdog auto-restarts VM on crash |
| Media (Plex) | LXC 101 (n3) | — | Single node fine — not mission critical |
| Home Assistant | VM 102 (n3) | — | Single node fine — Zigbee stays local |
| n3 data | datapool ZFS mirror (2×12TB) | survpool/backups (cortana) | ZFS replication via Syncoid |

---

## Security Hardening Checklist

### proxmox-n3 — COMPLETE
- [x] Created non-root user (rafy) on Proxmox for SSH
- [x] Root SSH disabled, Ed25519 key auth configured
- [x] Tailscale for remote access (no open ports)
- [x] Plex remote access / UPnP disabled
- [x] DHCP reservation for proxmox-n3 on router
- [x] Plex LXC: rafy user created, root SSH disabled, key auth only
- [x] Tailscale LXC: no SSH server (minimal surface, pct enter only)
- [x] Sudoers: rafy has passwordless access to pct/qm/pvesm only
- [x] Lab config Git repo initialized (GitHub, private)
- [x] SMB hardened: mediauser created, root Samba access removed
- [x] BIOS: Restore on AC Power Loss → Power On
- [x] AdGuard Home: DNS-over-HTTPS upstreams (ISP cannot see queries)
- [x] AdGuard LXC: rafy user, root SSH disabled, sudo installed

### proxmox-cortana — PLANNED
- [ ] BIOS: Restore on AC Power Loss → Power On
- [ ] rafy user, root SSH disabled, Ed25519 key auth
- [ ] Tailscale LXC 200: no SSH, `pct enter` only
- [ ] AdGuard Sync: verify blocklists and DNS rewrites stay in sync with primary
- [ ] Reolink NVR VM: Proxmox watchdog enabled, no direct internet access
- [ ] survpool/surveillance: local only, not exposed over SMB
- [ ] Cameras: move to surveillance VLAN after UDR7 (Phase 3 prerequisite for Frigate)

### Network — PLANNED
- [ ] VLANs for IoT and camera isolation (after UDR7)
- [ ] Reverse proxy for clean internal hostnames (after Docker VM)
- [ ] fail2ban on Proxmox host (both nodes)
- [ ] Automated ZFS scrubs and SMART monitoring (both nodes)
- [x] Gluetun VPN kill switch for torrent stack — active, all containers route through VPN
- [x] VPN port forwarding enabled (ProtonVPN NAT-PMP)

---

## Open TODO

### Phase 2 (n3 — Next Sessions)
- [x] Deploy media automation stack (Gluetun, qBit, Sonarr, Radarr, Prowlarr, Bazarr, Overseerr)
- [x] Add docker DNS rewrite to AdGuard (docker.torres-core.us → 192.168.50.16)
- [ ] Commit updated architecture doc to torres-core-lab GitHub repo
- [ ] Set up SSH key for Docker VM → GitHub (for direct git operations from server)
- [ ] Home Assistant: add WiFi devices (smart plugs, bulbs, thermostat)
- [ ] Home Assistant: pair remaining Zigbee devices
- [ ] Home Assistant: build automations (door sensors → notifications, lights)
- [ ] Home Assistant: DHCP reservation for .13 on router
- [ ] Inventory all IoT devices (lights, sensors, Alexa units, cameras)
- [ ] Clean up accidental SSH config file on Proxmox rafy home dir
- [ ] Cloudflare Tunnel (deferred — post Docker)
- [ ] Configure anime separate from TV in Sonarr (separate root folder + quality profile)
- [ ] Revolt self-hosted deployment in Docker VM (see revolt-deployment-plan.docx)

### Phase 4 (Cortana)
- [ ] Back up and document Reolink NVR config (camera IPs, stream URLs) before wiping
- [ ] Install Proxmox VE on Cortana — base build per build log above
- [ ] Deploy Tailscale backup LXC (200) — enable subnet failover in Tailscale admin panel
- [ ] Deploy AdGuard secondary LXC (201) + configure AdGuard Home Sync
- [ ] Update router DHCP: add 192.168.50.22 as secondary DNS
- [ ] Deploy Reolink NVR VM (202) — VirtIO-fs mount for surveillance storage
- [ ] Configure ZFS replication: n3 → cortana via Sanoid/Syncoid
- [ ] Add cortana DNS rewrites to AdGuard primary

### Phase 4 (Hal)
- [ ] Install 4TB Barracuda from gaming PC into Hal
- [ ] Install Proxmox VE, configure GPU passthrough for GTX 1050
- [ ] Configure Wake-on-LAN
- [ ] Assign static IP: 192.168.50.21

---

*Document version: 8.0 — March 6, 2026 (end of session 4 — media automation stack deployed)*
*Lab domain: torres-core.us*
*Architecture partner: Claude (Anthropic)*