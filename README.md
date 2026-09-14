# Bare-Metal NixOS Homelab (`nixlab`)

Declarative, standalone NixOS homelab configuration for a bare-metal Dell OptiPlex (Intel Core i5-8500, 96GB RAM, ~2TB NVMe).

---

## Architecture Overview

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
  - WireGuard tunnel (`wg-vps`) connecting host to public VPS.
  - Traefik ingress with PROXY Protocol v2 and Let's Encrypt ACME certificates via Cloudflare DNS-01.
- **Hardware Acceleration**:
  - Intel UHD Graphics 630 QuickSync VA-API passthrough for media transcoding (Jellyfin).
- **Automated Backups**:
  - Daily BorgBackup jobs targeting Hetzner Storage Box for persistent data and database dumps.

---

## Repository Structure

```
homelab-nix/
├── flake.nix                       <-- Standalone flake inputs and homelab system output
├── flake.lock                      <-- Lockfile maintained by Renovate
├── .sops.yaml                      <-- SOPS recipient keys (Admin YubiKey + host age key)
├── secrets/
│   └── secrets.yaml                <-- Encrypted production secrets
├── hosts/
│   └── homelab/
│       ├── default.nix             <-- Host entrypoint (imports profiles & services)
│       ├── hardware.nix            <-- Intel i5-8500 microcode, QuickSync VA-API, sysctl
│       └── disk.nix                <-- Disko layout (tmpfs root, Btrfs subvolumes, /persist)
└── modules/
    ├── core/                       <-- Nix settings, base packages, users, auto-upgrades, impermanence
    ├── security/                   <-- Hardened SSH, firewall, SOPS integration, ACME
    └── services/
        ├── network/                <-- wg-vps WireGuard tunnel & Traefik PROXY-v2 ingress
        ├── databases/              <-- PostgreSQL 16 (pgvector) & host Valkey cache
        ├── media/                  <-- Jellyfin, Jellyseerr, Arr stack, Navidrome
        ├── automation/             <-- Home Assistant Core & Mosquitto MQTT
        ├── apps/                   <-- Forgejo, AdGuard Home, SearXNG, The Lounge
        ├── containers/             <-- Podman host-networking stacks (Immich, Authentik, misc)
        └── backup/                 <-- Automated Borg backups to Hetzner Storage Box
```

---

## Management & Operations

### Local Rebuild & Deployment
Rebuild and switch system configuration locally:
```bash
sudo nixos-rebuild switch --flake .#homelab
```

Deploy to host remotely:
```bash
nixos-rebuild switch --flake .#homelab --target-host dominik@homelab --use-remote-sudo
```

### Flake Evaluation & Formatting
Verify flake evaluation:
```bash
nix build .#nixosConfigurations.homelab.config.system.build.toplevel --dry-run
```

Format code:
```bash
nix fmt
```

### Managing Secrets
Edit secrets file using SOPS:
```bash
sops secrets/secrets.yaml
```

### Monitoring System Auto-Upgrades
Check auto-upgrade timer and execution logs:
```bash
systemctl status nixos-upgrade.timer
journalctl -u nixos-upgrade.service -e
```
