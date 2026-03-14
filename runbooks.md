# Torres-Core — Runbooks

> **Back to index:** [README.md](./README.md)

Operational procedures, build history, and hard-won gotchas. The stuff you need when something breaks or when building from scratch.

---

## Common Procedures

### Clone a New VM from Template

```bash
# On proxmox-n3
sudo qm clone 9000 <VMID> --name <hostname> --full
sudo qm set <VMID> --ipconfig0 ip=192.168.50.XX/24,gw=192.168.50.1 --nameserver 192.168.50.14
sudo qm start <VMID>
# SSH-ready in ~60 seconds
```

Template VM 9000 pre-bakes: `rafy` user, Ed25519 SSH key, figlet+rainbow MOTD, `qemu-guest-agent`, root SSH disabled, bashrc pulled from GitHub on first boot.

### Restart a Container

```bash
pct stop 103 && pct start 103   # AdGuard
pct stop 101 && pct start 101   # Plex
pct stop 100 && pct start 100   # Tailscale
```

### Enter a Container (No SSH)

```bash
pct enter 100   # Tailscale LXC — no SSH by design
```

### Check ZFS Snapshot Status

```bash
zfs list -t snapshot | head -30
# Should show snapshots on both datapool and rpool datasets
```

### Restart WireGuard on Docker VM

```bash
ssh docker
sudo systemctl restart wg-quick@wg0
sudo systemctl status wg-watchdog.timer
```

### Check VPN Public IP (Docker VM)

```bash
ssh docker
curl -s https://api.ipify.org
# Should return a Netherlands IP (ProtonVPN)
```

### Check Port Forwarding

```bash
ssh docker
cat /tmp/gluetun/forwarded_port   # if using Gluetun remnants
# Or check proton-port-forward.sh script output in logs
```

### Restart Media Stack

```bash
ssh docker
cd ~/media-stack
docker compose down && docker compose up -d
docker compose ps   # verify all running
```

### Update Plex

```bash
ssh plex
sudo apt update && sudo apt upgrade plexmediaserver
sudo systemctl restart plexmediaserver
```

### SMB Access (Gaming PC → Proxmox)

```
M: → \\192.168.50.10\media        (mediauser credentials)
P: → \\192.168.50.10\private-media
```

### Proxmox Recovery (Locked Out of a VM)

Boot into GRUB, edit kernel line, append `init=/bin/bash`. This drops you into a root shell. Reliable for fixing sudo, user permissions, and password issues. Remount filesystem read-write first: `mount -o remount,rw /`

---

## Session Close Routine

```bash
# On gaming PC, from the torres-core-lab repo directory
git add -A && git commit -m "Session notes: <brief description>" && git push
```

Update the architecture doc version line and last-updated date before committing.

---

## Build Log

### Phase 1 — proxmox-n3 Base (March 1–2, 2026)

