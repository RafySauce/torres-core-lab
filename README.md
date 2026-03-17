# Torres-Core Home Lab

> **Domain:** `torres-core.us` · **Subnet:** `192.168.50.0/24` · **Gateway:** `192.168.50.1`
> **Primary node:** `proxmox-n3` at `192.168.50.10` · **Proxmox UI:** https://192.168.50.10:8006

---

## Documentation

| Doc | What's in it |
|-----|-------------|
| [infrastructure.md](./infrastructure.md) | Node specs, ZFS storage layout, VM/CT inventory |
| [services.md](./services.md) | Plex, Home Assistant, AdGuard Home, Tailscale, Portainer |
| [network.md](./network.md) | DNS rewrites, remote access, VLAN plan, travel kit |
| [media-stack.md](./media-stack.md) | WireGuard VPN, qBittorrent, Sonarr, Radarr, Prowlarr, Bazarr, Seerr |
| [mesh.md](./mesh.md) | LoRa mesh network — Reticulum, RNode, Heltec nodes, Sideband, Buffalo deployment |
| [security.md](./security.md) | Hardening checklist, SSH config, kill switch rules |
| [runbooks.md](./runbooks.md) | Build log, clone workflow, key gotchas, recovery procedures |
| [roadmap.md](./roadmap.md) | Phase plan, open TODOs, priorities |
| [hardware.md](./hardware.md) | Physical inventory, Cortana/Hal migration plan |
| [ai-agents.md](./ai-agents.md) | CrewAI, Ollama, workflow engine design |

---

## IP Address Map

| IP | Hostname | Role |
|----|----------|------|
| `192.168.50.1` | — | Router (Asus GS-AX5400) |
| `192.168.50.10` | `proxmox-n3` | Proxmox primary hypervisor |
| `192.168.50.11` | `tailscale` | Tailscale subnet router — primary (LXC 100) |
| `192.168.50.12` | `plex` | Plex Media Server (LXC 101) |
| `192.168.50.13` | `homeassistant` | Home Assistant OS (VM 102) |
| `192.168.50.14` | `adguard` | AdGuard Home — primary DNS (LXC 103) |
| `192.168.50.15` | — | Reserved: Cloudflare Tunnel (planned) |
| `192.168.50.16` | `docker` | Docker VM — media stack + Portainer (VM 104) |
| `192.168.50.20` | `proxmox-cortana` | Proxmox secondary node (Phase 4, planned) |
| `192.168.50.21` | `proxmox-hal` | Proxmox GPU node (Phase 4, planned) |
| `192.168.50.22` | `adguard-cortana` | AdGuard Home — secondary DNS (planned) |
| `192.168.50.23` | `tailscale-cortana` | Tailscale subnet router — backup (planned) |
| `192.168.50.24` | `reolink-nvr` | Reolink NVR Windows VM (planned) |
| `192.168.50.25` | `frigate` | Frigate AI NVR (future) |

---

## Service Quick Reference

| Service | URL | Host |
|---------|-----|------|
| Proxmox UI | https://192.168.50.10:8006 | proxmox-n3 |
| Plex | http://plex.torres-core.us:32400/web | LXC 101 |
| Home Assistant | http://homeassistant.torres-core.us:8123 | VM 102 |
| AdGuard Home | http://adguard.torres-core.us:3000 | LXC 103 |
| Portainer | https://docker.torres-core.us:9443 | VM 104 |
| qBittorrent | http://docker.torres-core.us:8080 | VM 104 |
| Sonarr | http://docker.torres-core.us:8989 | VM 104 |
| Radarr | http://docker.torres-core.us:7878 | VM 104 |
| Prowlarr | http://docker.torres-core.us:9696 | VM 104 |
| Bazarr | http://docker.torres-core.us:6767 | VM 104 |
| Seerr | http://docker.torres-core.us:5055 | VM 104 |
| Reticulum TCP | 192.168.50.16:4242 | VM 104 (rnsd container) |
| Nomad BBS | via Sideband or rnsd TCP | VM 104 (nomadnet container) |

---

## SSH Shortcuts

```bash
ssh proxmox-n3   # 192.168.50.10 — Proxmox host
ssh plex         # 192.168.50.12 — Plex LXC
ssh adguard      # 192.168.50.14 — AdGuard LXC
ssh docker       # 192.168.50.16 — Docker VM
```

All nodes: `rafy` user, Ed25519 key auth, root SSH disabled.

---

## Current Phase

**Phase 2 — Core Infrastructure** (active)

Phase 1 ✅ · Phase 2 🔄 · Phase 3 (network/VLANs) ⬜ · Phase 4 (Cortana + Hal) ⬜ · Phase 5 (advanced services) ⬜

See [roadmap.md](./roadmap.md) for open TODOs and phase details.

---

## Repo

```bash
# Session close routine
git add -A && git commit -m "Session notes: <brief description>" && git push
```

`RafySauce/torres-core-lab` — architecture docs, compose files, cloud-init configs, scripts.

---

*Last updated: March 17, 2026 — v10.0*
