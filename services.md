# Torres-Core — Services

> **Back to index:** [README.md](./README.md)

---

## Tailscale — Remote Access (LXC 100)

| Setting | Value |
|---------|-------|
| Host | proxmox-n3, LXC 100 |
| IP | `192.168.50.11` |
| Type | Privileged Debian 12 LXC |
| Advertised subnet | `192.168.50.0/24` |
| Access | `pct enter 100` — no SSH (minimal attack surface) |

Tailscale is the primary remote access layer — no open ports on the router. The LXC advertises the entire home subnet so all tailnet devices (phone, gaming PC, laptop, GL.iNet travel router) can reach any local IP.

Backup subnet router planned on Cortana (LXC 200) — requires enabling subnet failover in the Tailscale admin panel once both are active.

---

## Plex Media Server (LXC 101)

| Setting | Value |
|---------|-------|
| Host | proxmox-n3, LXC 101 |
| IP | `192.168.50.12` |
| Type | Privileged Debian 12 LXC |
| Web UI | http://plex.torres-core.us:32400/web |
| SSH | `ssh plex` |
| Media root | `/media` (bind mount → `datapool/media`) |

Libraries: Movies → `/media/movies`, TV → `/media/tv`, Music → `/media/music`

Remote access and UPnP are **disabled** — remote access goes through Tailscale or (future) Cloudflare Tunnel only.

Plex account: lifetime pass linked. ~2TB media transferred from gaming PC.

---

## Home Assistant OS (VM 102)

| Setting | Value |
|---------|-------|
| Host | proxmox-n3, VM 102 |
| IP | `192.168.50.13` |
| Type | HAOS 14.2 (q35, OVMF BIOS) |
| Web UI | http://homeassistant.torres-core.us:8123 |
| Zigbee | Sonoff ZBDongle-P via USB passthrough (CP210x, ID 10c4:ea60) |
| Integration | ZHA — coordinator TI CC2652P |

**Status:** Installed, door sensors paired via Zigbee.

**Pending:**
- WiFi devices (smart plugs, bulbs, thermostat)
- Remaining Zigbee device pairing
- Automations (door sensors → push notifications, lights)
- DHCP reservation for .13 on router
- Push notifications configured for Rafy + wife via companion app

---

## AdGuard Home — DNS (LXC 103)

| Setting | Value |
|---------|-------|
| Host | proxmox-n3, LXC 103 |
| IP | `192.168.50.14` |
| Type | Unprivileged Debian 12 LXC |
| Web UI | http://adguard.torres-core.us:3000 |
| SSH | `ssh adguard` |
| Version | v0.107.72 |

| Config | Value |
|--------|-------|
| Upstream DNS | Cloudflare DoH + Quad9 DoH (parallel requests) |
| Bootstrap DNS | `1.1.1.1`, `9.9.9.9` |
| Blocklists | AdGuard DNS filter, OISD Full, HaGeZi Multi Pro |
| Block rate | ~24% (day 1) |
| Router DHCP | Pushes `192.168.50.14` as primary DNS to all clients |
| Router WAN DNS | Pointed at `192.168.50.14` |

**DNS Rewrites:**

| Hostname | IP |
|----------|----|
| `proxmox-n3.torres-core.us` | 192.168.50.10 |
| `plex.torres-core.us` | 192.168.50.12 |
| `homeassistant.torres-core.us` | 192.168.50.13 |
| `adguard.torres-core.us` | 192.168.50.14 |
| `docker.torres-core.us` | 192.168.50.16 |
| `portainer.torres-core.us` | 192.168.50.16 |
| `proxmox-cortana.torres-core.us` | 192.168.50.20 |
| `adguard-cortana.torres-core.us` | 192.168.50.22 |
| `reolink-nvr.torres-core.us` | 192.168.50.24 |
| `frigate.torres-core.us` | 192.168.50.25 |

Secondary AdGuard instance planned on Cortana (LXC 201, .22) — synced via AdGuard Home Sync from primary.

---

## Docker VM — Engine + Portainer (VM 104)

| Setting | Value |
|---------|-------|
| Host | proxmox-n3, VM 104 |
| IP | `192.168.50.16` |
| Type | Debian 13 (trixie) VM |
| SSH | `ssh docker` |
| Docker | Engine 29.3.0 |
| Portainer | CE, https://docker.torres-core.us:9443 |

**VirtIO-fs mounts (from Proxmox host):**

| Mount tag | VM path | Source |
|-----------|---------|--------|
| `appdata` | `/mnt/appdata` | `datapool/appdata` |
| `media` | `/mnt/media` | `datapool/media` |

Both entries in `/etc/fstab` for persistence. Ownership set from Proxmox host (`chown -R 1000:1000`) — do not run chown from inside the VM.

**Services running on this VM:** See [media-stack.md](./media-stack.md) for the full stack.

**Planned:** Revolt self-hosted chat (see `revolt-deployment-plan.docx`), reverse proxy (Nginx Proxy Manager or Caddy).

---

## Samba — File Shares (Proxmox Host)

| Share | Path | Access |
|-------|------|--------|
| `media` | `/datapool/media` | `mediauser` only |
| `private-media` | `/datapool/media-private` | `mediauser` only |

Root Samba access removed. Gaming PC has M: → media, P: → private-media mapped.

---

*Last updated: March 14, 2026*
