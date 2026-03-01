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

### Storage Layout

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

### Containers & VMs Running

| CT/VM ID | Hostname | Type | IP | Cores | RAM | Purpose | Onboot |
|----------|----------|------|----|-------|-----|---------|--------|
| 100 | tailscale | LXC (privileged) | 192.168.50.11 | 1 | 512MB | Tailscale subnet router — advertises 192.168.50.0/24 | Yes |
| 101 | plex | LXC (privileged) | 192.168.50.12 | 4 | 4GB | Plex Media Server — mounts /datapool/media at /media | Not yet |

---

### Network (Current)
| Component | Detail |
|-----------|--------|
| Router | Asus GS-AX5400 (consumer, Wi-Fi 6) |
| Switch | Ubiquiti EdgeSwitch 8 150W (802.1Q VLAN, PoE+ all ports) |
| AP | Asus RT-AX1800S (planned as second AP, not yet deployed) |
| VLANs | Not yet configured |
| DNS | ISP default (no Pi-hole/AdGuard yet) |
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
| Tailscale | Subnet router on LXC 100 — advertising 192.168.50.0/24. Also on: Android phone, gaming PC, laptop, GL.iNet travel router. |
| Cloudflare | Domain: `torres-core.us` registered and pointed to Cloudflare. No tunnels configured yet. |
| Reverse Proxy | Not deployed yet |
| SMB | Samba on Proxmox host — sharing `datapool/media` and `datapool/media-private` (temporary root access for file transfer, needs hardening) |

---

### Mobile Travel Network — BUILT
| Component | Detail |
|-----------|--------|
| Router | GL.iNet AX1800 (Flint) — WireGuard profiles for Proton VPN |
| Power | EcoFlow River Pro 2 |
| Camera | Reolink (connected to travel WiFi) |
| Streaming | Roku (connected to travel WiFi) |
| VPN | Proton VPN via WireGuard (manual profiles) |
| Home tunnel | Not yet configured — planned via Tailscale on GL.iNet |

**Use cases:** Hotel/Airbnb WiFi security, portable surveillance, geo-flexible streaming, remote lab access (planned).

---

### Node 2: Cortana (Future Proxmox Node) — WINDOWS (Reolink NVR only)
| Component | Spec |
|-----------|------|
| CPU | Intel Core i7-6700 (4C/8T) |
| RAM | 16GB DDR4 |
| Storage | 1TB Samsung EVO SSD + 4TB WD Red HDD |
| Current Role | Windows — Reolink NVR (underutilized) |
| Future Role | Proxmox node — NVR + additional services |

### Node 3: Hal (Future Proxmox Node) — OFFLINE/STAGING
| Component | Spec |
|-----------|------|
| CPU | Intel Core i5-4440 (4C/4T) |
| RAM | 16GB DDR3 |
| GPU | GTX 1050 |
| Current Role | Idle |
| Future Role | GPU passthrough node (Plex transcode, lightweight AI/ML) |

---

## Build Log — March 1, 2026

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
- Installed Plex Media Server from official repo
- Accessed web UI at http://192.168.50.12:32400/web
- Linked Plex account (lifetime pass)
- **Disabled remote access / UPnP** — will use Tailscale or Cloudflare Tunnel instead
- Libraries configured: Movies → /media/movies, TV → /media/tv, Music → /media/music

### 5. SMB File Sharing (Temporary)
- Installed Samba on Proxmox host
- Configured shares: `[media]` → /datapool/media, `[private-media]` → /datapool/media-private
- Set root smbpasswd for file transfer
- **IN PROGRESS:** ~2TB media transfer from gaming PC (~3 hours ETA)
- **TODO:** Create non-root Samba user, disable root SMB access after transfer

### 6. SSH Hardening
- Created non-root user `rafy` with sudo access
- Generated Ed25519 SSH key on gaming PC
- Copied public key to Proxmox via ssh-copy-id
- Disabled root SSH login (PermitRootLogin no)
- Configured SSH shortcut on gaming PC (~/.ssh/config → `ssh proxmox-n3`)
- Deployed custom bashrc with figlet banner + rainbow system info MOTD

### 7. System Maintenance
- Disabled pve-enterprise.sources and ceph.sources (renamed to .disabled)
- Added pve-no-subscription.list
- Git installed and configured on gaming PC
- SSH keys (Ed25519) generated on gaming PC
- DHCP reservation created on Asus router for proxmox-n3 (192.168.50.10)

---

## IP Address Map

| IP | Hostname | Role |
|----|----------|------|
| 192.168.50.1 | — | Router (Asus GS-AX5400) |
| 192.168.50.10 | proxmox-n3 | Proxmox hypervisor |
| 192.168.50.11 | tailscale | Tailscale subnet router (LXC 100) |
| 192.168.50.12 | plex | Plex Media Server (LXC 101) |
| 192.168.50.13 | — | Reserved: Home Assistant (planned) |
| 192.168.50.14 | — | Reserved: AdGuard / Pi-hole (planned) |
| 192.168.50.15 | — | Reserved: Cloudflare Tunnel (planned) |
| 192.168.50.16 | — | Reserved: Docker/Portainer (planned) |
| 192.168.50.20 | — | Reserved: Cortana (future node) |
| 192.168.50.21 | — | Reserved: Hal (future node) |

---

## Use Cases — Full Inventory

### Priority 1 — Active / In Progress
| Use Case | Status | Service | Platform |
|----------|--------|---------|----------|
| Media server | 🔄 In progress (files transferring) | Plex (Jellyfin backup) | LXC 101 |
| Secure remote access | ✅ Done | Tailscale subnet router | LXC 100 |

