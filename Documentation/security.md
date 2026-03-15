# Torres-Core — Security

> **Back to index:** [README.md](./README.md)

---

## Hardening Checklist

### proxmox-n3 — ✅ Complete

- [x] Non-root user `rafy` created on Proxmox host with sudo
- [x] Root SSH disabled (`PermitRootLogin no`) on all nodes
- [x] Ed25519 key auth — password auth not used
- [x] Tailscale for remote access — zero open router ports
- [x] Plex remote access + UPnP disabled — access via Tailscale only
- [x] DHCP reservation for proxmox-n3 (.10) on router
- [x] Plex LXC (101): `rafy` user, root SSH disabled, key auth only
- [x] Tailscale LXC (100): no SSH server — `pct enter 100` only
- [x] AdGuard LXC (103): `rafy` user, root SSH disabled, sudo installed
- [x] Docker VM (104): `rafy` user, root SSH disabled, key auth only
- [x] Sudoers: `rafy` has passwordless access to `pct`, `qm`, `pvesm` only
- [x] SMB: `mediauser` created, root Samba access removed
- [x] BIOS: "Restore on AC Power Loss" → Power On
- [x] AdGuard: DNS-over-HTTPS upstreams (ISP cannot see DNS queries)
- [x] OS-level WireGuard kill switch on Docker VM (torrent stack)
- [x] ProtonVPN NAT-PMP port forwarding renewal script running

### proxmox-cortana — ⬜ Planned (Phase 4)

- [ ] BIOS: "Restore on AC Power Loss" → Power On
- [ ] `rafy` user, root SSH disabled, Ed25519 key auth
- [ ] Tailscale LXC 200: no SSH server — `pct enter` only
- [ ] AdGuard Sync: verify blocklists + DNS rewrites stay in sync with primary
- [ ] Reolink NVR VM (202): Proxmox watchdog enabled, no direct internet access
- [ ] `survpool/surveillance`: local only, not exposed over SMB
- [ ] Cameras: move to surveillance VLAN after UDR7 (Phase 3 prerequisite for Frigate)

### Network — ⬜ Planned (Phase 3+)

- [ ] VLANs for IoT and camera isolation (after UDR7)
- [ ] Reverse proxy for clean internal hostnames
- [ ] `fail2ban` on Proxmox host (both nodes)
- [ ] Automated ZFS scrubs and SMART monitoring (both nodes)
- [ ] Cloudflare Tunnel for external service access (no open ports)

---

## SSH Configuration

All nodes follow the same baseline:

```
User: rafy
Auth: Ed25519 key only (password auth disabled)
Root SSH: disabled (PermitRootLogin no)
```

**Gaming PC `~/.ssh/config` shortcuts:**

```
Host proxmox-n3
  HostName 192.168.50.10
  User rafy

Host plex
  HostName 192.168.50.12
  User rafy

Host adguard
  HostName 192.168.50.14
  User rafy

Host docker
  HostName 192.168.50.16
  User rafy
```

**Tailscale LXC (100) has no SSH.** Access only via `pct enter 100` from the Proxmox host. Minimal attack surface — no shell exposure needed.

---

## WireGuard Kill Switch (Docker VM 104)

The Docker VM runs an OS-level WireGuard kill switch to ensure torrent traffic never leaks outside the VPN tunnel. Config lives in `/etc/wireguard/wg0.conf`.

**PostUp rules (applied when tunnel comes up):**

```bash
# Block all non-VPN output except explicitly allowed traffic
iptables -I OUTPUT ! -o wg0 -m mark ! --mark 0xca6c -m addrtype ! --dst-type LOCAL -j REJECT

# Exceptions: LAN, docker bridge, VPN gateway
iptables -I OUTPUT -d 192.168.50.0/24 -j ACCEPT
iptables -I OUTPUT -o docker+ -j ACCEPT
iptables -I OUTPUT -d 10.2.0.1/32 -j ACCEPT

# Allow Docker container traffic through FORWARD chain
iptables -I FORWARD -i docker+ -j ACCEPT
iptables -I FORWARD -o docker+ -j ACCEPT
```

**PreDown rules** mirror PostUp with `-D` (delete) in reverse order.

> **Why the FORWARD chain matters:** A kill switch that only locks down `OUTPUT` will silently break Docker container access to the host IP. Container → host traffic routes through `FORWARD`, not `OUTPUT`. Both chains need explicit docker+ exceptions.

**Watchdog:** `wg-watchdog.timer` runs every 30 seconds via systemd, using `wg-up.sh` / `wg-down.sh` wrappers to detect and recover from tunnel drops.

**Port forwarding:** NAT-PMP via `proton-port-forward.sh` renewal script — qBittorrent listening port is set dynamically. Do not manually change it in qBit settings.

---

## Credentials & Secrets Policy

- WireGuard private keys and VPN credentials live in `.env` on the Docker VM — gitignored
- `.env` is never committed to the repo; only `docker-compose.yml` is committed
- Workflows and public docs never contain credentials, internal IPs beyond what's in this repo, or API keys
- Git repo is public — treat everything committed as public

---

## Threat Model Notes

- **No open ports on the router.** All remote access via Tailscale. Cloudflare Tunnel planned for external-facing services.
- **Torrent traffic VPN-isolated.** The Docker VM's kill switch means a VPN drop kills all torrent traffic rather than falling back to the home IP.
- **IoT devices not yet isolated.** Alexas, smart devices share the main subnet until Phase 3 VLANs. Known risk, accepted until UDR7 is in place.
- **Cameras not yet isolated.** Same — surveillance VLAN is a Phase 3 prerequisite for Frigate.
- **Single admin account.** `rafy` is the only non-root user across all nodes. No shared accounts.

---

*Last updated: March 14, 2026*
