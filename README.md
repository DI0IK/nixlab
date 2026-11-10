# Bare-Metal NixOS Homelab (`nixlab`) & Cloud Ingress VPS

Declarative, multi-host NixOS configuration for:
1. **Homelab (`homelab`)**: Bare-metal Dell OptiPlex (Intel Core i5-8500, 96GB RAM, ~2TB NVMe) with ephemeral tmpfs root.
2. **Cloud Ingress VPS (`vps`)**: Public cloud gateway (IONOS KVM, 1 vCPU, 2GB RAM, 60GB SSD) providing WireGuard VPN hub, HAProxy SNI-routing with PROXY Protocol v2, game server NAT forwarding, and independent external outage monitoring (Gatus + ntfy-sh).

---

## Architecture Overview

### Homelab Host (`homelab`)
- **Storage Layout & Impermanence**:
  - `nodev."/"`: 16GB volatile `tmpfs` root (wiped on every reboot).
  - ESP: 1GB FAT32 at `/boot`.
  - Btrfs subvolumes: `@persist` mounted at `/persist` (`neededForBoot = true;`, `compress=zstd`), `@nix` at `/nix`, and a 32GB swapfile at `/.swapvol`.
  - NFS Shares: Declarative NFS mounts for media (`/data/media`) and Immich photo libraries (`/mnt/immich-library`, `/mnt/immich-external`, etc.).
- **Automated Lifecycle & Updates**:
  - **Renovate Bot**: Automatically updates flake inputs in Git and maintains `flake.lock` via automated PRs.
  - **System Auto-Upgrade**: `system.autoUpgrade` runs daily at 04:00 AM, pulling directly from `github:DI0IK/nixlab#homelab` and rebuilding without forced reboots.
- **Secrets Management**:
  - Encrypted via `sops-nix` using admin YubiKey and host Ed25519 SSH key (`/persist/etc/ssh/ssh_host_ed25519_key`).
- **Databases & Cache**:
  - Central host **PostgreSQL 16 with pgvector** (used by Forgejo, Authentik, Immich).
  - Loopback trust authentication (`127.0.0.1:5432` and `/run/postgresql`).
  - Central host **Valkey** daemon on `127.0.0.1:6379`.
- **Network & Ingress**:
  - WireGuard tunnel (`wg-vps`) connecting host to public VPS (`172.30.32.2`).
  - Traefik ingress with PROXY Protocol v2 and Let's Encrypt ACME certificates via Cloudflare DNS-01.
- **Hardware Acceleration**:
  - Intel UHD Graphics 630 QuickSync VA-API passthrough for media transcoding (Jellyfin).
- **Automated Backups**:
  - Daily BorgBackup jobs targeting Hetzner Storage Box for persistent data and database dumps.

### Cloud Ingress VPS (`vps`)
- **Storage & Partitions**:
  - Declarative Disko layout with GPT, 512MB EFI/boot, 4GB random-encrypted swap partition, and ext4 root.
- **WireGuard Hub & Dual-Port Access**:
  - Primary interface `wg0` listening on UDP `51820` with MTU 1350 connecting Homelab (`.2`), Games Wing (`.3`), Laptop (`.20`), Phone (`.10`), and Tablet (`.11`).
  - Kernel redirect forwarding OpenVPN UDP `1194` traffic to `51820` for bypass on restricted public/hotel Wi-Fi.
  - Client-to-client routing and outbound internet NAT masquerade for mobile devices and game servers.
- **HAProxy Ingress with SNI Routing & PROXY-v2**:
  - Layer 4 SNI inspection on port 443:
    - Homelab domains (`*.dominikstahl.dev`): Raw TCP pass-through with `send-proxy-v2` directly to `172.30.32.2:443`.
    - VPS services (`status.dominikstahl.dev`, `ntfy.dominikstahl.dev`): Terminated locally on `127.0.0.1:8443` with an independent VPS certificate.
  - Port 22 forwarded directly to Forgejo Git SSH (`172.30.32.2:2222`).
  - Port 80 forwarded with PROXY-v2; Port 853 forwarded to AdGuard DoT.
  - Admin SSH listening on dedicated port `22222`.
