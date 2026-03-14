# Torres-Core — Network

> **Back to index:** [README.md](./README.md)

---

## Current Setup

| Component | Detail |
|-----------|--------|
| Router | Asus GS-AX5400 (Wi-Fi 6) |
| Switch | Ubiquiti EdgeSwitch 8 150W (802.1Q VLAN-capable, PoE+ all ports) |
| Subnet | `192.168.50.0/24` |
| Gateway | `192.168.50.1` |
| DNS (primary) | `192.168.50.14` (AdGuard Home, LXC 103) |
| DNS (secondary) | `192.168.50.22` (planned — AdGuard on Cortana) |
| VLANs | Not yet configured — deferred until UDR7 |
| Firewall | Router-level only |

---

## Planned Network Upgrade (Phase 3)

| Component | Detail | Cost |
|-----------|--------|------|
| Router/Gateway | Ubiquiti UDR7 (Wi-Fi 7, IDS/IPS, full VLAN management) | $279 |
| AP × 2 | Ubiquiti U7 Lite (Wi-Fi 7, PoE, ceiling mount) | $198 |
| Cat6 backhaul | Flat runs to each AP location | ~$30 |
| Switch | EdgeSwitch 8 150W (already owned, powers APs via PoE+) | $0 |
| **Total** | | **~$507** |

VLANs are a pure software config on UDR7 + EdgeSwitch — no physical changes required once the UDR7 is in place. Large house with thick walls = two U7 Lites confirmed.

**Planned VLANs:**

| VLAN | Name | Purpose |
|------|------|---------|
| 10 | Management | Proxmox UIs, switches, APs |
| 20 | Trusted | Daily use devices, gaming PC, laptop |
| 30 | Lab | All Proxmox VMs/CTs, lab services |
| 40 | IoT | Alexas, smart plugs, bulbs, thermostats |
| 50 | Surveillance | Cameras — isolated, no internet access |
| 60 | Guest | Guest WiFi, isolated |

---

## DNS — AdGuard Home

Full configuration documented in [services.md](./services.md).

**Key facts:**
- All lab hostnames resolve via `*.torres-core.us` DNS rewrites
- DoH upstreams (Cloudflare + Quad9) — ISP cannot see DNS queries
- Router DHCP pushes `.14` as DNS to all clients
- Secondary at `.22` (Cortana) planned for failover

---

## Remote Access — Tailscale

Tailscale is the primary remote access method — zero open ports on the router.

**Devices on tailnet:**
- Android phone
- Gaming PC
- Laptop
- GL.iNet AX1800 travel router
- LXC 100 (subnet router, n3) — advertises `192.168.50.0/24`
- LXC 200 (subnet router, cortana — planned backup)

Any tailnet device can reach any `192.168.50.x` IP directly. Subnet route is approved in the Tailscale admin panel.

**Planned:** Enable subnet failover in Tailscale admin once LXC 200 (Cortana) is online — two devices advertising the same subnet requires explicit failover mode.

---

## Remote Access — Cloudflare

Domain `torres-core.us` is registered and pointed at Cloudflare. No tunnels configured yet.

Cloudflare Tunnel is planned for Phase 3 to expose selected services externally (Seerr, HA, Revolt) without opening router ports or exposing home IP. A dedicated LXC at `.15` is reserved for the tunnel container.

---

## Reverse Proxy (Planned — Phase 3)

Currently all services are accessed with explicit ports (`:8989`, `:7878`, etc.). A reverse proxy (Nginx Proxy Manager or Caddy) on the Docker VM will clean this up to bare hostnames.

Not deployed yet — blocked on Phase 3 network segmentation.

---

## Travel Network

| Component | Detail |
|-----------|--------|
| Router | GL.iNet AX1800 (Flint) — Tailscale client |
| Power | EcoFlow River Pro 2 |
| Camera | Reolink (connected to travel WiFi) |
| Streaming | Roku (connected to travel WiFi) |
| VPN | ProtonVPN via WireGuard (manual profiles on GL.iNet) |
| Local DNS | AdGuard Home built-in on GL.iNet (local ad blocking — no home hop) |
| Home tunnel | Tailscale split tunnel → `192.168.50.0/24` via LXC 100 |

**Verified:** Roku on travel WiFi discovers and streams Plex at `192.168.50.12` via Tailscale tunnel. No manual configuration needed at the destination.

**TODO:** Add Tailscale WireGuard profile to GL.iNet for home lab access (currently using ProtonVPN profile slots).

---

*Last updated: March 14, 2026*