1. Wiped previous Proxmox install (couldn't log in after ~1 year)
2. Installed Proxmox VE 9.1 on 2TB Samsung 990 EVO NVMe — ZFS RAID0
3. Disabled enterprise repos, added `pve-no-subscription` repo
4. Wiped old partitions from both 12TB HDDs (`wipefs -a`), created ZFS mirror `datapool`
5. Created full dataset structure under `datapool`
6. Registered storage IDs in Proxmox
7. Created Tailscale LXC 100 — privileged Debian 12, TUN access, IP forwarding enabled
8. Created Plex LXC 101 — privileged Debian 12, `datapool/media` bind-mounted at `/media`
9. Transferred ~2TB media from gaming PC via SMB
10. SSH hardening: `rafy` user, Ed25519 keys, root SSH disabled on host + LXC 101
11. Figlet + rainbow MOTD deployed on all accessible nodes
12. DHCP reservation for proxmox-n3 (.10) on router
13. BIOS: "Restore on AC Power Loss" → Power On
14. SMB hardened: `mediauser` created, root Samba access removed

### Phase 2 — Core Services (March 3–14, 2026)

15. Home Assistant OS VM 102 — HAOS 14.2, q35, OVMF, Sonoff ZBDongle-P USB passthrough, ZHA configured, door sensors paired
16. Travel network — GL.iNet AX1800 on Tailscale, split tunnel verified, Roku streaming Plex confirmed
17. AdGuard Home LXC 103 — DoH upstreams, blocklists, DNS rewrites, router cutover
18. Sanoid ZFS snapshots — `datapool` production template (24h/30d/6m), `rpool` system template (4h/7d/2m), systemd timer active
19. Proxmox host upgraded — 76 packages, kernel 6.17.13-1-pve, AMD microcode
20. Cloud-init template VM 9000 — Debian 13 genericcloud, vendor snippet for baseline config, bashrc from GitHub, ~60s to SSH-ready
21. Docker VM 104 — Debian 13, Docker Engine 29.3.0, Portainer CE, static .16
22. VirtIO-fs mounts — `appdata` at `/mnt/appdata`, `media` at `/mnt/media`, both in fstab
23. Media stack — WireGuard kill switch, qBittorrent, Sonarr, Radarr, Prowlarr, Bazarr, Seerr, FlareSolverr — full pipeline verified

---

## Key Learnings & Gotchas

### Docker Networking

**Container hostnames vs host IP.** Containers on the same Docker bridge network must use container hostnames (`http://sonarr:8989`), not the VM's host IP (`192.168.50.16`). Docker's NAT DNAT rules only apply to traffic arriving from *outside* the bridge — same-network containers bypass DNAT entirely and time out when hitting the host IP.

- ✅ `http://radarr:7878`, `http://sonarr:8989`, `http://prowlarr:9696`
- ❌ `http://192.168.50.16:7878` (times out from within the same network)
- Exception: external hosts (e.g. Plex at `192.168.50.12`) still use IP — the rule only applies within one Docker network
- FlareSolverr URL in Prowlarr requires the full scheme: `http://flaresolverr:8191` (not just `flaresolverr:8191`)

**Docker Compose gotchas:**
- `.env` requires explicit `--env-file .env` flag — not auto-loaded in all contexts
- `${}` interpolation in YAML requires `$${}` escaping
- Anonymous volumes silently override bind mounts — if a service isn't persisting config, check for an anonymous volume conflict

### WireGuard Kill Switch + Docker

A kill switch that only locks down `OUTPUT` will silently break Docker container access to the host IP. Container → host traffic goes through `FORWARD`, not `OUTPUT`. Both chains need docker+ exceptions:

```bash
iptables -I FORWARD -i docker+ -j ACCEPT
iptables -I FORWARD -o docker+ -j ACCEPT
```

Required OUTPUT exceptions before the REJECT rule: LAN subnet (`192.168.50.0/24`), docker bridge (`docker+`), VPN gateway (`10.2.0.1/32`).

### VPN Protocol

**OpenVPN → WireGuard:** ProtonVPN OpenVPN `AUTH_FAILED` issues were persistent and unresolvable. WireGuard connected on the first attempt. Always use WireGuard for ProtonVPN going forward.

**Gluetun vs OS-level WireGuard:** For a single-VM media stack, Gluetun adds significant complexity (shared network namespace, port mappings on the gateway container, Alpine tooling gaps) with no real benefit over `wg-quick`. OS-level is simpler, more debuggable, and more reliable.

### Proxmox

**VirtIO-fs + ZFS:** Run `chown` on ZFS-backed VirtIO-fs mounts from the Proxmox *host*, not from inside the VM. Running it inside the VM triggers circular directory structure warnings and doesn't stick.

**Cloud-init vendor snippets:** bashrc content causes YAML parsing failures when embedded directly. Host the bashrc as a separate file and pull it via `curl` in `runcmd`.

**Proxmox recovery:** GRUB single-user mode (`init=/bin/bash`) is the reliable path for fixing sudo, user permissions, and password issues on VMs.

---

*Last updated: March 14, 2026*