- **Game Server Gateway (Calagopus Wings)**:
  - Inbound DNAT forwarding for Minecraft (`25565`), Calagopus SFTP (`2022`), Valheim (`2456:2457`), Satisfactory (`7777`), Factorio (`34197`), and dynamic port ranges (`20000:20010`) to `172.30.32.3`.
- **External Health Monitoring & Outage Alerting**:
  - **Gatus**: Automated health monitoring of the WireGuard tunnel, public endpoints, and DNS.
  - **ntfy-sh**: Self-hosted push notification server delivering immediate notifications to iOS and Android phones even if the homelab is completely offline.

---

## Repository Structure

```
homelab-nix/
├── flake.nix                       <-- Multi-host flake inputs and system outputs (homelab & vps)
├── flake.lock                      <-- Lockfile maintained by Renovate
├── .sops.yaml                      <-- SOPS recipient keys (Admin YubiKey + host age keys)
├── secrets/
│   ├── secrets.yaml                <-- Homelab encrypted secrets
│   └── vps.yaml                    <-- VPS encrypted secrets (least-privilege isolation)
├── hosts/
│   ├── homelab/                    <-- Bare-metal homelab host configuration
│   │   ├── default.nix             <-- Host entrypoint
│   │   ├── hardware.nix            <-- Intel microcode, QuickSync VA-API, sysctl
│   │   └── disk.nix                <-- Disko layout (tmpfs root, Btrfs subvolumes, /persist)
│   └── vps/                        <-- Cloud Ingress VPS configuration
│       ├── default.nix             <-- Host entrypoint (SSH port 22222, base modules)
│       ├── disk.nix                <-- Disko layout (ext4 root, 4GB random-encrypted swap)
│       ├── hardware.nix            <-- VirtIO modules, net.ifnames=0 (eth0), sysctl
│       ├── wireguard.nix           <-- WireGuard server & peers
│       ├── haproxy.nix             <-- SNI-based TCP reverse proxy & local SSL termination
│       ├── routing.nix             <-- Declarative firewall, DNAT game rules & OpenVPN redirect
│       ├── monitoring.nix          <-- Gatus health checks, ntfy-sh push notifications, ACME
│       └── secrets.nix             <-- SOPS secrets definition for VPS
└── modules/
    ├── core/                       <-- Nix settings, base packages, users, auto-upgrades
    ├── security/                   <-- Hardened SSH, firewall, SOPS integration, ACME, CrowdSec
    └── services/                   <-- Homelab services (databases, media, apps, containers, vms)
```

---

## Management & Operations

### Local Rebuild & Deployment

Rebuild and switch system configuration locally:
```bash
sudo nixos-rebuild switch --flake .#homelab
```

Deploy to homelab remotely:
```bash
nixos-rebuild switch --flake .#homelab --target-host dominik@homelab --use-remote-sudo
```

Deploy to VPS remotely:
```bash
nixos-rebuild switch --flake .#vps --target-host root@<vps-ip> --target-port 22222
```

Initial installation of a new VPS via `nixos-anywhere`:
```bash
nix run github:nix-community/nixos-anywhere -- --flake .#vps root@<new-vps-ip> -p 22
```

### Flake Evaluation & Formatting
Verify flake evaluation:
```bash
nix build .#nixosConfigurations.homelab.config.system.build.toplevel --dry-run
nix build .#nixosConfigurations.vps.config.system.build.toplevel --dry-run
```

Format code:
```bash
nix run nixpkgs#nixfmt-tree .
```

### Managing Secrets
Edit secrets files using SOPS:
```bash
# Homelab secrets
sops secrets/secrets.yaml

# VPS secrets
sops secrets/vps.yaml
```

### Monitoring System Auto-Upgrades
Check auto-upgrade timer and execution logs:
```bash
systemctl status nixos-upgrade.timer
journalctl -u nixos-upgrade.service -e
```
