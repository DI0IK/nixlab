# Bare-Metal NixOS Homelab (`homelab-nix`)

Declarative, standalone NixOS configuration for transforming the physical Dell Optiplex (Intel Core i5-8500, 96GB RAM, ~2TB NVMe) from Proxmox VE + Kubernetes into a unified, bare-metal NixOS host.

---

## Architecture Overview

- **Storage Layout**:
  - `nodev."/"`: 16GB volatile `tmpfs` root (wiped on every reboot).
  - ESP: 1GB FAT32 at `/boot`.
  - Btrfs:
    - `@persist` mounted at `/persist` (`neededForBoot = true;`, `compress=zstd`).
    - `@nix` mounted at `/nix` (`compress=zstd`).
    - `@swap` mounted at `/.swapvol` with a 32GB swapfile.
  - NFS: External NFS share mounted declaratively at `/data/media` (`192.168.179.10:/mnt/user/media`).
- **Secrets**: `sops-nix` managed via admin YubiKey (`fw13`) and host Ed25519 key (`/persist/etc/ssh/ssh_host_ed25519_key`).
- **Databases & Cache**:
  - Central host **PostgreSQL 16 with pgvector** (Forgejo, Authentik, Immich).
  - Trust authentication on loopback (`127.0.0.1:5432` and `/run/postgresql`) eliminating local database passwords.
  - Central host **Valkey** daemon on `127.0.0.1:6379`.
- **Ingress**:
  - WireGuard tunnel (`wg-vps`) connecting to VPS `217.154.87.4:51820`.
  - Traefik with PROXY Protocol v2 and Let's Encrypt ACME (Cloudflare DNS-01).
- **Hardware Acceleration**: Intel UHD Graphics 630 QuickSync VA-API passthrough to Jellyfin.

---

## Repository Structure

```
homelab-nix/
├── flake.nix                       <-- Standalone flake inputs and homelab output
├── flake.lock
├── .sops.yaml                      <-- SOPS recipient keys (Admin YubiKey + host age key)
├── secrets/
│   └── secrets.yaml                <-- Encrypted production secrets
├── hosts/
│   └── homelab/
│       ├── default.nix             <-- Host entrypoint (imports profiles & services)
│       ├── hardware.nix            <-- Intel i5-8500 microcode, QuickSync VA-API, sysctl
│       └── disk.nix                <-- Disko layout (tmpfs root, Btrfs subvolumes, /persist)
├── modules/
│   ├── core/                       <-- Nix settings, base packages, users, impermanence
│   ├── security/                   <-- Hardened SSH, firewall, SOPS integration
│   └── services/
│       ├── network/                <-- wg-vps WireGuard tunnel & Traefik PROXY-v2 ingress
│       ├── databases/              <-- PostgreSQL 16 (pgvector) & host Valkey cache
│       ├── media/                  <-- Jellyfin, Jellyseerr, Arr stack, Navidrome
│       ├── automation/             <-- Home Assistant Core & Mosquitto MQTT
│       ├── apps/                   <-- Forgejo, AdGuard Home, SearXNG, The Lounge
│       ├── containers/             <-- Podman host-networking stacks (Immich, Authentik, misc)
│       └── backup/                 <-- Automated Borg backups to Hetzner Storage Box
└── scripts/
    ├── preseed-host-key.sh         <-- Injects system-ssh-key from secrets.yaml into target /mnt/persist/etc/ssh
    ├── evacuate-k8s.sh             <-- Freezes K8s pods, dumps DBs, pulls PVCs to fw13
    ├── migrate-permissions.sh      <-- Relocates restored PVC data into /persist/var/lib
    └── restore-databases.sh        <-- Ingests logical dumps into PostgreSQL 16
```

---

## Step-by-Step Migration & Installation

### Phase 1: Local Secrets Verification (on fw13)

Your secrets file `secrets/secrets.yaml` is already encrypted using both your YubiKey and the server host age key (derived from `system-ssh-key`).

### Phase 2: Data Evacuation (Proxmox Online)

Run the evacuation script from `fw13` (where `kubectl` is configured):
```bash
./scripts/evacuate-k8s.sh
```
All persistent data and database dumps will be stored in `~/homelab-evacuation/`.

### Phase 3: Bare-Metal Transformation (Server Offline)

1. Boot the server from a NixOS Minimal Live USB.
2. Verify network connectivity on the server (`ip a`) and set a temporary root password (`passwd root`).
3. From `fw13`, partition the server drive via Disko:
   ```bash
   nix run github:nix-community/disko -- \
     --mode disko \
     --flake .#homelab \
     root@<SERVER_INSTALLER_IP>
   ```
4. **Pre-seed the host key** directly onto the freshly formatted `/mnt/persist/etc/ssh`:
   ```bash
   ./scripts/preseed-host-key.sh <SERVER_INSTALLER_IP>
   ```
5. Install NixOS:
   ```bash
   nixos-install --flake .#homelab --no-root-password --target-host root@<SERVER_INSTALLER_IP>
   ```
6. Reboot into bare-metal NixOS:
   ```bash
   ssh root@<SERVER_INSTALLER_IP> reboot
   ```

### Phase 4: State Re-hydration & Activation

1. From `fw13`, transfer the evacuated data into `/persist/staging`:
   ```bash
   rsync -avP --sparse ~/homelab-evacuation/pvcs/ root@<NIXOS_IP>:/persist/staging/
   rsync -avP ~/homelab-evacuation/dumps/ root@<NIXOS_IP>:/persist/staging/dumps/
   ```
2. SSH into the NixOS server:
   ```bash
   ssh dominik@<NIXOS_IP>
   sudo -i
   ```
3. Run the relocation and permissions fixup script:
   ```bash
   /path/to/homelab-nix/scripts/migrate-permissions.sh
   ```
4. Restore databases into PostgreSQL:
   ```bash
   /path/to/homelab-nix/scripts/restore-databases.sh
   ```
5. Restart services or reboot to bring all systems online:
   ```bash
   systemctl restart postgresql
   systemctl restart traefik
   ```
