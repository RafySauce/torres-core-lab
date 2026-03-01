# Torres-Core — Physical TODO & Hardware Migration Plan

## Immediate Physical TODOs (Post-Transfer)

### After file transfer completes:
- [ ] Harden SMB on Proxmox (non-root user, disable root Samba)
- [ ] Reboot Proxmox → enter BIOS → set "Restore on AC Power Loss" → Power On
- [ ] Verify Plex libraries fully scanned after transfer
- [ ] Test Plex playback from another device on the network

### Gaming PC Cleanup:
- [ ] Confirm all media files transferred successfully to Proxmox
- [ ] Delete media files from gaming PC
- [ ] Remove 4TB Seagate Barracuda HDD from gaming PC
- [ ] Label drive and store safely (or allocate to a node — see migration plan)

### Router / Network:
- [ ] DHCP reservation for proxmox-n3 (.10) — DONE
- [ ] Update router admin password if needed

### Travel Network:
- [ ] Add Tailscale WireGuard profile to GL.iNet for home lab access
- [ ] Test Plex streaming via Tailscale from travel Roku

### Git / Documentation:
- [ ] Initialize torres-core-lab Git repo on gaming PC
- [ ] Commit architecture doc as first file
- [ ] Clean up accidental SSH config on Proxmox rafy home dir

---

## Hardware Inventory — Available for Migration

### Gaming PC (CoreGaming) — KEEP AS DAILY DRIVER
| Component | Spec | Action |
|-----------|------|--------|
| Role | Gaming + daily use | No changes — dedicated to gaming |
| 4TB Seagate Barracuda | Freed after media transfer | Remove → reallocate |

### Cortana (Security Camera NVR) — CONVERT TO PROXMOX NODE
| Component | Spec | Action |
|-----------|------|--------|
| CPU | Intel Core i7-6700 (4C/8T) | Plenty for a second Proxmox node |
| RAM | 16GB DDR4 | Adequate for NVR VM + light services |
| 1TB Samsung EVO SSD | M.2 | Proxmox OS drive |
| 4TB WD Red HDD | Surveillance rated | Surveillance recordings / local backup |
| Current Role | Windows — Reolink NVR | Migrate NVR to VM, wipe Windows |

### Hal (Old PC with GPU) — CONVERT TO PROXMOX NODE
| Component | Spec | Action |
|-----------|------|--------|
| CPU | Intel Core i5-4440 (4C/4T) | Older but functional |
| RAM | 16GB DDR3 | Enough for GPU workloads |
| GPU | GTX 1050 | GPU passthrough for transcode / AI |
| Storage | None listed | Needs a drive — candidate for the 4TB Barracuda |
| Current Role | Idle | Bring online as GPU node |

### Spare Drive from Gaming PC
| Drive | Spec | Best Use |
|-------|------|----------|
| 4TB Seagate Barracuda | SATA HDD | Option A: Install in Hal as its primary storage |
| | | Option B: Add to Cortana for extra capacity |
| | | Option C: Use as offline backup drive |

---

## Migration Path — Phase 4 Plan

### Step 1: Cortana → Proxmox Node (proxmox-cortana)
**Prerequisites:** Phase 1 & 2 complete on proxmox-n3

1. Back up any Reolink recordings you want to keep
2. Note Reolink camera IPs and config
3. Wipe Windows, install Proxmox VE on 1TB Samsung EVO SSD
4. Assign static IP: 192.168.50.20
5. Create ZFS pool on 4TB WD Red for surveillance storage
6. Spin up Windows VM → install Reolink NVR (or go straight to Blue Iris/Frigate)
7. Reconnect cameras to new NVR VM
8. Set up ZFS replication: proxmox-n3 → proxmox-cortana for backups
9. Join Proxmox cluster (optional — adds shared management)

**Estimated time:** 2-3 hours
**Downtime:** Cameras offline during migration

### Step 2: Hal → Proxmox Node (proxmox-hal)
**Prerequisites:** Cortana migrated, spare drive allocated

1. Install 4TB Barracuda (from gaming PC) into Hal
2. Install Proxmox VE on the Barracuda (or get a small SSD for OS)
3. Assign static IP: 192.168.50.21
4. Configure GPU passthrough for GTX 1050
5. Use cases:
   - Plex hardware transcode offload
   - Frigate AI object detection for cameras
   - Lightweight ML experimentation
6. Join Proxmox cluster (optional)

**Estimated time:** 2-3 hours
**Note:** i5-4440 is DDR3 era — check if it's worth the power consumption vs. capabilities. May be better as a dedicated single-purpose box (e.g., Frigate only).

### Automation Ideas for Migration:
- **Ansible playbook** — automate Proxmox post-install config (repos, users, SSH hardening, ZFS pools) so each new node gets the same baseline
- **Cloud-init templates** — pre-bake VM/LXC templates with your standard config (Tailscale, bashrc, etc.)
- **Proxmox API scripts** — automate container creation with consistent naming, IPs, resources
- **Infrastructure as Code** — Terraform has a Proxmox provider for defining VMs/CTs declaratively

These are great Phase 4-5 learning projects that double as resume material.

---

## Cluster Architecture (Future State)

```
┌─────────────────────────────────────────────────┐
│                 Torres-Core Lab                  │
├─────────────────┬──────────────┬────────────────┤
│   proxmox-n3    │   cortana    │      hal       │
│   .10           │   .20        │      .21       │
│                 │              │                │
│ ▪ Tailscale LXC │ ▪ Reolink   │ ▪ GPU tasks    │
│ ▪ Plex LXC      │   NVR VM    │ ▪ Frigate      │
│ ▪ Home Asst VM  │ ▪ Backup    │ ▪ Plex HW      │
│ ▪ AdGuard LXC   │   target    │   transcode    │
│ ▪ Docker VM     │              │                │
│ ▪ CF Tunnel LXC │              │                │
│                 │              │                │
│ NVMe: 2TB       │ SSD: 1TB    │ HDD: 4TB       │
│ HDD: 2×12TB mir │ HDD: 4TB   │ GPU: GTX 1050  │
└─────────────────┴──────────────┴────────────────┘
         │              │               │
         └──────────────┴───────────────┘
              EdgeSwitch 8 150W (PoE+)
                       │
              Asus GS-AX5400 (→ UDR7)
                       │
                   Internet
```

---

*Last updated: March 1, 2026*
