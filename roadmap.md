# Torres-Core — Roadmap

> **Back to index:** [README.md](./README.md)

---

## Phase Status

| Phase | Status | Summary |
|-------|--------|---------|
| Phase 1 — Quick Wins | ✅ Complete | Proxmox, ZFS, Tailscale, Plex, SSH hardening, travel network |
| Phase 2 — Core Infrastructure | 🔄 In progress | HA, AdGuard, Sanoid, Docker, media stack, mesh network |
| Phase 3 — Network Segmentation | ⬜ Planned | UDR7, VLANs, reverse proxy, Cloudflare Tunnel |
| Phase 4 — Node Expansion | ⬜ Planned | Cortana + Hal, NVR migration, ZFS replication |
| Phase 5 — Advanced Services | ⬜ Ongoing | Email, monitoring, Vaultwarden, AI agents |

---

## Open TODOs

### Phase 2 — proxmox-n3 (Current)

**Media stack:**
- [ ] Bazarr: create English language profile and assign to all series/movies — subtitle searches aren't triggering until this is done
- [ ] Sonarr: check language profile — searching Spanish titles first for some shows
- [ ] Anime: configure as separate root folder in Sonarr with its own quality profile

**Home Assistant:**
- [ ] Add WiFi devices (smart plugs, bulbs, thermostat)
- [ ] Pair remaining Zigbee devices
- [ ] Build automations — door sensors → push notifications for Rafy + wife
- [ ] DHCP reservation for .13 on router

**Infrastructure:**
- [ ] Set up SSH key for Docker VM → GitHub (direct git operations from server)
- [ ] Clean up accidental SSH config file on Proxmox `rafy` home dir
- [ ] Revolt self-hosted deployment on Docker VM (see `revolt-deployment-plan.docx`)

**Mesh network (Buffalo Community Mesh):**
- [ ] Flash Node 1 (relay) with Meshtastic firmware — place at best available elevated location
- [ ] Flash Node 2 (mobile A) with Meshtastic firmware — pair to phone, test with Meshtastic app
- [ ] Flash Node 3 (mobile B) with Meshtastic firmware — pair to second volunteer phone
- [ ] Test end-to-end: mobile node → relay → home node message relay
- [ ] Confirm antenna adapter (SMA Male → RP-SMA Female) — check KMR195 cable end before ordering
- [ ] Mount 5.8dBi fiberglass antenna for Node 0 (currently unconnected)
- [ ] Add AdGuard DNS rewrite for Nomad Network if exposing on LAN

**Deferred:**
- [ ] Cloudflare Tunnel — deferred to Phase 3
- [ ] Sanoid restore test — verify a dataset can actually be restored from snapshot

### Phase 4 — Cortana

- [ ] Back up and document Reolink NVR config (camera IPs, stream URLs) before wiping Windows
- [ ] Install Proxmox VE on 1TB Samsung EVO SSD
- [ ] ZFS pool on 4TB WD Red: `survpool` (surveillance, backups datasets)
- [ ] SSH hardening to match n3 baseline
- [ ] Deploy Tailscale backup LXC (200) — enable subnet failover in Tailscale admin
- [ ] Deploy AdGuard secondary LXC (201) — configure AdGuard Home Sync from n3
- [ ] Update router DHCP: add `192.168.50.22` as secondary DNS
- [ ] Deploy Reolink NVR Windows VM (202) — VirtIO-fs surveillance mount
- [ ] Configure ZFS replication: n3 → cortana via Sanoid/Syncoid
- [ ] Add cortana DNS rewrites to AdGuard primary

### Phase 4 — Hal

- [ ] Install 4TB Barracuda (from gaming PC) into Hal
- [ ] Install Proxmox VE, configure GPU passthrough for GTX 1050
- [ ] Configure Wake-on-LAN
- [ ] Assign static IP: 192.168.50.21

---

## Phase Detail

### Phase 1 — Quick Wins ✅ Complete

1. ✅ Fresh Proxmox VE 9.1 install on NVMe
2. ✅ ZFS mirror pool (`datapool`) on 12TB HDDs with dataset structure
3. ✅ Tailscale subnet router LXC 100 — remote access working
4. ✅ ~2TB media transfer from gaming PC — complete
5. ✅ Plex LXC 101 — configured, libraries scanning, onboot=1
6. ✅ SSH hardening — `rafy` user, root SSH disabled, Ed25519 keys
7. ✅ Figlet + rainbow MOTD on all nodes
8. ✅ DHCP reservation proxmox-n3 (.10)
9. ✅ SMB hardened — `mediauser`, root Samba removed
10. ✅ BIOS: Restore on AC Power Loss → Power On
11. ✅ GL.iNet Tailscale — split tunnel, Plex on Roku via Tailscale verified

### Phase 2 — Core Infrastructure 🔄 In Progress