### Priority 2 — Next Up
| Use Case | Status | Service | Platform |
|----------|--------|---------|----------|
| Home automation | Planned | Home Assistant | VM (planned) |
| Surveillance | Running on Cortana | Reolink NVR → Blue Iris/Frigate | VM (planned) |

### Priority 3 — Medium Term
| Use Case | Status | Service | Platform |
|----------|--------|---------|----------|
| Email aggregation | Planned | Stalwart/Fetchmail + Roundcube | Docker (planned) |
| Docker playground | Planned | Docker + Portainer | VM (planned) |
| DNS ad blocking | Planned | AdGuard Home | LXC (planned) |
| Family service access | Planned | Cloudflare Tunnels | LXC (planned) |

### Priority 4 — Future Projects
| Use Case | Status | Service | Platform |
|----------|--------|---------|----------|
| Asset tracking (cars, dogs, equipment) | Idea | Traccar | Docker (planned) |
| Round-up savings automation | Idea | Custom (Python + Plaid API + Firefly III) | Docker (planned) |
| Password manager | Idea | Vaultwarden | Docker (planned) |
| Wiki / documentation | Idea | BookStack or Outline | Docker (planned) |
| Dashboard | Idea | Homepage or Heimdall | Docker (planned) |
| Monitoring | Idea | Uptime Kuma + Grafana | Docker (planned) |

---

## Suggested Build Order (Revised)

### Phase 1 — Quick Wins ← YOU ARE HERE
1. ✅ Fresh Proxmox VE 9.1 install on NVMe
2. ✅ ZFS mirror pool (datapool) on 12TB HDDs with dataset structure
3. ✅ Tailscale subnet router (LXC 100) — remote access working
4. 🔄 Media transfer from gaming PC (in progress, ~3 hours)
5. ✅ Plex configured, updated, libraries scanning as files arrive
6. ✅ Set Plex LXC to onboot=1
7. ✅ SSH hardened — created rafy user, root SSH disabled, Ed25519 key auth
8. ✅ SSH config shortcut on gaming PC (`ssh proxmox-n3`)
9. ✅ Custom bashrc deployed (figlet banner + rainbow system info)
10. ✅ DHCP reservation for proxmox-n3 (.10) on router
11. ⬜ Harden SMB: create non-root user, disable root Samba access (after transfer completes)
12. ⬜ Set BIOS "Restore on AC Power Loss" → Power On (after transfer completes, requires reboot)
13. ⬜ Configure GL.iNet travel router Tailscale profile for home lab access
14. ⬜ Enable Plex remote streaming via Tailscale (for Roku on travel network)

### Phase 2 — Core Infrastructure (Weeks 2-4)
11. Deploy Home Assistant VM + add lights and door sensors
12. Deploy AdGuard Home (LXC) for DNS + ad blocking
13. Deploy Docker VM with Portainer (platform for future services)
14. Set up Cloudflare Tunnel for family-facing services (Plex, HA)
15. Begin automated ZFS snapshots (backup layer 1)

### Phase 3 — Network Segmentation (Weeks 4-8)
16. Purchase UDR7 + 2× U7 Lite
17. Replace Asus router, deploy APs with Cat6 backhaul
18. Create VLANs: Management, Trusted, Lab, IoT, Surveillance, Guest
19. Isolate IoT devices, reconnect Alexas on restricted VLAN
20. Isolate cameras on surveillance VLAN

### Phase 4 — Node Expansion (Weeks 8-12)
21. Convert Cortana to Proxmox node, migrate Reolink NVR to VM
22. Set up cross-node ZFS replication (proxmox-n3 → Cortana)
23. Evaluate Hal for GPU passthrough (Plex transcode, AI/ML)
24. Deploy Blue Iris or Frigate for AI-powered surveillance

### Phase 5 — Advanced Services (Ongoing)
25. Email aggregation server
26. Asset tracking (Traccar)
27. Monitoring stack (Uptime Kuma, Grafana)
28. Password manager (Vaultwarden)
29. Wiki (BookStack / Outline)
30. Round-up savings automation (custom build)
31. Offsite backup (Backblaze B2 / Cloudflare R2)

---

## Security Hardening Checklist
- [x] Created non-root user (rafy) on Proxmox for SSH
- [x] Root SSH disabled, Ed25519 key auth configured
- [x] Tailscale for remote access (no open ports)
- [x] Plex remote access / UPnP disabled
- [x] DHCP reservation for proxmox-n3 on router
- [ ] Create non-root Samba user, disable root SMB access (after transfer)
- [ ] BIOS: Restore on AC Power Loss → Power On (after transfer, requires reboot)
- [ ] VLANs for IoT and camera isolation (after UDR7)
- [ ] fail2ban on Proxmox host
- [ ] Automated ZFS scrubs and SMART monitoring
- [ ] Lab config Git repo initialized

---

## Open TODO
- [ ] Complete media file transfer (in progress)
- [ ] Harden SMB — create non-root user, disable root access (after transfer)
- [ ] Set BIOS "Restore on AC Power Loss" → Power On (after transfer, requires reboot)
- [ ] Configure GL.iNet travel router Tailscale profile for home lab access
- [ ] Enable Plex streaming on Roku via Tailscale when traveling
- [ ] Initialize Git repo for lab configs
- [ ] Inventory all IoT devices (lights, sensors, Alexa units, cameras)
- [ ] Consider dedicated Tailscale device (RPi) for always-on remote access independent of Proxmox
- [ ] Clean up accidental SSH config file on Proxmox rafy home dir

---

*Document version: 2.1 — March 1, 2026 (end of session 1)*
*Lab domain: torres-core.us*
*Architecture partner: Claude (Anthropic)*
