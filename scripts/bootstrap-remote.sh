#!/usr/bin/env bash
# ==============================================================================
# scripts/bootstrap-remote.sh
# Bootstrap NixOS on Proxmox VE over SSH without physical media via kexec
# ==============================================================================
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <TARGET_IP>"
  echo "Example: $0 192.168.179.X"
  exit 1
fi

TARGET_IP="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> 1. Preparing ephemeral staging directory with host SSH key for sops-nix..."
TEMP_EXTRA=$(mktemp -d)
trap 'rm -rf "${TEMP_EXTRA}"' EXIT

mkdir -p -m 0755 "${TEMP_EXTRA}/persist/etc/ssh"
sops -d --extract '["system-ssh-key"]' "${REPO_DIR}/secrets/secrets.yaml" > "${TEMP_EXTRA}/persist/etc/ssh/ssh_host_ed25519_key"
chmod 0600 "${TEMP_EXTRA}/persist/etc/ssh/ssh_host_ed25519_key"
ssh-keygen -y -f "${TEMP_EXTRA}/persist/etc/ssh/ssh_host_ed25519_key" > "${TEMP_EXTRA}/persist/etc/ssh/ssh_host_ed25519_key.pub"
chmod 0644 "${TEMP_EXTRA}/persist/etc/ssh/ssh_host_ed25519_key.pub"

echo "==> 2. Bootstrapping NixOS via nixos-anywhere..."
echo "Connecting to root@${TARGET_IP}..."
echo "This will:"
echo "  1. kexec into an in-memory NixOS installer (no reboot required)"
echo "  2. Format /dev/nvme0n1 using Disko"
echo "  3. Inject host SSH key into /persist/etc/ssh"
echo "  4. Install NixOS and reboot directly into your new homelab"
echo ""

nix run github:nix-community/nixos-anywhere -- \
  --extra-files "${TEMP_EXTRA}" \
  --flake "${REPO_DIR}#homelab" \
  "root@${TARGET_IP}"