1. ✅ Home Assistant OS VM 102 — ZHA + ZBDongle-P, door sensors paired
2. ✅ AdGuard Home LXC 103 — DoH, blocklists, DNS rewrites, router cutover
3. ✅ Sanoid ZFS snapshots — all datasets covered, timer active
4. ✅ Docker VM 104 — Debian 13, Docker 29.3.0, Portainer CE
5. ✅ VirtIO-fs mounts — appdata + media in VM, persists on reboot
6. ✅ Cloud-init template VM 9000 — clone workflow verified (~60s to SSH)
7. ✅ Media automation stack — WireGuard VPN, full *arr pipeline verified
8. ✅ Mesh stack Node 0 — Heltec LoRa32 V3, RNode 1.85, Reticulum + Nomad Network live
9. ⬜ Mesh stack Nodes 1–3 — Meshtastic relay + mobile nodes
10. ⬜ Home Assistant: WiFi devices, automations, remaining Zigbee devices
11. ⬜ Cloudflare Tunnel (deferred to Phase 3)

### Phase 3 — Network Segmentation ⬜ Planned

1. Purchase UDR7 + 2× U7 Lite
2. Replace Asus router, deploy APs with Cat6 backhaul
3. Create VLANs: Management, Trusted, Lab, IoT, Surveillance, Guest
4. Deploy reverse proxy on Docker VM (Nginx Proxy Manager or Caddy)
5. Isolate IoT devices — Alexas + smart devices on IoT VLAN
6. Isolate cameras on Surveillance VLAN (prerequisite for Frigate)
7. VLAN-isolate media automation stack (torrent traffic)
8. Deploy Cloudflare Tunnel for external service access

### Phase 4 — Node Expansion ⬜ Planned

1. Cortana → `proxmox-cortana`: base install, storage, SSH, Tailscale LXC, AdGuard LXC, Reolink NVR VM, ZFS replication from n3
2. Hal → `proxmox-hal`: Proxmox install, GTX 1050 GPU passthrough, Wake-on-LAN
3. Frigate LXC 203 on Cortana — after Phase 3 VLANs, HA integration, evaluate Coral USB accelerator

### Phase 5 — Advanced Services ⬜ Ongoing

| Service | Tool | Notes |
|---------|------|-------|
| Email aggregation | Stalwart + Roundcube | Consolidate personal email accounts |
| Asset tracking | Traccar | Cars, dogs, equipment |
| Monitoring | Uptime Kuma + Grafana | Service health, ZFS metrics |
| Password manager | Vaultwarden | Self-hosted Bitwarden |
| Wiki | BookStack or Outline | Internal documentation |
| Dashboard | Homepage or Heimdall | Lab service launcher |
| Round-up savings | Python + Plaid API + Firefly III | Custom agent build |
| Offsite backup | Backblaze B2 or Cloudflare R2 | Automated script |
| Media transcoding | Tdarr | Needs Hal online |
| Mesh node expansion | Meshtastic + Reticulum | Seneca One Tower, building nodes, truck node |
| Mesh spine | LoRa long-haul | Buffalo → Cincinnati → Franklin TN (long-term) |

---

## Services — Full Status

| Use Case | Status | Service | Where |
|----------|--------|---------|-------|
| Media server | ✅ Running | Plex | LXC 101 |
| Remote access | ✅ Running | Tailscale | LXC 100 |
| DNS blocking | ✅ Running | AdGuard Home | LXC 103 |
| Travel network | ✅ Running | Tailscale + GL.iNet | GL.iNet |
| Home automation | 🔄 Partial | Home Assistant | VM 102 |
| ZFS snapshots | ✅ Running | Sanoid | proxmox-n3 host |
| Docker platform | ✅ Running | Docker + Portainer | VM 104 |
| Media automation | ✅ Running | qBit + *arr + VPN | VM 104 |
| Mesh backbone | ✅ Running | Reticulum + RNode | VM 104 |
| Mesh BBS | ✅ Running | Nomad Network | VM 104 |
| Mesh relay node | ⬜ Pending | Meshtastic | Node 1 (to deploy) |
| Mesh mobile nodes | ⬜ Pending | Meshtastic | Nodes 2 + 3 |
| Reverse proxy | ⬜ Planned | NPM or Caddy | VM 104 |
| VLANs | ⬜ Phase 3 | UDR7 + EdgeSwitch | Network |
| Cloudflare Tunnel | ⬜ Phase 3 | cloudflared | LXC (planned) |
| Email | ⬜ Phase 5 | Stalwart | Docker |
| Surveillance NVR | ⬜ Phase 4 | Reolink NVR | VM 202 (Cortana) |
| AI surveillance | ⬜ Phase 4/5 | Frigate | LXC 203 (Cortana) |
| DNS redundancy | ⬜ Phase 4 | AdGuard Sync | LXC 201 (Cortana) |
| ZFS replication | ⬜ Phase 4 | Syncoid | n3 → Cortana |
| GPU workloads | ⬜ Phase 4 | Tdarr / ML | proxmox-hal |
| Revolt chat | ⬜ Planned | Revolt | VM 104 |
| Monitoring | ⬜ Phase 5 | Uptime Kuma + Grafana | Docker |
| Vaultwarden | ⬜ Phase 5 | Vaultwarden | Docker |
| AI agents | ⬜ Phase 5 | CrewAI + Ollama | See ai-agents.md |

---

*Last updated: March 14, 2026*
